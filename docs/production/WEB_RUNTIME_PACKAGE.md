# Web runtime package: build metadata removal

This is a packaging change for **Web QA** and **Alpha Web QA** only. Native,
Archive and Legacy export preset blocks are byte-for-byte unchanged. No card,
rule, original image or provenance data is removed from the repository.

The normal Web runtime has no script/scene references to `art_sources.json`,
`art_source_map.json`, `art_briefs.json`, `authoring.json` or `art_previews.json`.
These are authoring, provenance and derivative-build inputs. Their combined
5,245,072 bytes do not need to be downloaded inside the initial PCK.
Build tools and native canonical provenance verification still use them.

The runtime retains `cards.json`, `art_manifest.json`, `art_delivery.json`,
`art_preview_delivery.json` and `test_decks.json`. `art_manifest.json` already
provides every original/preview path, hash, dimension and individual-art status
needed by the resolver. Its provenance path is a repository reference, not a
runtime load instruction. No external image, cache or HTTP policy changes.

## Measured package check

The preserved Web171 artifact receipt is in
`work/production-art/web171-before-build-metadata-removal.json`. It contains the
SHA-256 and size of every previous staged file. The previous source commit was
`17134e4daf5f0bd0203294e125e1803ec973d279`; original and derivative inputs remain
available for reproduction. The initial after measurement used this packaging
patch over `b6f39bd7cfdb250a80fd1cbf208da7244698d364`. An exact committed rebuild
is required before subsequent browser QA; build-info records that commit.

| Measurement | Before | After | Removed |
| --- | ---: | ---: | ---: |
| Actual PCK bytes | 22,404,608 | 17,159,136 | 5,245,472 |
| Inventoried resource bytes | 22,348,490 | 17,103,418 | 5,245,072 |

The payload reduction exactly equals the five excluded JSON files. The extra
400 bytes of PCK reduction are pack file-table/alignment overhead. The measured
PCK reduction is 23.41%; this does **not** measure startup time, network transfer
latency, browser memory or real-device performance.

The actual PCK was opened from an empty directory, without checkout resource
fallback. All **5,535 assertions passed**: exactly 550 distinct valid runtime
catalog IDs match 550 individual-art manifest bindings; all original and preview
path/dimension/hash bindings are checked; zero full textures and five pinned
previews are packed; all five build JSON files are absent. Native mode retains
its separate canonical `art_sources.json` hash/dimension crosscheck. No previous
art test cases were removed.

Machine-readable measured sizes, hashes, absent/retained paths and limitations:
[web-runtime-package-trim.json](art-evidence/web-runtime-package-trim.json).

## Reproduce

```sh
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS=2
bash tools/build_alpha.sh
# The build automatically runs both isolated package inventory and art checks.
# Recheck the resulting PCK independently:
bash tools/test_production_art_package.sh work/alpha/web/orafold-<commit12>.pck web
```

Logs: `work/alpha/package-inspection.log`,
`work/alpha/art-package-inspection.log` and
`work/production-art/exported-art-package-web.log`. This CLI packaging check
runs no browser, renderer, production deployment or physical-device test.
