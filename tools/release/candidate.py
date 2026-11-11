"""Read-only, fail-closed candidate discovery for the INACTIVE one-click proposal.

This module never dispatches a workflow, edits settings, merges, or deploys. The
active manual publisher deliberately continues to use the unchanged guard.py.
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


class Denied(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise Denied(message)


def context_from_env():
    return {key: os.environ[name] for key, name in {
        "repository": "GITHUB_REPOSITORY", "event": "GITHUB_EVENT_NAME",
        "ref": "GITHUB_REF", "sha": "GITHUB_SHA",
    }.items()}


def validate_context(context):
    require(context["repository"] == REPOSITORY, "wrong repository")
    require(context["event"] == "workflow_dispatch", "explicit manual dispatch only")
    require(context["ref"] == REF, "develop branch only; no tags or PR refs")
    require(SHA.fullmatch(context["sha"]) is not None, "full lowercase SHA required")


def validate_run(run, path, sha, jobs):
    require(run["repository"]["full_name"] == REPOSITORY, "foreign QA repository")
    require(run.get("head_repository", {}).get("full_name") == REPOSITORY, "foreign head repository")
    require(run["head_sha"] == sha and run["head_branch"] == "develop", "QA source mismatch")
    require(run["event"] in ("push", "workflow_dispatch"), "PR or untrusted QA event")
    require(run["path"] == path, "wrong QA workflow path")
    require(run["status"] == "completed" and run["conclusion"] == "success", "QA not successful")
    require(isinstance(run["id"], int) and run["id"] > 0, "invalid run ID")
    require(isinstance(run["run_attempt"], int) and run["run_attempt"] > 0, "invalid run attempt")
    require(bool(jobs), "empty QA job list")
    require(len({job["id"] for job in jobs}) == len(jobs), "duplicate QA jobs")
    for job in jobs:
        require(job["run_id"] == run["id"], "foreign QA job")
        require(job["head_sha"] == sha, "job source mismatch")
        require(job["status"] == "completed" and job["conclusion"] == "success", "failed, pending or skipped QA job")
    # The main workflow already includes native, browser, audio, integration,
    # resources, full-pool and balance jobs. Do not accept a reduced smoke run.
    if path == MAIN:
        names = {job["name"] for job in jobs}
        require(MAIN_JOBS.issubset(names), "incomplete main QA job set")
    else:
        require(any(job["name"] == "release-safety" for job in jobs), "missing release-safety job")


def validate_settings(evidence):
    require(evidence["pages"]["build_type"] == "workflow", "branch-based Pages forbidden")
    environment = evidence["environment"]
    require(environment.get("name") == "github-pages", "wrong deployment environment")
    policy = environment.get("deployment_branch_policy") or {}
    if policy.get("custom_branch_policies"):
        require({"name": "develop", "type": "branch"} in evidence["policies"], "environment must allow develop explicitly")
    # GitHub enforces active reviewers/timers/protected-branch rules. No admin
    # bypass, policy edit, alternate environment, or second identity is required.


def select(context, evidence):
    validate_context(context)
    sha = context["sha"]
    require(evidence["develop_sha"] == sha, "stale dispatch: develop changed")
    validate_settings(evidence)
    validate_run(evidence["main"], MAIN, sha, evidence["main_jobs"])
    validate_run(evidence["safety"], SAFETY, sha, evidence["safety_jobs"])
    artifacts = [a for a in evidence["artifacts"] if a["name"] == ARTIFACT]
    require(len(artifacts) == 1, "exactly one tested artifact required")
    artifact = artifacts[0]
    require(artifact["expired"] is False, "expired tested artifact")
    require(isinstance(artifact["id"], int) and artifact["id"] > 0, "invalid artifact ID")
    require(0 < artifact["size_in_bytes"] <= 2_000_000_000, "invalid artifact size")
    require(isinstance(artifact.get("digest"), str) and DIGEST.fullmatch(artifact["digest"]) is not None, "immutable SHA256 artifact digest required")
    require(artifact["workflow_run"]["id"] == evidence["main"]["id"], "foreign artifact run")
    require(artifact["workflow_run"]["head_sha"] == sha, "foreign artifact source")
    return {
        "schema": 1, "repository": REPOSITORY, "commit": sha,
        "qa_run_id": evidence["main"]["id"], "qa_attempt": evidence["main"]["run_attempt"],
        "safety_run_id": evidence["safety"]["id"], "safety_attempt": evidence["safety"]["run_attempt"],
        "artifact_id": artifact["id"], "artifact_digest": artifact["digest"],
        "artifact_size": artifact["size_in_bytes"], "public_url": PUBLIC_URL,
    }


def recheck(context, evidence, candidate):
    actual = select(context, evidence)
    require(candidate == actual, "candidate changed while awaiting approval; dispatch again")
    return actual


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
        # Read-only API errors including403/404 propagate. Never log credentials.
        with urllib.request.build_opener(NoRedirect).open(request, timeout=30) as response:
            return json.load(response)

    def pages(self, path, key):
        values = []
        for page in range(1, 101):
            separator = "&" if "?" in path else "?"
            result = self.get(f"{path}{separator}per_page=100&page={page}")
            rows = result[key]
            values.extend(rows)
            if len(rows) < 100:
                return values
        raise Denied("API pagination limit exceeded")

    def latest_run(self, workflow, sha):
        query = urllib.parse.urlencode({"branch": "develop", "head_sha": sha})
        rows = self.pages(f"actions/workflows/{Path(workflow).name}/runs?{query}", "workflow_runs")
        # Include incomplete/failed runs. A new failed or pending retry must
        # never fall back to a historical successful run for the same commit.
        rows = [r for r in rows if r["head_sha"] == sha and r["head_branch"] == "develop" and r["event"] in ("push", "workflow_dispatch")]
        require(bool(rows), "no exact-develop QA run: " + workflow)
        return max(rows, key=lambda row: (row.get("run_started_at", row.get("created_at", "")), row["id"], row["run_attempt"]))

    def collect(self, context, candidate=None):
        validate_context(context)
        main = self.latest_run(MAIN, context["sha"])
        safety = self.latest_run(SAFETY, context["sha"])
        if candidate is not None:
            require(main["id"] == candidate["qa_run_id"] and safety["id"] == candidate["safety_run_id"], "newer QA run requires a fresh release dispatch")
        policy = self.pages("environments/github-pages/deployment-branch-policies", "branch_policies")
        return {
            "develop_sha": self.get("git/ref/heads/develop")["object"]["sha"],
            "pages": self.get("pages"), "environment": self.get("environments/github-pages"),
            "policies": [{k: row[k] for k in ("name", "type")} for row in policy],
            "main": main, "safety": safety,
            "main_jobs": self.pages(f"actions/runs/{main['id']}/attempts/{main['run_attempt']}/jobs", "jobs"),
            "safety_jobs": self.pages(f"actions/runs/{safety['id']}/attempts/{safety['run_attempt']}/jobs", "jobs"),
            "artifacts": self.pages(f"actions/runs/{main['id']}/artifacts", "artifacts"),
        }


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
        candidate = select(context, api.collect(context))
        target = Path(args.output)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(candidate, indent=2) + "\n")
        with open(os.environ["GITHUB_OUTPUT"], "a") as outputs:
            outputs.write("commit=" + candidate["commit"] + "\n")
            outputs.write("candidate=" + json.dumps(candidate, separators=(",", ":")) + "\n")
    elif args.command == "recheck":
        recheck(context, api.collect(context, candidate), candidate)
    elif args.command == "download":
        recheck(context, api.collect(context, candidate), candidate)
        download_artifact(api, candidate, "work/release-candidate.zip")
        manifest = extract_web("work/release-candidate.zip", "work/release-web", candidate)
        print("Verified release files:", len(manifest["files"]))
    else:
        verify_public(candidate)
    print(json.dumps(candidate, sort_keys=True))


if __name__ == "__main__":
    main()
