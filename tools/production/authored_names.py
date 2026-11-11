"""Editorial production inventory. Names and species are authored, not word permutations.

Each row represents a separate card brief. Species order conveys no hierarchy.
These are small setting proposals, not new world history or canonical leaders.
"""

CREATURES = {
    "houses": """
Kupferhüterin|human
Schreinpfleger|human
Rostflügel|beast,construct
Verbliebene Stimme|spirit
Narbenkartografin|human
Gedächtniskerze|elemental
Briefträger ohne Gestern|revenant,human
Schwellenhund|beast
Fadenrest|spirit
Tonbewahrerin|construct
Nachtbuchhändler|human
Kellerchronistin|human
Aschehirsch|beast,elemental
Stummer Mitschreiber|mechanoid
Erinnerungsfresser|devourer
Rückwärtsgänger|paradox
Wachsmund|amalgam,construct
Trauerweide|plant
Wiedergefundene|revenant
Kupferspinne|mechanoid,beast
Siegelwächter|construct
Schriftenträgerin|human
Gespräch im Glas|spirit,paradox
Sargblütenhüter|plant,revenant
Leihgedächtnis|amalgam
Salzbriefleserin|human
Falscher Vorfahr|paradox
Knochenrestaurator|human
Krähensammlerin|human
Mauererinnerung|construct,spirit
Wiederkehrender Gast|revenant,human
Heimkehrschwarm|beast
Schlafender Zeuge|spirit
Nachlasshändler|human
Porzellanwitwe|construct
Echozählerin|human
Staubschreiber|elemental
Schlüsselsucher|human
Ewiger Untermieter|revenant
Kupfergeflecht|plant,construct
Fremde Kindheit|paradox,spirit
Vernähte Erinnerung|amalgam
Fehlende Schwester|revenant
Grablichthüter|elemental,construct
Namenrabe|beast
Totenpostmeisterin|human
Vergessenszehrer|devourer
Schriftkrabbe|mechanoid
Wurzel der Namen|plant
Gestohlene Stunde|paradox
Stimmenhort|amalgam,spirit
Letzter Chronometer|mechanoid
Geborgene Gestalt|morphid
Alter Widerspruch|paradox
Unbezahlte Schuld|revenant,devourer
Kupferner Beichtstuhl|construct
Zweiter Abschied|spirit
Hüter der Restwärme|human
Die offene Tür|paradox
Hundert Namen|amalgam
Unvollendete Heimkehr|revenant,spirit
Kupferne Wiederkehr|construct,revenant
Die Unvergessene|human
Schrift aus Atem|elemental,spirit
Haus ohne Schatten|construct,paradox
Nachlass der Stille|devourer,spirit
""",
    "stillwatch": """
Eislichtwache|human
Kristallmarder|beast
Schneeglaspflegerin|human
Schwellenautomat|mechanoid
Reifhülle|elemental
Passärztin|human
Stasisfalter|beast,paradox
Mauerpflanze|plant
Unbewegter Bote|construct
Leuchtfeuervogel|beast,elemental
Stillgelegte Wache|revenant,human
Schutzplattenkäfer|beast
Rissprüferin|human
Kältesammler|devourer
Taktpfleger|mechanoid
Schneewurzel|plant,elemental
Stiller Doppelgänger|paradox
Prismenbär|beast,construct
Glasverbund|amalgam
Eidträgerin|human
Grenzbewahrer|human
Verbliebener Posten|revenant
Kreiselwächter|mechanoid
Eisadern|plant
Schutzgeist|spirit
Panzerhüter|construct
Schwellenretterin|human
Frostschleier|elemental,spirit
Ruhezehrer|devourer
Kristallpfropf|amalgam,plant
Schichtablösung|human
Bleierner Läufer|mechanoid
Gesprungener Eid|paradox,construct
Stille Raupe|beast,morphid
Versiegelte Stimme|spirit
Bastionsweide|plant
Eissturmhüter|elemental
Verzögerungswache|human
Schwerer Schritt|construct
Felsgesicht|elemental,construct
Spiegelpanzer|mechanoid
Retterin ohne Puls|revenant,human
Gepanzerter Keim|plant,construct
Stille Versammlung|amalgam,spirit
Aufgehaltener Riss|paradox
Wachender Frost|elemental
Winterplattenhüter|mechanoid
Bewahrte Silhouette|spirit
Gläserner Grenzstein|construct
Schildzehrer|devourer
Schutzhautwechsler|morphid
Unverrückbarer Gast|revenant
Der letzte Posten|human
Eis ohne Tauwetter|elemental,paradox
Wand aus Erinnerung|construct,spirit
Bewahrte Minute|paradox
Die stille Ablösung|revenant,human
Kristallkathedrale|construct
Wacht ohne Ende|mechanoid
Schlafender Gletscher|elemental
Ungebrochener Kreis|amalgam,construct
""",
    "morph": """
Jadekundschafterin|human
Wurzelflieger|plant,beast
Zweithautechse|beast,morphid
Sporenpfleger|human
Knospenläufer|plant
Glasflügelnymphe|morphid
Dornenmaul|plant,devourer
Pfropfchirurgin|human
Farnklauen|plant,beast
Wandelkrabbe|morphid,beast
Lebender Pfad|plant
Hautschriftleser|human
Furchenwurm|beast
Zwillingshülle|amalgam
Bernsteinfeder|beast
Keim im Metall|plant,mechanoid
Gedankenmoos|plant,spirit
Faltenschleicher|morphid
Häutungssammlerin|human
Hungriger Garten|plant,devourer
Kreuzungsbote|amalgam
Regenform|elemental,morphid
Wanderspross|plant
Sechster Finger|amalgam,human
Pilzhorcher|plant
Rankenbrecher|beast
Ersatzkörper|construct,morphid
Stachelspäherin|human
Rindenwechsler|morphid,plant
Sporenlicht|elemental,plant
Gelenkfalter|mechanoid,beast
Wuchernder Schatten|spirit,plant
Fremdschlag|amalgam
Rückwurzler|plant,revenant
Jadefresser|devourer
Laufendes Nest|beast,plant
Schwellenkriecher|morphid
Wurzelknüpferin|human
Fließender Panzer|morphid,construct
Blütenraubtier|plant,beast
Häutungsgelehrter|human
Spiegelblatt|plant,paradox
Sporenmechanoid|mechanoid,plant
Mutationshüterin|human
Geteilter Leib|amalgam
Wandernde Kolonie|plant
Pfadverschlinger|devourer
Nadelwild|beast,plant
Instabiles Geweih|morphid,beast
Zukünftiger Körper|paradox,morphid
Ersatzherzträger|human,mechanoid
Staubkeim|plant,elemental
Haut ohne Träger|revenant,morphid
Knospenwächter|construct,plant
Tausend Gelenke|amalgam,mechanoid
Wandelnder Wall|plant
Sichere Unform|morphid
Morgenfresser|devourer,paradox
Blühender Bruch|elemental,plant
Geteilte Jägerin|human,amalgam
Jadekollektiv|amalgam
Wurzel aller Wege|plant
Unmögliche Häutung|morphid,paradox
Der wandelnde Garten|plant,construct
Morgen ohne Form|paradox
Die zweite Haut|morphid
Herz des Schwarms|amalgam,beast
Unvollendeter Körper|construct,morphid
Hungernder Frühling|plant,devourer
Alle Richtungen|paradox,morphid
Ferne Knospe|plant,spirit
""",
    "ninth": """
Zeigerläuferin|human
Sekundenfuchs|beast,paradox
Taktmechaniker|mechanoid
Faltenschreiberin|human
Vorauseilender Schatten|spirit
Stundenglasfresser|devourer
Rücklicht|elemental
Zählwerkhüter|construct
Gegentakt|paradox
Verpasster Bote|human
Uhrenspinne|mechanoid,beast
Prognosenleserin|human
Zeitnarbenwild|beast
Nachhall der Stunde|spirit
Kreisgänger|paradox
Verspätete Wache|revenant,human
Minutenweide|plant
Prismenpendel|construct
Taktfalter|beast
Kausalitätsjägerin|human
Unzeitiger Gast|paradox
Sekundenkollektor|mechanoid
Verlorener Vorläufer|revenant
Taktloser Zehrer|devourer
Gleichzeitiger Körper|amalgam,paradox
Fadenuhrhüterin|human
Sternstaubzähler|elemental
Rückwärtiger Zeuge|spirit
Verzögerungskern|construct
Wiederholter Schritt|paradox
Späte Reisende|human
Unsichtbarer Termin|spirit
Kreisförmiger Hunger|devourer,paradox
Zeigerwald|plant,mechanoid
Faltentänzer|morphid
Möglichkeitssammler|human
Zersprungene Sekunde|elemental,paradox
Zukunftsruine|construct
Ungelöster Takt|paradox
Geteilte Prognose|amalgam
Neunfacher Läufer|mechanoid
Ungelebte Stimme|spirit
Der späte Gast|revenant
Kausalschneiderin|human
Fehlender Augenblick|paradox
Pendelfresser|devourer
Gleiche Nacht|spirit,paradox
Uhrwerk ohne Zeiger|mechanoid
Das offene Morgen|paradox
Zeugin der Lücke|human
Die achte Sekunde|elemental,paradox
Ankunft ohne Abreise|revenant,paradox
Ende vor dem Anfang|amalgam,paradox
Der leere Kalender|construct
Ungeschehener Hunger|devourer
""",
    "neutral": """
Wegmarkiererin|human
Lastenläufer|mechanoid
Staubmarder|beast
Regenfänger|construct
Feldscher|human
Windglasspatz|beast,elemental
Schwellenhändlerin|human
Wurzelschlepper|plant
Karrenwächter|construct
Falte im Mantel|paradox
Lichtsammler|devourer
Nachtfähre|mechanoid
Brückenpflegerin|human
Verlorener Hund|beast
Rostgeweih|beast,mechanoid
Nebelträger|elemental
Fremdenführerin|human
Flüsterpflanze|plant,spirit
Tonläufer|construct
Salzsänger|human
Taschenfresser|devourer
Rückkehrender Pilger|revenant
Zwillingskarre|amalgam,mechanoid
Wegloser Geist|spirit
Lampenfalter|beast
Reparaturhüter|human
Kieswurzel|plant
Vertragszeugin|human
Wandernde Hülle|morphid
Grenzschwein|beast
Sammlerin der Reste|human
Messingkäfer|mechanoid,beast
Wasserglasläufer|elemental
Lehmgedächtnis|construct
Fremde Silhouette|spirit
Pfadfresser|devourer
Schlafwanderin|human
Geteiltes Gepäck|amalgam
Namenloser Reisender|human
Abendweide|plant
Schwarzer Packhirsch|beast
Zwischenraumvogel|paradox,beast
Fließendes Werkzeug|morphid,construct
Fährgeist|spirit
Schutzsuchende|human
Überwucherter Wächter|construct,plant
Langlebiger Automat|mechanoid
Leihkörper|amalgam
Wanderfeuer|elemental
Abgetragener Pfad|revenant
Moosherz|plant
Der letzte Händler|human
Unruhiger Grenzstein|construct
Hungriger Kompass|devourer
Stimmenwagen|mechanoid,spirit
Der ungebetene Gast|paradox
Koffer voller Regen|elemental,construct
Verspäteter Retter|human
Gemeinsamer Atem|amalgam,spirit
Stein des Weges|construct
Weltlose Wanderin|human
Brücke ohne Ufer|paradox,construct
Die letzte Fähre|mechanoid
Verlorener Riese|revenant
Wurzel im Nichts|plant,paradox
Fremdes Morgen|spirit
Weg ohne Ende|paradox
""",
}

EVENTS = {
    "houses": """
Geborgener Name
Zurück ins Licht
Kupfernes Versprechen
Abschrift
Erneuter Abschied
Offene Nachfolge
Restwärme
Wiedergefundenes Wort
Stimme aus Staub
Sichere Verwahrung
Geerbte Last
Versiegelte Erinnerung
Vergessene Schuld
Nachgetragener Sieg
Unbeantworteter Brief
Rückruf
Zweite Niederschrift
Bewahrter Atem
Totenwache
Gemeinsamer Nachlass
Ausgeliehene Vergangenheit
Gebrochener Eintrag
Letzte Zeugenaussage
""",
    "stillwatch": """
Geschlossene Formation
Kristallschirm
Halt in der Kälte
Stillgestellter Schmerz
Sicherer Abstand
Ruhiger Puls
Geteilte Deckung
Unbewegter Augenblick
Schützende Hand
Eingefrorener Schritt
Prismensplitter
Bewahrte Grenze
Kälteriss
Aufgefangener Schlag
Feste Position
Stiller Austausch
Eiserne Pause
Gesicherter Rückzug
Schützendes Schweigen
Kreis aus Eis
Letzte Deckung
Unnachgiebiger Halt
Zeit unter Glas
Rettung im Frost
Verriegelte Gegenwart
Keine weitere Sekunde
""",
    "morph": """
Offene Schneise
Neue Gelenke
Jadehäutung
Wurzelsprung
Sporenstoß
Fremdes Wachstum
Richtungswechsel
Geteilte Rinde
Instinktive Antwort
Verbundene Wurzeln
Reißende Blüte
Zweite Lunge
Überwucherung
Wandelnde Deckung
Fremder Instinkt
Knospenregen
Gemeinsame Häutung
Abgelegter Körper
Ungehemmter Frühling
Morgen keimt
""",
    "ninth": """
Vorgemerkter Einschlag
Sekundenbruch
Frühe Warnung
Rückwärtiger Impuls
Gezählte Schritte
Aufgeschobener Blitz
Leere Prognose
Gegenseitige Verzögerung
Ursache gesucht
Nächster Augenblick
Zu spät gesehen
Unterbrochener Takt
Offene Möglichkeit
Kausaler Schnitt
Wiederholte Warnung
Ausstehende Rechnung
Nachlauf
Abgezählte Stille
Ungleicher Rhythmus
Vorbereiteter Rückschlag
Neuer Verlauf
Vertagte Wunde
Sekundenhandel
Andere Reihenfolge
Ungeplantes Ende
Verschobener Horizont
Zukunftsschuld
Vorausgehender Schatten
Verweigerter Termin
Faltung des Moments
Ein Augenblick mehr
Der neunte Schlag
""",
    "neutral": """
Kurze Rast
Freier Weg
Notverband
Aufgeräumtes Lager
Prismensignal
Fester Stand
Gute Gelegenheit
Schutz vor dem Regen
Tausch am Weg
Schweres Gepäck
Licht über der Brücke
Unerwartete Hilfe
Letzter Proviant
Offene Hand
Heller Widerhall
Gemeinsame Deckung
Unterschlupf
Wegkreuzung
Gesammelte Kraft
Weitergehen
""",
}

RELICS = {
    "houses": """
Kupfernes Namensband
Unbeschriebenes Testament
Gedächtnisspule
Schlüssel des Nachlasses
Restaurationslampe
Siegel der Wiederkehr
Schrein der Restwärme
Leiharchiv
Wappen ohne Träger
Unvollständiges Register
Die offene Chronik
""",
    "stillwatch": """
Kristallanker
Prismenwächter
Stasislampe
Eisernes Stundenglas
Frostspange
Versiegelte Waage
Rettungsglocke
Grenzmarke
Stillstandskern
Ungebrochene Scheibe
Schutzplattenwerk
Der unbewegte Zeiger
Unzerbrechlicher Eid
""",
    "morph": """
Jadeknoten
Wanderwurzel
Samen der Anpassung
Häutungsklinge
Geteiltes Herz
Sporenlinse
Lebender Kompass
Der fremde Keim
Wurzel ohne Boden
""",
    "ninth": """
Sekundenfänger
Gegentaktpendel
Linse des Nachlaufs
Offener Zeitmesser
Kausalnadel
Prognoseprisma
Faltkalender
Verzögerungsspule
Zeiger ohne Kreis
Möglichkeitswaage
Das zweite Zählwerk
Uhr der offenen Frage
Die letzte Sekunde
""",
    "neutral": """
Weglampe
Reparaturkasten
Schwellenkarte
Notvorrat
Prismenkarussell
Messingkompass
Leihschutz
Der letzte Schlüssel
""",
}


def rows(block):
    return [line.strip() for line in block.strip().splitlines() if line.strip()]


if __name__ == "__main__":
    for power in CREATURES:
        print(power, len(rows(CREATURES[power])), len(rows(EVENTS[power])), len(rows(RELICS[power])))
