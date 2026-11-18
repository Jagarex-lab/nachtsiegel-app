"""Fail-closed discovery and verification for the approved automatic Alpha release.

GitHub's trusted workflow_run payload identifies the tested source. The workflow
execution SHA is never substituted for that source. This guard only reads API
state and prepares the immutable tested export; it never changes GitHub settings.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import urllib.parse
import urllib.request
import urllib.error
import zipfile
from datetime import datetime
from pathlib import Path, PurePosixPath

REPOSITORY = "Jagarex-lab/nachtsiegel-app"
REF = "refs/heads/develop"
MAIN = ".github/workflows/web-preview.yml"
SAFETY = ".github/workflows/release-safety.yml"
ARTIFACT = "nachtsiegel-arena-qa"
PUBLIC_URL = "https://jagarex-lab.github.io/nachtsiegel-app/"
SHA = re.compile(r"[0-9a-f]{40}")
DIGEST = re.compile(r"sha256:[0-9a-f]{64}")
MAIN_JOBS = {
    "test-and-export", "browser (chromium)", "browser (webkit)",
    "native-platforms / windows", "native-platforms / linux-android",
    "alpha03-integration / integrated-modules", "production-audio / audio",
    "production-art-native-package", "production-art-browser (chromium)",
    "production-art-browser (webkit)", "production-resources",
    "production-full-pool-coverage", "production-balance-aggregate",
    "premium-browser (chromium)", "premium-browser (webkit)", "premium-block-balance",
    *{f"production-balance ({i})" for i in range(4)},
}
SUITES = {
    "main": (MAIN, MAIN_JOBS),
    "alpha": (".github/workflows/alpha-qa.yml", {"alpha-playable", "balance-audit", "browser (chromium)", "browser (webkit)"}),
    "safety": (SAFETY, {"release-safety"}),
    "legacy": (".github/workflows/legacy-foundations.yml", {"pinned-reference-and-catalog"}),
    "economy": (".github/workflows/economy-qa.yml", {"economy"}),
    "campaign": (".github/workflows/campaign-orafold-qa.yml", {"isolated-campaign"}),
    "online": (".github/workflows/online-qa.yml", {"online / integrated-modules"}),
}
PENDING = {"queued", "in_progress", "requested", "waiting", "pending"}


class Denied(ValueError):
    pass


class NotReady(ValueError):
    """A valid source is stale or still waiting for its required push QA."""


def require(ok, message):
    if not ok:
        raise Denied(message)


def context_from_env():
    context = {key: os.environ[name] for key, name in {
        "repository": "GITHUB_REPOSITORY", "event": "GITHUB_EVENT_NAME",
        "ref": "GITHUB_REF", "sha": "GITHUB_SHA",
    }.items()}
    context["workflow_sha"] = context["sha"]
    if context["event"] == "workflow_run":
        try:
            context["payload"] = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
            context["sha"] = context["payload"]["workflow_run"]["head_sha"]
        except (KeyError, TypeError, OSError, ValueError) as error:
            raise Denied("missing or malformed workflow_run event payload") from error
    validate_context(context)
    return context


def positive_id(value):
    return type(value) is int and value > 0


def repository_name(value):
    return value.get("full_name") if isinstance(value, dict) else None


def validate_run_identity(run, path, sha):
    require(isinstance(run, dict), "malformed QA run")
    require(repository_name(run.get("repository")) == REPOSITORY, "foreign QA repository")
    require(repository_name(run.get("head_repository")) == REPOSITORY, "foreign head repository")
    require(run.get("head_sha") == sha and run.get("head_branch") == "develop", "QA source mismatch")
    require(run.get("event") == "push", "only trusted push QA is accepted")
    require(run.get("path") == path, "wrong QA workflow path")
    require(positive_id(run.get("id")), "invalid run ID")
    require(positive_id(run.get("run_attempt")), "invalid run attempt")


def validate_context(context):
    require(context.get("repository") == REPOSITORY, "wrong repository")
    require(context.get("ref") == REF, "develop branch only; no tags or PR refs")
    require(isinstance(context.get("sha"), str) and SHA.fullmatch(context["sha"]) is not None, "full lowercase SHA required")
    if context.get("event") == "workflow_dispatch":
        return
    require(context.get("event") == "workflow_run", "only QA completion or inputless dispatch is accepted")
    payload = context.get("payload")
    require(isinstance(payload, dict) and payload.get("action") == "completed", "completed workflow_run event required")
    require(repository_name(payload.get("repository")) == REPOSITORY, "foreign event repository")
    run = payload.get("workflow_run")
    require(isinstance(run, dict), "missing workflow_run identity")
    require(isinstance(run.get("path"), str) and run["path"] in {path for path, _ in SUITES.values()}, "unapproved QA trigger path")
    validate_run_identity(run, run["path"], context["sha"])
    require(run.get("status") == "completed" and run.get("conclusion") == "success", "trigger QA not successfully completed")


def validate_run(run, path, sha, jobs):
    if run is None:
        raise NotReady("no exact-develop push QA run: " + path)
    validate_run_identity(run, path, sha)
    require(isinstance(run.get("status"), str), "malformed QA status")
    if run.get("status") in PENDING and run.get("conclusion") is None:
        raise NotReady("QA still pending: " + path)
    require(run.get("status") == "completed" and run.get("conclusion") == "success", "QA not successful: " + path)
    require(isinstance(jobs, list) and bool(jobs), "empty QA job list")
    require(all(isinstance(job, dict) and positive_id(job.get("id")) for job in jobs), "invalid QA job")
    require(len({job["id"] for job in jobs}) == len(jobs), "duplicate QA jobs")
    for job in jobs:
        require(job.get("run_id") == run["id"], "foreign QA job")
        require(job.get("head_sha") == sha, "job source mismatch")
        require(job.get("status") == "completed" and job.get("conclusion") == "success", "failed, pending or skipped QA job")
        require(isinstance(job.get("name"), str), "missing QA job name")
    required = next(names for workflow, names in SUITES.values() if workflow == path)
    require(required.issubset({job["name"] for job in jobs}), "incomplete QA job set: " + path)


def validate_settings(evidence):
    pages = evidence.get("pages")
    require(isinstance(pages, dict) and pages.get("build_type") == "workflow", "branch-based Pages forbidden")
    environment = evidence.get("environment")
    require(isinstance(environment, dict), "missing deployment environment")
    require(environment.get("name") == "github-pages", "wrong deployment environment")
    policy = environment.get("deployment_branch_policy") or {}
    require(isinstance(policy, dict), "malformed environment branch policy")
    if policy.get("custom_branch_policies"):
        require(isinstance(evidence.get("policies"), list) and {"name": "develop", "type": "branch"} in evidence["policies"], "environment must allow develop explicitly")
    # GitHub enforces active reviewers/timers/protected-branch rules. No admin
    # bypass, policy edit, alternate environment, or second identity is required.


def select(context, evidence):
    validate_context(context)
    sha = context["sha"]
    require(isinstance(evidence, dict), "malformed release evidence")
    require(isinstance(evidence.get("develop_sha"), str) and SHA.fullmatch(evidence["develop_sha"]) is not None, "invalid develop source")
    if evidence["develop_sha"] != sha:
        raise NotReady("stale source: develop changed")
    validate_settings(evidence)
    waiting = []
    for key, (path, _) in SUITES.items():
        require(key in evidence, "missing QA suite evidence: " + key)
        try:
            validate_run(evidence[key], path, sha, evidence.get(key + "_jobs"))
        except NotReady as error:
            waiting.append(str(error))
    if context["event"] == "workflow_run":
        trigger = context["payload"]["workflow_run"]
        key = next(key for key, (path, _) in SUITES.items() if path == trigger["path"])
        latest = evidence[key]
        require(isinstance(latest, dict) and (trigger["id"], trigger["run_attempt"]) == (latest["id"], latest["run_attempt"]), "trigger is not the latest QA run and attempt")
    if waiting:
        raise NotReady("; ".join(waiting))
    require(isinstance(evidence.get("artifacts"), list), "missing tested artifact evidence")
    require(all(isinstance(artifact, dict) and isinstance(artifact.get("name"), str) for artifact in evidence["artifacts"]), "malformed artifact metadata")
    artifacts = [a for a in evidence["artifacts"] if a["name"] == ARTIFACT]
    require(len(artifacts) == 1, "exactly one tested artifact required")
    artifact = artifacts[0]
    require(artifact.get("expired") is False, "expired tested artifact")
    require(positive_id(artifact.get("id")), "invalid artifact ID")
    require(type(artifact.get("size_in_bytes")) is int and 0 < artifact["size_in_bytes"] <= 2_000_000_000, "invalid artifact size")
    require(isinstance(artifact.get("digest"), str) and DIGEST.fullmatch(artifact["digest"]) is not None, "immutable SHA256 artifact digest required")
    artifact_run = artifact.get("workflow_run")
    require(isinstance(artifact_run, dict) and artifact_run.get("id") == evidence["main"]["id"], "foreign artifact run")
    require(artifact_run.get("head_sha") == sha, "foreign artifact source")
    require(timestamp(artifact.get("created_at")) >= timestamp(evidence["main"].get("run_started_at")), "artifact predates selected QA attempt")
    return {
        "schema": 1, "repository": REPOSITORY, "commit": sha,
        "qa_run_id": evidence["main"]["id"], "qa_attempt": evidence["main"]["run_attempt"],
        "safety_run_id": evidence["safety"]["id"], "safety_attempt": evidence["safety"]["run_attempt"],
        "suites": {key: {"path": path, "run_id": evidence[key]["id"], "attempt": evidence[key]["run_attempt"]} for key, (path, _) in SUITES.items()},
        "artifact_id": artifact["id"], "artifact_digest": artifact["digest"],
        "artifact_size": artifact["size_in_bytes"], "public_url": PUBLIC_URL,
    }


def recheck(context, evidence, candidate):
    try:
        actual = select(context, evidence)
    except NotReady as error:
        raise Denied("candidate no longer ready: " + str(error)) from error
    require(candidate == actual, "candidate changed during publication")
    return actual


def timestamp(value):
    require(isinstance(value, str), "missing QA/artifact timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise Denied("invalid QA/artifact timestamp") from error
    require(parsed.utcoffset() is not None, "unqualified QA/artifact timestamp")
    return parsed


class API:
    def __init__(self, token):
        require(bool(token), "workflow GitHub token required")
        self.token = token

    def get(self, path):
        require(not path.startswith("/") and "://" not in path and ".." not in path, "unsafe API path")
        request = urllib.request.Request(
            "https://api.github.com/repos/" + REPOSITORY + "/" + path,
            headers={"Authorization": "Bearer " + self.token, "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"},
        )
        # Read-only API errors including 403/404 deny release. Never log credentials.
        try:
            with urllib.request.build_opener(NoRedirect).open(request, timeout=30) as response:
                return json.load(response)
        except (urllib.error.URLError, OSError, ValueError) as error:
            raise Denied("GitHub API request failed") from error

    def pages(self, path, key):
        values = []
        for page in range(1, 101):
            separator = "&" if "?" in path else "?"
            result = self.get(f"{path}{separator}per_page=100&page={page}")
            require(isinstance(result, dict) and isinstance(result.get(key), list), "malformed API pagination response")
            rows = result[key]
            values.extend(rows)
            if len(rows) < 100:
                return values
        raise Denied("API pagination limit exceeded")

    def latest_run(self, workflow, sha):
        query = urllib.parse.urlencode({"branch": "develop", "head_sha": sha, "event": "push"})
        rows = self.pages(f"actions/workflows/{Path(workflow).name}/runs?{query}", "workflow_runs")
        # Include incomplete/failed runs. A new failed or pending retry must
        # never fall back to a historical successful run for the same commit.
        require(all(isinstance(row, dict) for row in rows), "malformed API QA run")
        require(all(isinstance(row.get("event"), str) for row in rows), "missing QA event")
        rows = [r for r in rows if r.get("event") == "push"]
        for row in rows:
            validate_run_identity(row, workflow, sha)
        if not rows:
            return None
        return max(rows, key=lambda row: (timestamp(row.get("run_started_at") or row.get("created_at")), row["id"], row["run_attempt"]))

    def collect(self, context, candidate=None):
        validate_context(context)
        def check_source():
            develop = self.get("git/ref/heads/develop")
            require(isinstance(develop, dict) and isinstance(develop.get("object"), dict), "malformed develop API source")
            develop_sha = develop["object"].get("sha")
            require(isinstance(develop_sha, str) and SHA.fullmatch(develop_sha) is not None, "invalid develop API source")
            if develop_sha != context["sha"]:
                if candidate is not None:
                    raise Denied("develop changed during publication")
                raise NotReady("stale source: develop changed")
            return develop_sha
        develop_sha = check_source()
        runs = {key: self.latest_run(path, context["sha"]) for key, (path, _) in SUITES.items()}
        policy = self.pages("environments/github-pages/deployment-branch-policies", "branch_policies")
        require(all(isinstance(row, dict) and isinstance(row.get("name"), str) and isinstance(row.get("type"), str) for row in policy), "malformed environment branch policies")
        evidence = {
            "develop_sha": develop_sha,
            "pages": self.get("pages"), "environment": self.get("environments/github-pages"),
            "policies": [{k: row[k] for k in ("name", "type")} for row in policy],
            **runs,
        }
        for key, run in runs.items():
            evidence[key + "_jobs"] = self.pages(f"actions/runs/{run['id']}/attempts/{run['run_attempt']}/jobs", "jobs") if run and run.get("status") == "completed" else []
        main = runs["main"]
        evidence["artifacts"] = self.pages(f"actions/runs/{main['id']}/artifacts", "artifacts") if main and main.get("status") == "completed" else []
        check_source()
        if candidate is not None:
            recheck(context, evidence, candidate)
        return evidence


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


def validate_storage_url(url):
    parsed = urllib.parse.urlsplit(url)
    require(parsed.scheme == "https" and not parsed.username and not parsed.password and parsed.port in (None, 443), "unsafe artifact redirect")
    hostname = parsed.hostname or ""
    require(hostname.endswith(".blob.core.windows.net") or hostname.endswith(".githubusercontent.com"), "unexpected artifact storage host")


class StorageRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        validate_storage_url(newurl)
        redirected = super().redirect_request(request, fp, code, msg, headers, newurl)
        if redirected is not None:
            redirected.remove_header("Authorization")
        return redirected


def download_artifact(api, candidate, target):
    """Authenticate only against api.github.com; never forward token to storage."""
    url = f"https://api.github.com/repos/{REPOSITORY}/actions/artifacts/{candidate['artifact_id']}/zip"
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + api.token, "Accept": "application/vnd.github+json"})
    try:
        response = urllib.request.build_opener(NoRedirect).open(request, timeout=30)
    except urllib.error.HTTPError as error:
        try:
            require(error.code in (301, 302, 303, 307, 308), f"artifact download API refused request ({error.code})")
            location = error.headers.get("Location", "")
        finally:
            error.close()
        validate_storage_url(location)
        # Fresh request, no Authorization header and no signed URL in logs.
        response = urllib.request.build_opener(StorageRedirect).open(urllib.request.Request(location), timeout=60)
    target = Path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    digest, size = hashlib.sha256(), 0
    try:
        with response, target.open("xb") as output:
            while chunk := response.read(1024 * 1024):
                size += len(chunk)
                require(size <= candidate["artifact_size"], "oversized artifact body")
                digest.update(chunk)
                output.write(chunk)
        require(size == candidate["artifact_size"], "truncated artifact body")
        require("sha256:" + digest.hexdigest() == candidate["artifact_digest"], "artifact digest mismatch")
    except Exception:
        target.unlink(missing_ok=True)
        raise


def extract_web(archive, destination, candidate):
    destination = Path(destination)
    require(not destination.exists(), "refuse to overwrite an existing release directory")
    selected, names, total = [], set(), 0
    with zipfile.ZipFile(archive) as package:
        for entry in package.infolist():
            name = entry.filename
            path = PurePosixPath(name)
            require(not path.is_absolute() and ".." not in path.parts and "\\" not in name and ":" not in name, "unsafe artifact member")
            require(str(path) == name.rstrip("/"), "noncanonical artifact member")
            require(name not in names, "duplicate artifact member")
            names.add(name)
            require(not stat.S_ISLNK(entry.external_attr >> 16), "symlink artifact member")
            require(not entry.flag_bits & 1, "encrypted artifact member")
            total += entry.file_size
            require(total <= 4_000_000_000, "oversized extracted artifact")
            if name.startswith("build/web/") and not entry.is_dir():
                relative = path.relative_to("build/web")
                require(bool(relative.parts), "empty release path")
                selected.append((entry, relative))
        require(bool(selected), "tested Web export missing")
        info_name = "build/web/build-info.json"
        require(info_name in names and "build/web/index.html" in names, "release entry or identity missing")
        require("build/web/release-evidence.json" not in names, "reserved release provenance must not exist in the QA export")
        info = json.loads(package.read(info_name))
        require(info["commit"] == candidate["commit"] and info["channel"] == "develop", "export source mismatch")
        # Existing tested Alpha exports contain commit/channel but no run_id.
        # The immutable v4 artifact binds them to the run; the new independent
        # release-evidence file records that run without rewriting tested bytes.
        require(info.get("run_id") is None or str(info["run_id"]) == str(candidate["qa_run_id"]), "export QA run mismatch")
        for entry, relative in selected:
            target = destination.joinpath(*relative.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            with package.open(entry) as source, target.open("xb") as output:
                while chunk := source.read(1024 * 1024):
                    output.write(chunk)
    files = {}
    for path in sorted(destination.rglob("*")):
        if path.is_file():
            with path.open("rb") as source:
                files[str(path.relative_to(destination))] = hashlib.file_digest(source, "sha256").hexdigest()
    require(sum(name.endswith(".pck") for name in files) == 1 and sum(name.endswith(".wasm") for name in files) == 1, "exactly one PCK/WASM export required")
    manifest = {"schema": 1, "candidate": candidate, "files": files}
    (destination / "release-evidence.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def verify_public(candidate):
    # Query and cache directives prevent accepting a stale proxy response.
    url = PUBLIC_URL + "build-info.json?release=" + candidate["commit"]
    request = urllib.request.Request(url, headers={"Cache-Control": "no-cache"})
    with urllib.request.urlopen(request, timeout=30) as response:
        info = json.load(response)
    require(info["commit"] == candidate["commit"], "public commit mismatch")
    evidence_url = PUBLIC_URL + "release-evidence.json?release=" + candidate["commit"]
    with urllib.request.urlopen(urllib.request.Request(evidence_url, headers={"Cache-Control": "no-cache"}), timeout=30) as response:
        evidence = json.load(response)
    require(evidence["candidate"] == candidate, "public release provenance mismatch")
    return info


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("select", "recheck", "download", "verify-public"))
    parser.add_argument("--output", default="work/release-candidate.json")
    args = parser.parse_args()
    context = context_from_env()
    validate_context(context)
    api = API(os.environ.get("GH_TOKEN", ""))
    candidate = json.loads(os.environ["RELEASE_CANDIDATE"]) if args.command != "select" else None
    if args.command == "select":
        try:
            candidate = select(context, api.collect(context))
        except NotReady as error:
            with open(os.environ["GITHUB_OUTPUT"], "a") as outputs:
                outputs.write("ready=false\n")
            print("Release not ready:", error)
            return
        target = Path(args.output)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(candidate, indent=2) + "\n")
        with open(os.environ["GITHUB_OUTPUT"], "a") as outputs:
            outputs.write("ready=true\n")
            outputs.write("commit=" + candidate["commit"] + "\n")
            outputs.write("candidate=" + json.dumps(candidate, separators=(",", ":")) + "\n")
    elif args.command == "recheck":
        recheck(context, api.collect(context, candidate), candidate)
    elif args.command == "download":
        recheck(context, api.collect(context, candidate), candidate)
        download_artifact(api, candidate, "work/release-candidate.zip")
        manifest = extract_web("work/release-candidate.zip", "work/release-web", candidate)
        evidence_digest = hashlib.sha256(Path("work/release-web/release-evidence.json").read_bytes()).hexdigest()
        with open(os.environ["GITHUB_OUTPUT"], "a") as outputs:
            outputs.write("evidence_sha256=" + evidence_digest + "\n")
        print("Verified release files:", len(manifest["files"]))
    else:
        verify_public(candidate)
    print(json.dumps(candidate, sort_keys=True))


if __name__ == "__main__":
    main()
