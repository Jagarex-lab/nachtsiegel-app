# Delivery and Alpha release policy

The owner has approved automatic publication of the Alpha test version from
`develop`. This approval supersedes the former manual-only release freeze.
Owner-approved PRs, including Codex work covered by the current standing owner
approval, may be merged without another permission prompt once every required
check is green on the current expected PR-head SHA. Use regular merges and obey
all GitHub branch, review and environment protections; recheck the expected SHA
before merging. Do not enable native auto-merge or an arbitrary-PR merge daemon.

The sole publisher is `.github/workflows/pages-release.yml`. Its automatic
`workflow_run` path requires all seven trusted post-merge develop QA suites and
all 29 required jobs on the exact current develop SHA. An inputless dispatch on
develop is the fallback. Publish only the immutable, tested v4 QA artifact;
never rebuild or release feature branches, PR refs, tags or untested artifacts.
Keep the existing protected `github-pages` environment and release concurrency.
Only its publish job receives Pages/OIDC write permissions.

Normal owner/GitHub App merges must produce the develop push QA events. A merge
performed only with `GITHUB_TOKEN` suppresses those events and is unsupported;
do not bypass missing QA with tokens, settings changes or alternate publishers.
The staged `.yml.in` file remains an inactive historical proposal.

See `docs/release/PAGES_RELEASE_SAFETY.md` and
`docs/premium/RELEASE_AUTOMATION.md` for evidence, verification and rollback.
Review the release policy again before any commercial release. Keep main,
gameplay rules, five paths and production assets unchanged unless separately
requested.
