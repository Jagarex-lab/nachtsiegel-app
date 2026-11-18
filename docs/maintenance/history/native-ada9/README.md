# Historical native failure evidence

The compact read-only evidence ZIP is copied from GitHub artifact [13896451760](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/43111438143/artifacts/13896451760), produced by successful one-shot [recovery run 43111438143](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/43111438143) on `qa/recover-native-ada9@f75162851bbd7eb57495919958de849c574f6420`.

ZIP SHA-256: `95877df888e4b5a129a5bada8fa8032b06e7809623809acb93dff905ffec9bfc` (262,491 bytes), verified against GitHub and after this copy. GitHub created it at `2026-11-11T22:24:27Z`; its server expiry is `2026-12-11T22:24:26Z`. The committed local copy preserves the bounded JSON/log evidence independently of server retention. The adjacent inventory records its eight entries and digest. No ZIP entry was executed.

Original failure: source `ada9ef91344b8df8042745ba089e6249d3dff478`, Windows artifact `13895866598`, run `43109351972`, failed job `130821145320`. A successful recovery proves retrieval only; it does not turn the original failed job into a pass. New baseline/current-head QA is separate evidence.

Only the compact evidence is preserved. Neither the old executable package nor its branch-only `.github/workflows/native-evidence-recovery.yml` is activated or copied into an Actions directory. Keep the source ref until this preservation PR is accepted; any later ref deletion requires a new exact-head check. This history directory is excluded from Godot imports by `.gdignore`.
