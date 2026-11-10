# ORAFOLD audio style guide

The sound world is dark modern science fantasy: a material impulse followed by a
brief, displaced harmonic memory. Keep tactical decisions quiet. Leave space
between events. The neutral language is restrained material and resonance, not a
fifth faction motif. The new production is an original first production library;
subjective mix approval on physical devices remains an integration acceptance step.

## Materials and identities

| Power | Canonical audio key | Material / gesture | Intended feeling |
| --- | --- | --- | --- |
| Zwölf Häuser | `zwoelf_haeuser` | Warm inharmonic metal, low resonant bodies, delayed bell tail | Dignified, melancholic, remembered |
| Stillwacht | `stillwacht` | High glass modes, precise short onset, controlled decay | Cold, calm, stable |
| Vielgestalt | `vielgestalt` | Layered FM motion, irregular moving partials, organic pitch | Living, changing, adaptive |
| Neunte Stunde | `neunte_stunde` | Growing reverse contour, shifted repeat, suspended lower tone | Causal displacement, intelligent unease |
| Neutral | no layer | Understated base cue | Universal feedback |

A faction layer is a short accent on semantic events, not a continuous ambience.
Base action cues remain legible beneath it. The audio router maps existing project
faction IDs; do not rename gameplay factions to satisfy these keys.

Faction accents use −5 dB catalog attenuation plus the runtime's −3 dB layer
offset (−8 dB relative to an equal-level base clip). Rarity accents use −8 dB
catalog attenuation plus a −5 dB runtime offset (−13 dB). This deliberate layer
budget leaves faction timbres perceptible while reserving foreground space for the
action. It is a numeric mix design, not a listening approval: differing RMS and
spectral density still require device and combined-event review. In particular,
the reverse Neunte-Stunde contour sustains more energy than the other accents.

## Cards, combat, resonance and relics

Card draw uses four noise/material, impulse and light resonance variants at a quiet
level. Hover/move remain especially soft. Manifestation uses organic growth;
impulse play uses a compact reverse contour; relic play adds a low metal body with
a longer tail. Common actions have two to four authored variants; the runtime
avoids immediate variant repetition and applies only small pitch variation.

Combat onset, hit, protection, healing, defeat and reaction have separate materials.
A strong-hit cue exists for a later explicitly supplied semantic event; its presence
asserts no critical-hit rule. Intensity is an audio-only 0–1 parameter provided by
the caller; the router must never infer damage, a winner or engine thresholds.

Resonance is a 220-Hz-root harmonic family. Low is an isolated impulse; medium
adds length and harmonic depth; high opens a broader tail. Gain rises in harmonic
clarity, spending contracts through a reverse discharge, and unleash has a distinct
low, layered signature. These are one-shot tiers, **not** automatic numeric gameplay
thresholds and **not** an always-on drone.

Relic play/activation are deliberate warm metal events. Passive activation is shorter
and quieter. Spend, replace and destroy are separate. A later legendary-specific
clip may be assigned via the catalog; no invented relic card identity is attached
to the generic legendary layer.

Common rarity uses the base cue. Rare adds a brief glass memory, epic a spatial
harmonic response, legendary a deeper metal signature. Each accent is attenuated;
rarity must not be treated as a louder mixer target. Preserve faction timbre and
check combined playback against the runtime's voice and gain budgets.

## Music

Nine real pieces are supplied: menu, collection, deckbuilder, duel, tense,
convergence, campaign, victory and defeat. Seven 32/40-second stereo loops use
slow chord movement, sparse original motifs, low synth/string-like partials,
metallic memory tones and restrained rhythmic impulses. Victory and defeat are
7/7.5-second nonlooping stingers. Campaign is an extensible seed piece, not a claim
that a campaign or scene integration exists.

Loop oscillators use exact whole cycles and circular pad/note envelopes; no
silence gap is inserted at a loop boundary. Vorbis import settings explicitly mark
loops. Crossfades are time based and do not promise beat-synchronized stems.
Tense/convergence selection is a caller instruction, never an audio-owned state
machine. The neutral `ambience.rift` is a quiet optional room bed with no faction
or resonance claim.

## Production and mix specification

- Short effects: 32 kHz mono, 16-bit PCM WAV. Designed source peak at −6 dBFS;
  event gains usually attenuate by another 10–20 dB before the user mix.
- Music/ambience: 32 kHz stereo, Vorbis quality 4. Source music peak −10 dBFS;
  catalog attenuation preserves room for foreground actions.
- Soft attack/release envelopes, filtered material noise, DC removal and bounded
  peaks avoid cuts, low-frequency bias and unintended clipping.
- Loops and stingers carry different explicit import settings. Short effects are
  cached; longer compressed tracks are loaded on demand by the music controller.
- Source peak/RMS are recorded per asset. These are sample measurements, not
  LUFS calibration or an acoustic loudness certification.

Review at low and normal playback levels on headphones, laptop speakers and phone
speakers. Confirm cue legibility, stereo compatibility, no fatiguing resonance,
quiet tactical pauses, balanced simultaneous layers and loop/crossfade seams.
Reduced intensity should shorten the perceptual foreground and suppress optional
layers; it never changes game rules or invents missing state information.
