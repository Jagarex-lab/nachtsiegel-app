# ORAFOLD · Abschlussbericht Audiopaket

> Produktaktivierung und aktueller Integrationsumfang: [PRODUCTION-INTEGRATION.md](PRODUCTION-INTEGRATION.md). Dieser Liefertext dokumentiert den ursprünglichen isolierten Paketstand.

PR: https://github.com/Jagarex-lab/nachtsiegel-app/pull/14
Branch: `feature/orafold-audio`, Basis `develop` / `17121e4`.
Der aktuelle Liefercommit ist der Head dieses PRs. Kein Merge, Auto-Merge,
Deployment oder Release wurde ausgeführt.

## Status

| Kategorie | Gelieferter Stand |
| --- | --- |
| Fertig implementiert | Modularer Manager, 52 datengetriebene Ereignisse, Router, eigene Busse/Limiter, Pool mit 16 Effektstimmen, Varianten, Layer, Crossfades, Ambience, persistente Einstellungen, Webfreigabe/Pausierung, optionale Settings-UI/Klangstudio |
| Mit echten Assets ausgestattet | 153 SFX-WAVs, neun Musik-Vorbisdateien, ein Ambience-Loop; keine Textplatzhalter |
| Automatisiert getestet | 389 Audio-, 28 Vorschau-, 3.117 Assetprüfungen; bestehende 1.704 Regel-/173 Replay-Assertions, 43 Node-/8 Release-Schutztests; Linuxexport 7 Prüfungen; Desktop/Android-Emulation je 10 Browserprüfgruppen |
| Manuell geprüft | Quellcode, Architektur-/Integrationsvertrag, Scope und Prüfprotokolle; Screenshot des exportierten QA-Projekts visuell geprüft |
| Noch nicht integriert | Produktiver Autoload, zentrale Settings-UI, bestätigte Spiel-/UI-Ereignisse, Szenenmusik, Exportfilter, ausdrückliche Übernahme vorhandener Profilwerte |
| Blockiert/offen | Lokales WebKit wegen sechs fehlender Bibliotheken; finale CI separat prüfen; menschliche Hör-/Mastering-Abnahme und physische Zielgeräte-/Unterbrechungs-/Latenztests offen |

## Systeme und Assets

Der Manager löst ausschließlich Präsentationsfeedback aus. Er importiert
keine Regelmodelle, verändert keine Kartenwerte und verwendet einen eigenen
Zufallsgenerator. Fehler/fehlende Audios liefern einen Audiostatus, keinen
Spielbefehl. Maximal 16 Effektplayer einschließlich Layer, zwei Musikplayer
und ein Ambienceplayer; keine Player-Erzeugung pro Ereignis. Alle Player
nutzen explizite Streamwiedergabe, auch im Web.

Die 153 SFX bestehen aus 146 Ereignisvarianten, vier Machtakzenten und drei
Seltenheitsakzenten. Karten ziehen/auswählen/vergrößern/bewegen/zurücklegen/
ausspielen/abwerfen/zerstören/mischen, verschiedene Kartentypen, Kampf,
Schutz/Block/Heilung, Resonanz und Relikte besitzen echte Cues. Seltenheit
ergänzt Klangschichten, ohne einen wesentlich höheren Lautstärkezielwert
vorzugeben. Individuelle Signaturen konkreter legendärer Relikte sind noch
nicht an Kartendaten gebunden.

| Macht | Gelieferte Klangsprache |
| --- | --- |
| Zwölf Häuser | Warmes Metall, tiefe Körper, Glockennachhall und verzögertes Echo |
| Stillwacht | Glasmoden, kalter präziser Ansatz, kontrolliertes Ausklingen |
| Vielgestalt | Organische FM-Bewegung, unregelmäßige Modulation, bewegliche Schichten |
| Neunte Stunde | Rückwärtskontur, verschobene Wiederholung, schwebende Resonanz |
| Neutral | Zurückhaltender Grundcue ohne zusätzliche Fraktionsschicht |

Neun Musikdateien decken Menü, Sammlung, Deckbuilder, Duell, Spannung,
Konvergenz, Kampagnengrundlage, Sieg und Niederlage ab. Sieben 32-/40-Sekunden-
Loops und zwei 7-/7,5-Sekunden-Stinger ergeben 262,5 Sekunden Musik.
Hinzu kommt ein 40-Sekunden-Ambience-Loop. Crossfades reagieren ausschließlich
auf vorgegebene Kontexte; es gibt keine neue Bedrohungs-/Konvergenzlogik.
Resonanzstufen sind explizite Eingaben ohne erfundene Gameplay-Schwellen.

## Nachweise, Performance und Rechte

[AUDIO-QA.md](AUDIO-QA.md) enthält Befehle, Rohprotokolle, Messwerte und
Grenzen. Der finale Hosttest verarbeitete 10.000 Dispatchversuche in
64,14 ms bei maximal 16 Effektstimmen. Desktop und 4× gedrosselte
Pixel-7-Emulation lieferten einen echten nicht-null Audioausgang; Master-Mute
ergab exakt null RMS. Sofortiger Reload, verweigerter Speicher und zukünftige
Speicherversionen wurden geprüft. Das ist keine physische Android-/Safari-
oder Ausgabelatenzabnahme.

Alle 163 Dateien zusammen: 7.914.598 Bytes. Nur eigene lokale Synthese aus
Oszillatoren, Filtern, Hüllkurven, deterministischem Rauschen und eigenen
Notenfolgen. Keine externen Samples, Musikdownloads oder nachgeahmten Werke.
[AUDIO-LICENSES.md](AUDIO-LICENSES.md) und
`data/audio/asset_manifest.json` dokumentieren Verfahren, Rechte, Datum,
Messwerte und Hashes pro Datei. Original-Assetrechte folgen dem bestehenden
`LICENSE-NOTICE.md`; es wird keine neue öffentliche Lizenz behauptet.

## Integration und verbleibende Grenzen

[AUDIO-INTEGRATION.md](AUDIO-INTEGRATION.md) beschreibt den kleinen separaten
Folgeschritt: einen Audioeigentümer wählen, Doppelmusik mit `GameAudio`
vermeiden, `data/audio/*.json` exportieren, bestätigte Präsentationsereignisse
weiterreichen, Spielpause explizit suspendieren und die Settings-UI einhängen.
Die Produktintegration darf Audio-Rückgaben niemals zur Spielvalidierung
verwenden. Fehlende Semantiken bleiben unverbunden.

Sämtliche bisherigen Dateien unter den produktiven Audio-/Spielpfaden bleiben
unverändert. Neben neuen Audio-/Dokumentations-/Testdateien wurde lediglich
ein eigener CI-Workflow `audio-qa.yml` hinzugefügt; bestehende Workflows wurden
nicht geändert. Er besitzt nur Leserechte und keinen Veröffentlichungsschritt.

Es gab keine menschliche Hörabnahme. Die vier Machtakzente und drei
Seltenheitsschichten sind zunächst je ein wiederverwendbarer Akzent, keine
vollständige individuelle Klangbibliothek für jede Karte. Musik besteht aus
komponierten kurzen Loops, nicht aus einem langen orchestralen Soundtrack oder
beatsynchronen adaptiven Stems. Physische mobile Geräte, Telefonate,
Bluetooth-/Headsetwechsel, lange Spielsitzungen und finale Mixabnahme müssen
vor der Produktfreigabe noch geprüft werden. Diese Punkte werden nicht als
fertig gemeldet.
