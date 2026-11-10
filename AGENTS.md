# Delivery and release policy

CI, branch pushes and PR merges do not authorize production publication.
Do not merge PRs or release without the user's explicit, current approval.
Use the reviewed manual Pages release workflow and its protected environment.
Never restore automatic publishing on develop or bypass approval with a token,
branch build, alternate workflow, or environment change. See
`docs/release/PAGES_RELEASE_SAFETY.md` for activation, release and rollback.
Keep main, gameplay rules, five paths and production assets unchanged unless
separately requested. Feature branches and QA artifacts are not releases.
