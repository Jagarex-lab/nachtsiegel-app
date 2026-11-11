extends SceneTree
## Read-only comparison of actual prepared art; no originals/derivatives overwritten.
const IDS := ["of-houses-020","of-houses-094","of-stillwatch-043","of-stillwatch-055","of-morph-003","of-morph-082","of-ninth-019","of-ninth-095","of-neutral-049","of-neutral-083"]
var assertions := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> bool:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ",label)
	return ok
func sha(bytes: PackedByteArray) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes); return h.finish().hex_encode()
func run() -> void:
	var rows: Array=[]
	var quality90_total := 0
	var lossless_total := 0
	for id in IDS:
		var original := FileAccess.get_file_as_bytes("res://assets/cards/previews/"+id+".png")
		var image := Image.new()
		if not check(image.load_png_from_buffer(original)==OK,"actual prepared PNG decodes: "+id): continue
		var lossy := image.save_webp_to_buffer(true,0.9)
		var lossless := image.save_webp_to_buffer(false)
		var lossy_image := Image.new(); var lossless_image := Image.new()
		if not check(lossy_image.load_webp_from_buffer(lossy)==OK and lossless_image.load_webp_from_buffer(lossless)==OK,"both actual codec bodies decode: "+id): continue
		image.convert(Image.FORMAT_RGBA8); lossy_image.convert(Image.FORMAT_RGBA8); lossless_image.convert(Image.FORMAT_RGBA8)
		check(image.get_data()==lossless_image.get_data(),"actual lossless codec preserves every prepared RGBA byte: "+id)
		check(image.get_size()==lossy_image.get_size() and image.get_size()==lossless_image.get_size(),"actual codec dimensions unchanged: "+id)
		var metrics: Dictionary=image.compute_image_metrics(lossy_image,false)
		quality90_total+=lossy.size(); lossless_total+=lossless.size()
		rows.append({"card_id":id,"prepared_png_sha256":sha(original),"width":image.get_width(),"height":image.get_height(),"quality90_bytes":lossy.size(),"quality90_sha256":sha(lossy),"quality90_metrics_rgba":metrics,"lossless_bytes":lossless.size(),"lossless_sha256":sha(lossless),"lossless_pixels_equal":image.get_data()==lossless_image.get_data()})
	var result:={"sample_actual_previews":rows.size(),"quality90_encoded_bytes":quality90_total,"lossless_encoded_bytes":lossless_total,"lossless_to_quality90_ratio":float(lossless_total)/maxi(1,quality90_total),"assertions":assertions,"failures":failures,"rows":rows,"scope":"Actual same ten512px prepared illustrations; codec/byte comparison, not a550-card transfer or physical-phone result. No source/output image files rewritten."}
	DirAccess.make_dir_recursive_absolute("res://work/production-art")
	var f:=FileAccess.open("res://work/production-art/compact-codec-comparison-detailed.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true)+"\n");f.close()
	print("PRODUCTION COMPACT CODEC COMPARISON: %d assertions, %d failures; Q90 %d bytes, lossless %d bytes" % [assertions,failures,quality90_total,lossless_total])
	root.get_node("GameAudio").request_quit(0 if failures==0 else 1)
