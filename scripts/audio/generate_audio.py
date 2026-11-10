#!/usr/bin/env python3
"""Rebuild ORAFOLD's original audio. Requires numpy and ffmpeg, no network.

Stable seeds, explicit envelopes, peak ceilings and periodic music oscillators
make the source auditable. This is sound design, never gameplay state logic.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
RATE = 32000
PEAK_SFX = 10 ** (-6 / 20)
PEAK_MUSIC = 10 ** (-10 / 20)
CATALOG = {"version": 1, "clips": {}, "music": {}}
EVENTS = {"version": 1, "events": {}}
FACTS = []


def seed_for(name):
    return int.from_bytes(hashlib.sha256(name.encode()).digest()[:8], "little")


def envelope(t, duration, attack=.007, release=.09):
    return np.sin(np.minimum(t / attack, 1) * np.pi / 2) ** 2 * np.sin(
        np.minimum((duration - t) / release, 1) * np.pi / 2
    ) ** 2


def tone(t, frequency, decay, fm=0., ratio=1.618):
    return np.sin(2 * np.pi * frequency * t + fm * np.sin(2 * np.pi * frequency * ratio * t)
                  * np.exp(-5 * t)) * np.exp(-decay * t)


def filtered_noise(rng, count, low, high):
    signal = rng.normal(size=count)
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    spectrum = np.fft.rfft(signal)
    # Smooth filter shoulders avoid abrupt spectral boundaries.
    window = np.exp(-(frequencies / high) ** 4) * (1 - np.exp(-(frequencies / low) ** 4))
    signal = np.fft.irfft(spectrum * window, n=count)
    return signal / max(float(np.std(signal)), .0001)


def echo(signal, delay, gain):
    offset = int(delay * RATE)
    if 0 < offset < len(signal):
        signal[offset:] += signal[:-offset].copy() * gain
    return signal


def sfx(name, family, duration, frequency, variant):
    rng = np.random.default_rng(seed_for(name))
    t = np.arange(round(duration * RATE)) / RATE
    f = frequency * (1 + (variant - 1) * .027)
    noise = filtered_noise(rng, len(t), 650, 6800)
    # Separate materials preserve event semantics at equal peak levels.
    if family == "card":
        body = .22 * noise * np.exp(-38 * t) + .46 * tone(t, f, 9, .55)
        body += .12 * tone(t, f * 2.03, 17) + .12 * np.sin(2*np.pi*(180*t+190*t*t)) * np.exp(-26*t)
        echo(body, .071 + variant * .005, .16)
    elif family == "glass":
        body = sum(a * tone(t, f * ratio, decay) for a, ratio, decay in
                   [(1, 1, 4), (.24, 2.756, 9), (.12, 4.071, 15)])
        body += .07 * noise * np.exp(-60 * t)
        echo(body, .093, .13)
    elif family == "impact":
        phase = 2 * np.pi * (f * t + 44 * (1 - np.exp(-30*t)) / 30)
        body = .8 * np.sin(phase) * np.exp(-9*t) + .20 * noise * np.exp(-35*t)
        body += .17 * tone(t, f*3.17, 13, 1.6)
        echo(body, .053, .12)
    elif family == "shield":
        body = .6 * tone(t, f, 6, 2.6) + .27 * tone(t, f*1.502, 7, .4)
        body += .12 * filtered_noise(rng, len(t), 1000, 4200) * np.exp(-18*t)
        echo(body, .089, .22)
    elif family == "reverse":
        rise = np.sin(np.minimum(t / (duration * .59), 1) * np.pi / 2) ** 3
        body = .55 * np.sin(2*np.pi*(f*t+f*.4*t*t)) * rise * np.exp(-2*t)
        body += .18 * noise * rise * np.exp(-6*t)
        body += .25 * tone(t, f*.5, 3.5, .7)
        echo(body, .147, .25)
    elif family == "organic":
        modulation = .8 * np.sin(2*np.pi*5.7*t) + .32 * np.sin(2*np.pi*9.3*t)
        body = .5 * np.sin(2*np.pi*f*t + modulation) * np.exp(-3.4*t)
        body += .23 * tone(t, f*1.2599, 4.5, 2.1) + .09 * noise * np.exp(-12*t)
        echo(body, .113, .2)
    elif family == "metal":
        body = sum(a * tone(t, f * ratio, decay, .35) for a, ratio, decay in
                   [(1,1,3),(.33,2.01,4),(.2,3.93,7),(.1,6.37,12)])
        body += .06 * noise * np.exp(-45*t)
        echo(body, .163, .22)
    elif family == "resonance":
        body = sum(a * tone(t, f*ratio, decay, .13) for a,ratio,decay in
                   [(.6,1,3.2),(.27,1.5,3.8),(.18,2,4.6),(.13,2.5,6)])
        body *= .8 + .2*np.cos(2*np.pi*3*t)
        echo(body, .127, .28)
    elif family == "ui":
        body = .65*tone(t,f,18,.25)+.13*tone(t,f*1.5,22)+.025*noise*np.exp(-55*t)
    else:
        raise ValueError(family)
    body *= envelope(t, duration, .008, min(.16, duration*.25))
    body -= np.mean(body)
    body *= envelope(t, duration, .003, .016)
    body *= PEAK_SFX / max(float(np.max(np.abs(body))), .001)
    return body


def write_audio(clip_id, relative, signal, bus, gain_db=0., loop=False):
    target = ROOT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.round(np.clip(signal, -.99, .99)*32767).astype("<i2")
    channels = 1 if signal.ndim == 1 else signal.shape[1]
    if target.suffix == ".wav":
        with wave.open(str(target), "wb") as stream:
            stream.setnchannels(channels)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(pcm.tobytes())
    else:
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "s16le",
                        "-ar", str(RATE), "-ac", str(channels), "-i", "pipe:0", "-c:a",
                        "libvorbis", "-q:a", "4", "-map_metadata", "-1", str(target)],
                       input=pcm.tobytes(), check=True)
        # Check in explicit import settings so Godot loops only the intended files.
        import_path = str(target.relative_to(ROOT)).replace("\\", "/")
        digest = hashlib.md5(("res://" + import_path).encode()).hexdigest()
        import_settings = target.parent / (target.name + ".import")
        existing_uid = ""
        if import_settings.exists():
            match = re.search(r'^uid="([^"]+)"$', import_settings.read_text(encoding="utf-8"), re.MULTILINE)
            if match:
                existing_uid = f'uid="{match.group(1)}"\n'
        import_settings.write_text(
            '[remap]\n\nimporter="oggvorbisstr"\ntype="AudioStreamOggVorbis"\n'
            + existing_uid + f'path="res://.godot/imported/{target.name}-{digest}.oggvorbisstr"\n\n'
            '[deps]\n\n'+f'source_file="res://{import_path}"\n'
            f'dest_files=["res://.godot/imported/{target.name}-{digest}.oggvorbisstr"]\n\n'
            '[params]\n\n'+f'loop={str(loop).lower()}\nloop_offset=0\nbpm=0\nbeat_count=0\nbar_beats=4\n',
            encoding="utf-8")
    CATALOG["clips"][clip_id] = {"path": "res://"+relative, "bus": bus,
                                  "gain_db": gain_db, "loop": loop}
    FACTS.append({"id":clip_id,"path":relative,"duration_seconds":round(len(signal)/RATE,3),
                  "channels":channels,"sample_rate":RATE,"bytes":target.stat().st_size,
                  "sha256":hashlib.sha256(target.read_bytes()).hexdigest(),
                  "source_peak_dbfs":round(20*np.log10(max(float(np.max(np.abs(signal))),1e-9)),2),
                  "source_rms_dbfs":round(20*np.log10(max(float(np.sqrt(np.mean(signal**2))),1e-9)),2),
                  "provenance":"original procedural synthesis", "license":"repository original asset rights"})


# name, directory, family, seconds, pitch, variants, level, priority
SPECS = [
    ("ui.hover","ui","ui",.16,590,3,-17,0),
    ("ui.select","ui","ui",.25,410,3,-12,1),
    ("ui.confirm","ui","glass",.45,530,2,-13,1),
    ("ui.cancel","ui","ui",.27,275,2,-13,1),
    ("ui.error","ui","ui",.32,190,2,-15,1),
    ("card.draw","cards","card",.48,330,4,-11,1),
    ("card.hover","cards","card",.19,520,3,-20,0),
    ("card.select","cards","card",.29,415,3,-14,1),
    ("card.enlarge","cards","glass",.44,470,3,-17,0),
    ("card.move","cards","card",.27,290,3,-18,0),
    ("card.return","cards","card",.38,245,3,-14,1),
    ("card.play","cards","resonance",.61,205,3,-10,2),
    ("card.play.creature","cards","organic",.82,165,3,-10,2),
    ("card.play.impulse","cards","reverse",.53,370,3,-12,2),
    ("card.play.relic","relics","metal",1.25,126,3,-10,3),
    ("card.discard","cards","card",.41,190,3,-14,1),
    ("card.destroy","cards","reverse",.73,150,3,-11,2),
    ("card.shuffle","cards","card",.72,285,3,-13,1),
    ("creature.summon","combat","organic",.97,155,3,-10,2),
    ("creature.attack.prepare","combat","reverse",.43,185,3,-15,1),
    ("creature.attack","combat","impact",.43,102,3,-10,2),
    ("creature.hit","combat","impact",.36,125,3,-13,2),
    ("creature.hit.strong","combat","impact",.69,70,3,-11,3),
    ("creature.defeated","combat","reverse",.95,120,3,-11,3),
    ("creature.return","combat","organic",.77,280,2,-13,2),
    ("hero.damage","combat","impact",.74,64,3,-11,3),
    ("shield.gain","combat","shield",.71,420,3,-13,2),
    ("shield.absorb","combat","shield",.49,255,3,-11,2),
    ("block.activate","combat","metal",.39,180,3,-12,2),
    ("combat.heal","combat","glass",.89,350,3,-13,2),
    ("combat.buff","combat","resonance",.71,305,2,-14,2),
    ("combat.debuff","combat","reverse",.63,210,2,-14,2),
    ("combat.path_change","combat","reverse",.73,310,2,-14,2),
    ("combat.time","combat","reverse",1.05,235,3,-12,3),
    ("combat.reaction","combat","glass",.48,440,3,-13,2),
    ("combat.interrupt","combat","shield",.46,210,3,-12,3),
    ("resonance.gain","resonance","resonance",.66,220,4,-13,2),
    ("resonance.low","resonance","resonance",.44,220,3,-17,1),
    ("resonance.medium","resonance","resonance",.81,277.18,3,-14,2),
    ("resonance.high","resonance","resonance",1.13,329.63,3,-12,3),
    ("resonance.spend","resonance","reverse",.61,165,4,-11,3),
    ("resonance.unleash","resonance","resonance",1.65,110,3,-10,4),
    ("relic.activate","relics","metal",1.13,146.83,3,-11,3),
    ("relic.passive","relics","metal",.54,293.66,3,-17,1),
    ("relic.spend","relics","reverse",.77,146.83,3,-12,3),
    ("relic.replace","relics","metal",.86,130.81,2,-13,2),
    ("relic.destroy","relics","metal",1.12,87.31,3,-12,3),
    ("convergence.prepare","combat","reverse",1.41,196,2,-12,3),
    ("convergence.complete","combat","resonance",1.92,98,2,-10,4),
    ("convergence.interrupt","combat","shield",.83,185,2,-12,3),
    ("battle.victory","combat","glass",1.62,293.66,2,-12,4),
    ("battle.defeat","combat","metal",1.54,110,2,-13,4),
]


def make_effects():
    factions = {}
    for key, family, frequency in [("zwoelf_haeuser","metal",174.61),
                                    ("stillwacht","glass",369.99),
                                    ("vielgestalt","organic",207.65),
                                    ("neunte_stunde","reverse",246.94)]:
        clip_id = "faction."+key
        write_audio(clip_id, f"assets/audio/factions/{key}.wav",
                    sfx(clip_id,family,1.13,frequency,1),"SFX",-5)
        factions[key] = clip_id
    rarities = {}
    for key, duration, frequency, family in [("rare",.61,440,"glass"),
                                            ("epic",.94,277.18,"resonance"),
                                            ("legendary",1.43,164.81,"metal")]:
        clip_id = "rarity."+key
        write_audio(clip_id,f"assets/audio/relics/rarity_{key}.wav",
                    sfx(clip_id,family,duration,frequency,1),"SFX",-8)
        rarities[key] = clip_id
    layered = {"card.play","card.play.creature","card.play.impulse","card.play.relic",
               "creature.summon","creature.attack","relic.activate","resonance.unleash"}
    rarity_events = {"card.play","card.play.creature","card.play.impulse","card.play.relic",
                     "creature.summon","relic.activate"}
    for name, directory, family, duration, frequency, count, gain, priority in SPECS:
        variants = []
        bus = "UI" if directory=="ui" or name in {"card.hover","card.enlarge","card.move"} else "SFX"
        for variant in range(count):
            clip_id = f"{name}.{variant+1:02}"
            relative = f"assets/audio/{directory}/{name.replace('.', '_')}_{variant+1:02}.wav"
            write_audio(clip_id,relative,sfx(clip_id,family,duration,frequency,variant),bus)
            variants.append(clip_id)
        EVENTS["events"][name] = {"variants":variants,"bus":bus,
            "cooldown_ms":110 if name.endswith("hover") else (65 if priority<2 else 90),
            "max_voices":1 if priority==0 else (2 if priority<3 else 3),
            "priority":priority,"gain_db":gain,"pitch_min":.985,"pitch_max":1.015}
        if name in layered:
            EVENTS["events"][name]["faction_layers"] = factions
        if name in rarity_events:
            EVENTS["events"][name]["rarity_layers"] = rarities


def midi(number):
    return 440 * 2 ** ((number-69)/12)


def periodic_frequency(frequency, duration):
    return round(frequency*duration)/duration


def music(context, duration, root, chords, motif, pulse):
    count = round(duration*RATE)
    t = np.arange(count)/RATE
    left = np.zeros(count)
    right = np.zeros(count)
    bar = duration / 8
    # Pads use circular overlap envelopes and exact-cycle oscillators. No cut
    # or fade seam interrupts the ongoing room tone at a loop boundary.
    for step in range(8):
        position = ((t - step*bar + duration/2) % duration) - duration/2
        pad_env = np.maximum(0, np.cos(np.clip(position/(bar*1.55),-1,1)*np.pi/2))**2
        chord = chords[step % len(chords)]
        for voice, interval in enumerate(chord):
            frequency = periodic_frequency(midi(root+interval),duration)
            shimmer = .19*np.sin(2*np.pi*(voice+1)*t/duration)
            slow = 1 + .17*np.sin(2*np.pi*t/duration+voice)
            left += .105/(1+voice*.25)*np.sin(2*np.pi*frequency*t+shimmer)*pad_env*slow
            right += .105/(1+voice*.25)*np.sin(2*np.pi*frequency*t-shimmer+.13*voice)*pad_env*slow
    # Restrained unique motif, an interrupted clock / memory figure.
    for index, note in enumerate(motif):
        start = (index * duration/len(motif) + (index % 3)*.083) % duration
        age = (t-start) % duration
        frequency = periodic_frequency(midi(root+24+note),duration)
        env = (1-np.exp(-age*32))*np.exp(-age*1.7)
        phase = .4*np.sin(2*np.pi*frequency*2*t)*np.exp(-age*4)
        sound = .075*np.sin(2*np.pi*frequency*t+phase)*env
        left += sound*(.83 if index%2 else 1)
        right += sound*(1 if index%2 else .83)
    # Rhythm lives below the tactical foreground, with no explosion-like hits.
    if pulse:
        spacing = bar/(4 if pulse>.6 else 2)
        age = t % spacing
        pitch = periodic_frequency(midi(root-12),duration)
        rhythm = (1-np.exp(-age*90))*np.exp(-age*12)
        clock = .055*pulse*np.sin(2*np.pi*pitch*t+.32*np.sin(2*np.pi*pitch*2*t))*rhythm
        left += clock
        right += clock
    # A deterministic spectral texture, circular by construction.
    for overtone in [11,17,29,41,67]:
        f = overtone/duration
        left += .005*np.sin(2*np.pi*f*t+.7*overtone)*np.sin(2*np.pi*(overtone+41)*t/duration)
        right += .005*np.cos(2*np.pi*f*t+.4*overtone)*np.sin(2*np.pi*(overtone+41)*t/duration)
    stereo = np.stack([left,right],axis=1)
    stereo -= np.mean(stereo,axis=0)
    stereo *= PEAK_MUSIC / max(float(np.max(np.abs(stereo))),.001)
    return stereo


MUSIC = [
    ("menu",40.,45,[(0,7,14),(0,5,10),(0,3,7),(0,2,7)],[0,7,3,2,0,10,7,2],.18),
    ("collection",40.,48,[(0,7,10),(0,5,9),(0,3,10),(0,7,14)],[7,0,10,3,7,5,2,0],0),
    ("deckbuilder",32.,43,[(0,7,14),(0,4,9),(0,5,10),(0,2,7)],[0,2,7,9,7,2,5,0],.25),
    ("duel",32.,38,[(0,7,13),(0,3,10),(0,5,12),(0,2,7)],[0,7,1,7,3,7,2,10],.55),
    ("tense",32.,37,[(0,1,7),(0,6,13),(0,3,8),(0,2,7)],[0,1,7,6,0,8,7,1,0,6,3,1],.8),
    ("convergence",32.,40,[(0,7,14),(0,6,13),(0,5,12),(0,3,10)],[0,7,14,13,7,5,12,10,7,3,2,0],.7),
    ("campaign",40.,41,[(0,7,10),(0,5,12),(0,3,9),(0,2,7)],[0,3,7,10,7,5,2,0],.12),
]


def make_music():
    for context,duration,root,chords,motif,pulse in MUSIC:
        clip_id = "music."+context
        signal = music(context,duration,root,chords,motif,pulse)
        write_audio(clip_id,f"assets/audio/music/{context}.ogg",signal,"Music",-9,True)
        CATALOG["music"][context] = clip_id
    for context, notes, duration in [("victory",[50,57,62,65,69],7.),("defeat",[45,52,48,46,40],7.5)]:
        t = np.arange(round(duration*RATE))/RATE
        signal = np.zeros(len(t))
        for step,note in enumerate(notes):
            age = np.maximum(0,t-step*.24)
            active = t >= step*.24
            f = midi(note)
            signal += .2*tone(age,f,.8,.17)*active*(1-np.exp(-age*25))
            signal += .04*tone(age,f*2.01,1.7)*active*(1-np.exp(-age*25))
        signal *= envelope(t,duration,.025,2.1)
        echo(signal,.273,.22)
        signal *= envelope(t,duration,.025,1.3)
        signal *= PEAK_MUSIC/max(float(np.max(np.abs(signal))),.001)
        stereo = np.stack([signal,np.roll(signal,round(.011*RATE))*.94],axis=1)
        stereo *= envelope(t,duration,.03,.5)[:,None]
        clip_id = "music."+context
        write_audio(clip_id,f"assets/audio/music/{context}.ogg",stereo,"Music",-7,False)
        CATALOG["music"][context] = clip_id
    # Neutral atmosphere: no faction motif and no permanent resonance cue.
    signal = music("ambience",40.,29,[(0,7),(0,7),(0,7),(0,7)],[],0)
    signal *= .7
    write_audio("ambience.rift","assets/audio/ambience/rift.ogg",signal,"Ambience",-20,True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--effects-only",action="store_true")
    args=parser.parse_args()
    make_effects()
    if not args.effects_only:
        make_music()
    (ROOT/"data/audio/audio_catalog.json").write_text(json.dumps(CATALOG,indent=2)+"\n",encoding="utf-8")
    (ROOT/"data/audio/audio_events.json").write_text(json.dumps(EVENTS,indent=2)+"\n",encoding="utf-8")
    (ROOT/"data/audio/asset_manifest.json").write_text(json.dumps({"version":1,"generator":
        "scripts/audio/generate_audio.py","generated_date":"2026-11-10","assets":FACTS},indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"clips":len(FACTS),"events":len(EVENTS["events"]),"music":len(CATALOG["music"]),
                      "bytes":sum(x["bytes"] for x in FACTS)},indent=2))


if __name__ == "__main__":
    main()
