# Original project audio

All audio in this directory is synthesized by `tools/generate_audio.py` from
sine waves and deterministically seeded noise. No recordings, downloaded sound
libraries, third-party samples or generated imitations of existing music are used.
The project owner may use these assets commercially under the existing project
rights in `LICENSE-NOTICE.md`; no separate third-party audio licence is required.
This is a provenance statement, not a claim of exclusive rights to mathematical tones.

The atmosphere is an original, restrained harmonic sound bed, not a composed
orchestral soundtrack. WAV cues: 24 kHz, mono, 16-bit PCM, bounded peaks and
click-free envelopes. Atmosphere: Vorbis, 12 seconds, looping. All sources are
reproducible with Python's standard library and ffmpeg; no network is used.

Separate buses: Music, SFX and UI. Audio starts after the first real interaction;
muting and independent gains are retained locally. A maximum of eight SFX voices,
two UI voices and one music player can exist. No paid/remote streaming services.
