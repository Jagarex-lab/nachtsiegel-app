# ORAFOLD audio provenance and rights

Production date: 2026-11-10. New assets live only in the new audio subdirectories.
The existing files directly under `assets/audio/` retain their existing provenance
in `assets/audio/README.md`; none was replaced or incorporated into the new work.

## New production

Every new WAV and Ogg file is synthesized locally by
[`scripts/audio/generate_audio.py`](../../scripts/audio/generate_audio.py). Source
material consists exclusively of oscillators, seeded mathematical noise, filters,
envelopes, delay, and original note sequences written for this order. There are no
recordings, downloaded samples, external compositions, voice models, or attempts
to imitate an existing soundtrack. No network is needed for synthesis.

Author/source: original procedural production for the ORAFOLD project, generated
through the repository's production workflow on 2026-11-10. Repository owner rights
and use terms follow [`LICENSE-NOTICE.md`](../../LICENSE-NOTICE.md): original game
assets have no public open-source license grant. The project owner may use this
commissioned production locally and in commercial game builds under its existing
project rights. This statement does not assert exclusive ownership of mathematical
tones or make a third-party sample-license claim.

[`data/audio/asset_manifest.json`](../../data/audio/asset_manifest.json) is the
per-file inventory: exact source path, clip ID, SHA-256, production date (top-level),
source procedure, rights category, duration, channels, rate, size, source peak and
source RMS. Together with the generator it documents provenance for **each** file.
Audio versions are represented by Git history and these hashes.

| Component | Source / author | Terms / usage | Changes | Date |
| --- | --- | --- | --- | --- |
| New SFX WAV files | Original synthesis; ORAFOLD production workflow | Repository original asset rights, no external restrictions | Designed, synthesized, filtered, enveloped, peak limited; 16-bit export | 2026-11-10 |
| New music / ambience Ogg files | Original synthesis and note sequences; ORAFOLD production workflow | Repository original asset rights, no external restrictions | Composed, synthesized, stereo mixed; Vorbis compression and loop import settings | 2026-11-10 |
| NumPy production dependency | NumPy developers, https://numpy.org/ | BSD-3-Clause; build tool only, no library bundled into Godot exports | None | 2026-11-10 |
| FFmpeg production dependency | FFmpeg developers, https://ffmpeg.org/legal.html | Installed build's LGPL/GPL terms; build tool only, no binary bundled into Godot exports | PCM-to-Vorbis encoding only | 2026-11-10 |

No external audio files were used. If a later production adds any, add a per-file
source URL, creator, license text/version, commercial-use and attribution terms,
modifications, and acquisition date before placing it in the catalog.

## Reproduction

Run `python3 scripts/audio/generate_audio.py` from the repository with Python 3,
NumPy and FFmpeg available. Seeds and PCM synthesis are deterministic. Vorbis
container/encoder metadata and therefore Ogg hashes may vary with FFmpeg/libvorbis
versions; the manifest is updated to match the produced bytes. No opaque generator
weights or remote service are required. Do not rerun `--effects-only` over a full
catalog for release: this diagnostic option intentionally outputs an effects-only
catalog and must be followed by a full rebuild.
