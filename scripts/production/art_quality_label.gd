extends Label
## Actual source/preview quality. This is not a card rule or approval control.
const ART = preload("res://scripts/production/art_resolver.gd")
var card: Dictionary = {}
var _elapsed := 0.0
func _ready() -> void:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 16)
	refresh()
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.15: _elapsed = 0; refresh()
func refresh() -> void:
	var actual := ART.resolve(card, "full", self)
	if actual.get("preview_pending", false):
		text = "Bild wird geladen …" if actual.delivery_state == "loading" else "Bild derzeit nicht erreichbar."
	elif actual.get("preview_only", false):
		text = "Bild: Vorschau · Original wird geladen …" if actual.delivery_state == "loading" else "Bild: Vorschau bleibt verfügbar · Original derzeit nicht erreichbar." if actual.delivery_state == "failed" else "Bild: Vorschau · hochauflösendes Original derzeit nicht geladen."
	elif actual.individual:
		text = "Bild: Individuelles Original · %d × %d Pixel" % [actual.texture.get_width(), actual.texture.get_height()]
		if actual.status != "final": text += " · Konzept, Produktionsprüfung offen"
	else: text = "Bild: Geteiltes Konzeptmotiv · individuelle Illustration fehlt."
func _exit_tree() -> void: ART.release_owner(self)
