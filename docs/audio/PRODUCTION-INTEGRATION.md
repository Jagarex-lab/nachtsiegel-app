# ORAFOLD – Audio in der Produktoberfläche

Die Alpha-Shell und die Archivoberfläche verwenden einen gemeinsamen Audioeigentümer: den bestehenden Autoload `GameAudio`. Er erbt die Runtime aus `scripts/audio/audio_manager.gd`; die frühere zweite Wiedergabepipeline mit elf Cues und eigener Hintergrundmusik wird nicht mehr gestartet. Das Projekt erhält keinen zusätzlichen Autoload.

## Eigentümer und Grenzen

Der Mixer besitzt höchstens 16 Effektstimmen einschließlich Macht-/Seltenheitsschichten, zwei Musikplayer für Übergänge und einen Umgebungsplayer. Das sind 18 direkte Kindknoten und 19 AudioStreamPlayer insgesamt. Effekte verwenden im Web ausdrücklich den Engine-Mixer, sodass Buslautstärken, Mute und Limiter auch die tatsächliche Ausgabe beeinflussen. Überzählige Effekte werden verworfen, niemals als spätere Spielaktionen nachgeholt.

Die Archivaufrufe `apply`, `cue`, `preview`, `volumes`, `voices`, `history` und `request_quit` bleiben verfügbar. Sie delegieren an denselben Mixer. Archivmenüs und Sammlung wählen passende vorhandene Musik; ein tatsächlich gestartetes Archivduell wählt Duellmusik. Die alten ASH/TIDE/THORN/VEIL-Cuenamen erhalten einen neutralen Reaktionsklang, keine nachträglich erfundene Zuordnung zu den vier ORAFOLD-Mächten.

Die separate Hörvorschau stoppt den Produkteigentümer ausdrücklich, bevor sie ihre eigene Vorschauinstanz startet. Diese isolierte Vorschau ist kein zweiter aktiver Produktmixer.

## Einstellungen und Speicherung

In den Alpha-Einstellungen führt „Ton und Lautstärke“ zu einem echten Scrollbereich mit getrennten Reglern für Gesamt, Musik, Effekte, Bedienung und Umgebung. Regler und Schalter haben mindestens 44 CSS-/logische Pixel Höhe. Mute wirkt auf den gemeinsamen Rootbus; reduzierte Intensität reduziert Pegel und zusätzliche Seltenheitsschichten. Speicherung und Spielfortschritt bleiben getrennt.

Die Runtime speichert in `user://orafold_audio_v1.cfg`; im Web sichert zusätzlich ein eigener synchroner `orafold.audio.v1:`-Mirror sofortige Reloads ab. Der neue optionale `ui`-Wert übernimmt beim Lesen früherer vollständiger Version-1-Audiodaten deren damaligen `sfx`-Wert. Die übrigen Pflichtfelder bleiben streng validiert. Unbekannte native Versionsstände sowie ungültige/future Web-Mirrors blockieren Schreibversuche auf diese Daten. Aktive Regleränderung und erfolgreiche Speicherung sind getrennte Ergebnisse; ein Fehler wird im Einstellpanel angezeigt.

Nur wenn noch keine neuen Audioeinstellungen vorliegen, werden vollständig typisierte Music-/SFX-/UI-Gains aus dem bekannten archivierten `progress_v1.json` beziehungsweise dessen bekanntem Web-Mirror gelesen. Archivdateien und unbekannte Profilversionen werden dabei nicht geschrieben oder migriert. Die neue Runtime importiert keinen Fortschritts-/Kampagnenstore.

## Bestätigte Präsentationsereignisse

`scripts/audio/presentation_audio.gd` liest ausschließlich bereits bestätigte, geordnete Modellereignisse nach erfolgreicher `Session.command`-Rückgabe. Das Modell erhält keine Audioabhängigkeit und Audioantworten werden niemals zur Spielvalidierung benutzt.

Jede Ereignis-Sequenznummer wird pro Partie einmal konsumiert. LP-, Schildzuwachs-, Blockzuwachs-, Resonanz- und Einheitenänderungen werden zwischen direkt benachbarten geschlossenen Snapshots verglichen. Dadurch wird eine bereits im inneren Reaktionslog sichtbare Änderung im späteren umschließenden Angriffslog nicht erneut vertont. Diese Deduplizierung ist unabhängig von Klang-Cooldowns.

Direkte Zuordnungen bestehen für bestätigte Beschwörung, Angriff, Tod, Rückkehr, Verschiebung, Impuls/Relikt, Ablage, Kreislauf, Entfesselung und Konvergenz. UI-Hover, Auswahl und Kartenvergrößerung entstehen an den tatsächlichen Präsentationsaktionen. Explizite Kartenmetadaten liefern vorhandene Macht und Seltenheit. Ein Angriff ohne belegte Quellkartenkennung erhält den neutralen Grundklang: Nach Reaktionen kann auf demselben Pfad schon ein anderes Wesen stehen. Eine explizit protokollierte Entfesselungsmacht bleibt nutzbar. Keine Karte wird geändert oder umklassifiziert.

Ein belegter Handzuwachs zusammen mit verbrauchten Deckkarten erzeugt einen Nachziehklang; Rückholen wird separat behandelt. Schäden erhalten keine frei erfundene Schwelle für „stark“. Schild-/Blockverlust allein kann Ablauf statt Absorption bedeuten und erhält deshalb keinen geratenen Absorptionsklang. Nicht belegte Resonanzstufen, Bedrohungsschwellen und andere fehlende Semantiken bleiben unverbunden.

## Musik und Lebenszyklus

Die Shell wählt vorhandene Menü-, Sammlungs-, Deckbau-, Duell-, bestätigte Konvergenz- und Ergebniskontexte. Sie erfindet keine LP-/Schadensschwelle für Spannungsmusik. Die erste echte Webinteraktion entsperrt Audio. Der tatsächliche Partieverlassen-Dialog suspendiert den Mixer; Rückkehr setzt erlaubte Musik fort. Anwendungsfokus und Betriebssystempause bleiben zusätzliche, voneinander getrennte Suspensionsgründe. Aktive Musik-/Umgebungsstreams bewahren ihre Wiedergabeposition; der Web-Transport wird beim Fortsetzen dort neu gestartet. Damit hängt die Wiederaufnahme nicht von einem beim Pausieren erhalten gebliebenen Backendzustand ab. Wiederholte Pausegründe überschreiben den erfassten Transport nicht. Der öffentliche `set_audio_paused`-Hook betrifft Präsentation und Audio, keine Spielregel.

## Auslieferung und Prüfung

Alle Exportpresets enthalten `data/audio/*.json` sowie die paketierte Kopie `assets/audio/ORAFOLD-LICENSES.md`. Die 163 Originaldateien, ursprünglichen Importparameter, Hashes und Verfahrensnachweise bleiben erhalten. Die Dokumente `AUDIO-DELIVERY.md` und `AUDIO-INTEGRATION.md` beschreiben den vorherigen isolierten Lieferstand; diese Datei beschreibt dessen tatsächliche Produktaktivierung.

Die Audio-Suite umfasst Runtime, Vorschau, Produktintegration und die vollständige Assetprüfung. `tests/audio/product_browser.mjs` bedient die tatsächlichen Canvas-Steuerelemente des exportierten Produkts und misst den WebAudio-Ausgang, einschließlich unabhängiger UI-/Effektpegel, Mute, Pause, Reload und Speicherfehlern. `tests/audio/exported.gd` prüft das erzeugte native Paket aus einem leeren Arbeitsverzeichnis. Ergebnisse und jeweilige Buildidentität werden separat protokolliert; ein Editorimport allein ist kein Exportnachweis.

Die Archiv-Kampfprüfung behält ihre Funktions-/Mute-/Persistenz-/Burstchecks und prüft das begründete neue Knotenbudget. Der 550-Karten-UI-Test bezieht seine Ausgangskarte aus dem aktiven Produktionskatalog und beendet die Audioausgabe über `GameAudio.request_quit`; alle 5012 Funktionsassertionen bleiben bestehen. Der alte zusätzliche Base-/Subclass-Preload führte sonst beim Prozessende zu Script-/Font-Ressourcenlecks.

Browser-/Dummy-Hostprüfungen sind weder physische Geräteprüfungen noch menschliche Hörabnahmen. Es werden keine Aussagen zu Telefonunterbrechung, Bluetooth, Lautsprecherlatenz oder einem final gehörten Mix behauptet. Es gibt keine Economy-, Online- oder Kampagnenerweiterung und keinen automatischen Merge oder Release.
