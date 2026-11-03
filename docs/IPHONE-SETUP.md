# iPhone-only setup

1. Open the repository's Actions tab. If prompted, enable workflows.
2. Open the **Godot Web Preview** workflow and inspect the latest run.
3. If the run succeeds, open Settings → Pages → Build and deployment → Source → GitHub Actions.
4. Rerun the workflow via Actions → Godot Web Preview → Run workflow (branch: develop).
5. Open the Pages URL shown in the deployment job.

If GitHub Pages is unavailable for this private repository on your plan, use the downloadable workflow artifact (a ZIP containing the web build) for testing via another static hosting service, or change repository visibility only if you explicitly want it public.

The export runs on a cloud runner. You do not need to install Godot on your iPhone.

This is a basic mechanics/layout prototype, not a visual-quality milestone or complete v2.5 port.
