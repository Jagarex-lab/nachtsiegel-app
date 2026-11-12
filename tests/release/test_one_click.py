import copy
import hashlib
import importlib.util
import io
import json
import stat
import tempfile
import unittest
import urllib.error
import urllib.request
import warnings
import zipfile
from pathlib import Path
from unittest.mock import patch

import yaml

spec = importlib.util.spec_from_file_location("candidate", Path("tools/release/candidate.py"))
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)
SHA = "a" * 40


def valid():
    context = {"repository": c.REPOSITORY, "event": "workflow_dispatch", "ref": c.REF, "sha": SHA}
    def run(identifier, path):
        return {"id": identifier, "run_attempt": 1, "repository": {"full_name": c.REPOSITORY}, "head_repository": {"full_name": c.REPOSITORY}, "head_sha": SHA, "head_branch": "develop", "event": "push", "path": path, "status": "completed", "conclusion": "success"}
    def jobs(identifier, names):
        return [{"id": index + identifier * 100, "run_id": identifier, "head_sha": SHA, "name": name, "status": "completed", "conclusion": "success"} for index, name in enumerate(sorted(names))]
    evidence = {
        "develop_sha": SHA, "pages": {"build_type": "workflow"},
        "environment": {"name": "github-pages", "deployment_branch_policy": {"custom_branch_policies": True}, "protection_rules": [{"type": "required_reviewers"}]},
        "policies": [{"name": "develop", "type": "branch"}],
        "main": run(101, c.MAIN), "safety": run(102, c.SAFETY),
        "main_jobs": jobs(101, c.MAIN_JOBS), "safety_jobs": jobs(102, ["release-safety"]),
        "artifacts": [{"id": 103, "name": c.ARTIFACT, "expired": False, "size_in_bytes": 1000, "digest": "sha256:" + "b" * 64, "workflow_run": {"id": 101, "head_sha": SHA}}],
    }
    return context, evidence


def zipped(entries=None):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w") as package:
        for name, value in (entries or {
            "build/web/build-info.json": json.dumps({"commit": SHA, "channel": "develop"}),
            "build/web/index.html": "<html>tested</html>",
            "build/web/orafold-a.pck": "real-test-pck",
            "build/web/orafold-a.wasm": "real-test-wasm",
            "alpha/test.log": "not published",
        }).items():
            package.writestr(name, value)
    return stream.getvalue()


class CandidateTests(unittest.TestCase):
    def test_exact_complete_candidate_and_extra_successful_jobs(self):
        context, evidence = valid()
        before = copy.deepcopy(evidence)
        result = c.select(context, evidence)
        self.assertEqual(result["commit"], SHA)
        self.assertEqual(result["qa_run_id"], 101)
        self.assertEqual(evidence, before)
        evidence["main_jobs"].append({**evidence["main_jobs"][0], "id": 9999, "name": "new-required-premium-qa"})
        self.assertEqual(c.select(context, evidence), result)

    def test_context_matrix_has_no_implicit_publish_event(self):
        for event in ["workflow_dispatch", "push", "pull_request", "workflow_run", "release", "repository_dispatch"]:
            for ref in [c.REF, "refs/heads/main", "refs/tags/v1", "refs/pull/1/merge", "refs/heads/feature/test"]:
                context, evidence = valid()
                context.update(event=event, ref=ref)
                with self.subTest(event=event, ref=ref):
                    if event == "workflow_dispatch" and ref == c.REF:
                        c.select(context, evidence)
                    else:
                        with self.assertRaises(c.Denied):
                            c.select(context, evidence)

    def test_fork_tags_and_stale_source_are_denied(self):
        for field, value in [("repository", "fork/game"), ("sha", "main"), ("sha", "A" * 40), ("sha", "b" * 40)]:
            context, evidence = valid()
            context[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(c.Denied):
                c.select(context, evidence)

    def test_settings_never_mutated_or_bypassed(self):
        context, evidence = valid()
        for rules in [[], [{"type": "required_reviewers", "prevent_self_review": True}], [{"type": "wait_timer", "wait_timer": 30}]]:
            evidence["environment"]["protection_rules"] = rules
            before = copy.deepcopy(evidence)
            c.select(context, evidence)
            self.assertEqual(before, evidence)
        for mutate in [lambda e: e["pages"].update(build_type="legacy"), lambda e: e["environment"].update(name="alternate"), lambda e: e.update(policies=[{"name": "*", "type": "tag"}])]:
            bad = copy.deepcopy(evidence)
            mutate(bad)
            with self.assertRaises(c.Denied):
                c.select(context, bad)

    def test_every_original_main_job_is_required(self):
        context, evidence = valid()
        for name in c.MAIN_JOBS:
            bad = copy.deepcopy(evidence)
            bad["main_jobs"] = [j for j in bad["main_jobs"] if j["name"] != name]
            with self.subTest(missing=name), self.assertRaises(c.Denied):
                c.select(context, bad)

    def test_all_jobs_must_succeed_including_new_and_safety_jobs(self):
        context, evidence = valid()
        for group in ["main_jobs", "safety_jobs"]:
            for status, conclusion in [("in_progress", None), ("completed", "skipped"), ("completed", "failure"), ("completed", "cancelled"), ("completed", "neutral"), ("completed", "timed_out")]:
                bad = copy.deepcopy(evidence)
                bad[group][0].update(status=status, conclusion=conclusion)
                with self.subTest(group=group, status=status, conclusion=conclusion), self.assertRaises(c.Denied):
                    c.select(context, bad)
        for group in ["main_jobs", "safety_jobs"]:
            for change in [{"run_id": 999}, {"head_sha": "b" * 40}]:
                bad = copy.deepcopy(evidence)
                bad[group][0].update(change)
                with self.assertRaises(c.Denied):
                    c.select(context, bad)
        bad = copy.deepcopy(evidence)
        bad["main_jobs"].append(bad["main_jobs"][0])
        with self.assertRaises(c.Denied):
            c.select(context, bad)

    def test_run_identity_and_attempt(self):
        context, evidence = valid()
        for group in ["main", "safety"]:
            for change in [{"repository": {"full_name": "fork/game"}}, {"head_repository": {"full_name": "fork/game"}}, {"head_sha": "b" * 40}, {"head_branch": "feature/test"}, {"event": "pull_request"}, {"path": ".github/workflows/smoke.yml"}, {"status": "in_progress"}, {"conclusion": "failure"}, {"run_attempt": 0}, {"id": -1}]:
                bad = copy.deepcopy(evidence)
                bad[group].update(change)
                with self.subTest(group=group, change=change), self.assertRaises(c.Denied):
                    c.select(context, bad)

    def test_artifact_cannot_be_old_foreign_missing_expired_or_ambiguous(self):
        context, evidence = valid()
        for change in [{"id": 0}, {"expired": True}, {"size_in_bytes": 0}, {"size_in_bytes": 2_000_000_001}, {"digest": None}, {"digest": "sha256:bad"}, {"workflow_run": {"id": 999, "head_sha": SHA}}, {"workflow_run": {"id": 101, "head_sha": "b" * 40}}]:
            bad = copy.deepcopy(evidence)
            bad["artifacts"][0].update(change)
            with self.subTest(change=change), self.assertRaises(c.Denied):
                c.select(context, bad)
        for artifacts in [[], evidence["artifacts"] * 2]:
            bad = copy.deepcopy(evidence)
            bad["artifacts"] = artifacts
            with self.assertRaises(c.Denied):
                c.select(context, bad)

    def test_recheck_rejects_every_candidate_identity_change(self):
        context, evidence = valid()
        selected = c.select(context, evidence)
        for field in selected:
            bad = copy.deepcopy(selected)
            bad[field] = "changed"
            with self.subTest(field=field), self.assertRaises(c.Denied):
                c.recheck(context, evidence, bad)
        evidence["main"]["run_attempt"] = 2
        with self.assertRaises(c.Denied):
            c.recheck(context, evidence, selected)

    def test_api_selects_latest_run_even_when_it_failed(self):
        _, evidence = valid()
        rows = [evidence["main"], {**evidence["main"], "id": 110, "conclusion": "failure"}]
        api = c.API("not-a-real-token-not-used")
        with patch.object(api, "pages", return_value=rows):
            self.assertEqual(api.latest_run(c.MAIN, SHA)["id"], 110)
        rows[0].update(run_started_at="2026-11-11T15:00:00Z", run_attempt=2, conclusion="failure")
        rows[1].update(run_started_at="2026-11-11T14:00:00Z")
        with patch.object(api, "pages", return_value=rows):
            self.assertEqual(api.latest_run(c.MAIN, SHA)["id"], 101, "a newer failing retry of an older run cannot be ignored")

    def test_api_pagination_includes_every_job_and_is_bounded(self):
        api = c.API("not-used")
        with patch.object(api, "get", side_effect=[{"jobs": list(range(100))}, {"jobs": [100]}]) as get:
            self.assertEqual(len(api.pages("actions/runs/1/jobs", "jobs")), 101)
            self.assertIn("page=2", get.call_args.args[0])
        with patch.object(api, "get", return_value={"jobs": list(range(100))}):
            with self.assertRaises(c.Denied):
                api.pages("actions/runs/1/jobs", "jobs")

    def test_api403_and_missing_fields_fail_closed(self):
        api = c.API("not-used")
        with patch.object(api, "get", side_effect=urllib.error.HTTPError("redacted", 403, "Forbidden", {}, None)):
            with self.assertRaises(urllib.error.HTTPError):
                api.collect(valid()[0])
        context, evidence = valid()
        del evidence["main"]["head_repository"]
        with self.assertRaises(c.Denied):
            c.select(context, evidence)

    def test_extracts_only_web_and_records_actual_hashes_without_rewriting(self):
        context, evidence = valid()
        candidate = c.select(context, evidence)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive = root / "artifact.zip"
            archive.write_bytes(zipped())
            result = c.extract_web(archive, root / "web", candidate)
            self.assertEqual((root / "web/index.html").read_text(), "<html>tested</html>")
            self.assertFalse((root / "web/alpha/test.log").exists())
            self.assertEqual(result["files"]["index.html"], hashlib.sha256(b"<html>tested</html>").hexdigest())
            self.assertEqual(json.loads((root / "web/release-evidence.json").read_text())["candidate"], candidate)
            with self.assertRaises(c.Denied):
                c.extract_web(archive, root / "web", candidate)
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                with zipfile.ZipFile(archive, "w") as package:
                    package.writestr("build/web/index.html", "one")
                    package.writestr("build/web/index.html", "two")
            with self.assertRaises(c.Denied):
                c.extract_web(archive, root / "web", candidate)

    def test_archive_traversal_symlink_duplicate_noncanonical_and_wrong_source(self):
        candidate = c.select(*valid())
        unsafe = ["../escape", "/absolute", "build/web/../../escape", "C:/escape", "build\\web\\bad", "build//web/alias", "build/web/./alias"]
        for name in unsafe:
            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                archive = root / "artifact.zip"
                archive.write_bytes(zipped({name: "bad"}))
                with self.subTest(name=name), self.assertRaises(c.Denied):
                    c.extract_web(archive, root / "web", candidate)
                self.assertFalse((root / "web").exists())
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive = root / "artifact.zip"
            link = zipfile.ZipInfo("build/web/link")
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            with zipfile.ZipFile(archive, "w") as package:
                package.writestr(link, "../../../outside")
            with self.assertRaises(c.Denied):
                c.extract_web(archive, root / "web", candidate)
            archive.write_bytes(zipped({"build/web/index.html": "tested", "build/web/build-info.json": json.dumps({"commit": "b" * 40, "channel": "develop"})}))
            with self.assertRaises(c.Denied):
                c.extract_web(archive, root / "web", candidate)

    def test_download_requires_actual_zip_hash_and_length(self):
        payload = zipped()
        candidate = c.select(*valid())
        candidate.update(artifact_size=len(payload), artifact_digest="sha256:" + hashlib.sha256(payload).hexdigest())
        for bad in [False, True]:
            with tempfile.TemporaryDirectory() as folder:
                target = Path(folder) / "download.zip"
                body = io.BytesIO(payload if not bad else payload[:-1])
                with patch("urllib.request.build_opener") as opener:
                    opener.return_value.open.return_value = body
                    if bad:
                        with self.assertRaises(c.Denied):
                            c.download_artifact(c.API("not-used"), candidate, target)
                        self.assertFalse(target.exists())
                    else:
                        c.download_artifact(c.API("not-used"), candidate, target)
                        self.assertEqual(target.read_bytes(), payload)

    def test_preexisting_release_provenance_is_denied_before_any_extraction(self):
        candidate = c.select(*valid())
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive = root / "artifact.zip"
            archive.write_bytes(zipped({
                "build/web/index.html": "tested",
                "build/web/build-info.json": json.dumps({"commit": SHA, "channel": "develop"}),
                "build/web/release-evidence.json": '{"candidate":"stale"}',
            }))
            with self.assertRaisesRegex(c.Denied, "reserved release provenance"):
                c.extract_web(archive, root / "web", candidate)
            self.assertFalse((root / "web").exists())

    def test_extra_unknown_failed_or_pending_jobs_are_never_ignored(self):
        context, evidence = valid()
        for group in ["main_jobs", "safety_jobs"]:
            for status, conclusion in [("completed", "failure"), ("in_progress", None), ("completed", "skipped"), ("completed", "cancelled")]:
                bad = copy.deepcopy(evidence)
                bad[group].append({**bad[group][0], "id": 99999, "name": "future-premium-required-qa", "status": status, "conclusion": conclusion})
                with self.subTest(group=group, status=status, conclusion=conclusion), self.assertRaises(c.Denied):
                    c.select(context, bad)

    def test_authenticated_api_redirect_uses_fresh_unauthenticated_storage_request(self):
        payload = zipped()
        candidate = c.select(*valid())
        candidate.update(artifact_size=len(payload), artifact_digest="sha256:" + hashlib.sha256(payload).hexdigest())
        with tempfile.TemporaryDirectory() as folder, patch("urllib.request.build_opener") as opener:
            first, second = unittest.mock.Mock(), unittest.mock.Mock()
            opener.side_effect = [first, second]
            first.open.side_effect = urllib.error.HTTPError("redacted", 302, "Found", {"Location": "https://safe.blob.core.windows.net/artifact?signature=not-logged"}, None)
            second.open.return_value = io.BytesIO(payload)
            c.download_artifact(c.API("workflow-test-only"), candidate, Path(folder) / "artifact.zip")
            self.assertTrue(first.open.call_args.args[0].has_header("Authorization"))
            self.assertFalse(second.open.call_args.args[0].has_header("Authorization"))

    def test_download_digest_mismatch_removes_partial_file(self):
        payload = zipped()
        candidate = c.select(*valid())
        candidate.update(artifact_size=len(payload))
        with tempfile.TemporaryDirectory() as folder, patch("urllib.request.build_opener") as opener:
            opener.return_value.open.return_value = io.BytesIO(payload)
            target = Path(folder) / "artifact.zip"
            with self.assertRaises(c.Denied):
                c.download_artifact(c.API("not-used"), candidate, target)
            self.assertFalse(target.exists())

    def test_artifact_redirect_never_forwards_authorization(self):
        redirect = c.StorageRedirect()
        request = urllib.request.Request("https://a.blob.core.windows.net/first", headers={"Authorization": "Bearer do-not-forward"})
        moved = redirect.redirect_request(request, None, 302, "Found", {}, "https://b.blob.core.windows.net/second")
        self.assertFalse(moved.has_header("Authorization"))
        for url in ["http://a.blob.core.windows.net/file", "https://evil.example/file", "https://user:secret@a.blob.core.windows.net/file", "https://a.blob.core.windows.net:444/file"]:
            with self.subTest(url=url), self.assertRaises(c.Denied):
                c.validate_storage_url(url)

    def test_active_workflow_and_guard_remain_byte_identical(self):
        for name, digest in {
            ".github/workflows/pages-release.yml": "cac935fa33f36c39d31acaf7133595bf94954886e3f8312d0b7e84f18bb0a2dd",
            "tools/release/guard.py": "008496e6298dd7c23ea4c80516ebbb08b7faa1a8dce6ca60b829f5fba430a45a",
        }.items():
            self.assertEqual(hashlib.sha256(Path(name).read_bytes()).hexdigest(), digest)

    def test_inactive_template_is_manual_input_free_and_least_privilege(self):
        path = Path(".github/release-staging/pages-one-click.yml.in")
        workflow = yaml.load(path.read_text(), Loader=yaml.BaseLoader)
        self.assertNotIn(path.parent, [Path(".github/workflows")])
        self.assertEqual(set(workflow["on"]), {"workflow_dispatch"})
        self.assertFalse(workflow["on"]["workflow_dispatch"])
        self.assertEqual(workflow["permissions"], {"contents": "read"})
        self.assertEqual(workflow["concurrency"]["cancel-in-progress"], "false")
        jobs = workflow["jobs"]
        self.assertEqual(jobs["publish"]["environment"]["name"], "github-pages")
        self.assertEqual(jobs["publish"]["needs"], "preflight")
        self.assertEqual(jobs["verify-public"]["permissions"], {"contents": "read"})
        for name, job in jobs.items():
            self.assertIn("github.event_name == 'workflow_dispatch'", job["if"])
            self.assertIn("github.ref == 'refs/heads/develop'", job["if"])
            privileged = job.get("permissions", {}).get("pages") == "write" or job.get("permissions", {}).get("id-token") == "write"
            self.assertEqual(privileged, name == "publish")
            for step in job["steps"]:
                if "uses" in step:
                    self.assertRegex(step["uses"], r"@[0-9a-f]{40}$")
        publish_steps = jobs["publish"]["steps"]
        deploy = next(i for i, step in enumerate(publish_steps) if "deploy-pages@" in step.get("uses", ""))
        self.assertEqual(publish_steps[deploy - 1]["run"], "python3 tools/release/candidate.py recheck")
        self.assertNotIn("export-debug", path.read_text())

    def test_activation_review_prints_diff_without_mutating(self):
        spec = importlib.util.spec_from_file_location("review", Path("tools/release/review_activation.py"))
        review = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(review)
        before = review.ACTIVE.read_bytes()
        diff = review.activation_diff()
        self.assertIn("+name: Reviewed one-click", diff)
        self.assertEqual(review.ACTIVE.read_bytes(), before)
        self.assertNotIn("write_text", Path("tools/release/review_activation.py").read_text())


if __name__ == "__main__":
    unittest.main()
