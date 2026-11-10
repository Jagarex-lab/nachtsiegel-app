@tool
extends EditorPlugin
const EXPORTER = preload("res://addons/orafold_art_delivery/exporter.gd")
var _exporter: EditorExportPlugin
func _enter_tree() -> void:
	_exporter = EXPORTER.new(); add_export_plugin(_exporter)
func _exit_tree() -> void:
	if _exporter != null: remove_export_plugin(_exporter)
	_exporter = null
