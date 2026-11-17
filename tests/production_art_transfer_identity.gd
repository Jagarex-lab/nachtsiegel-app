extends SceneTree
## Controlled callback-order regression with unchanged, real loopback WebP bytes.
## The late callback is injected deliberately; this is not a claim that browser
## scheduling reproduces the same race on every run.
const ART=preload("res://scripts/production/art_resolver.gd")
const DELIVERY=preload("res://scripts/production/art_delivery.gd")
var assertions:=0
var failures:=0
var service: Node
var owner_node: Node
var observations: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 assertions+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func sha(body: PackedByteArray) -> String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(body);return h.finish().hex_encode()
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=1:check(false,"actual loopback fixture URL required");await finish();return
 var base: String=args[0]
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_preview_delivery.json"))
 var ids: Array=[]
 for id in manifest.entries:
  if manifest.entries[id].get("delivery")=="external":ids.append(id)
 ids.sort()
 var compact_id: String=ids[0]
 var full_id:="oa-stillwatch-c01"
 var compact: Dictionary=manifest.entries[compact_id]
 # Obtain actual committed compact bytes through an independent genuine request.
 var fetch:=HTTPRequest.new();root.add_child(fetch)
 check(fetch.request(base+"ok/"+str(compact.relative_url))==OK,"real old-response body request starts")
 var response: Array=await fetch.request_completed
 fetch.queue_free()
 var body: PackedByteArray=response[3]
 check(response[0]==HTTPRequest.RESULT_SUCCESS and response[1]==200 and body.size()==int(compact.bytes) and sha(body)==compact.web_sha256,"late response fixture is the exact real compact WebP, not invented bytes")
 var previous=root.get_node_or_null("ArtDelivery")
 if previous!=null:root.remove_child(previous);previous.free()
 ART.clear_cache()
 service=DELIVERY.new(base+"slow/");service.name="ArtDelivery";root.add_child(service)
 owner_node=Node.new();root.add_child(owner_node)
 service.request_preview(compact_id,owner_node);service._start_next()
 check(service.metrics().active=="compact|"+compact_id,"real compact transfer is active before handoff")
 var old_http: HTTPRequest=service._http
 var old_http_id:=old_http.get_instance_id()
 var old_callback: Callable=old_http.request_completed.get_connections()[0].callable
 service.request_full(full_id,owner_node);service._start_next()
 check(service.metrics().active=="full|"+full_id,"inspector preempts compact and has a distinct current full transfer")
 # Simulate an already queued completion captured BEFORE cancellation. The
 # bound original callback is stronger than a disconnected old sender signal.
 old_callback.call(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(["Content-Type: image/webp"]),body)
 observations.after_late=service.metrics()
 check(service.metrics().active=="full|"+full_id,"a late compact completion cannot clear/reject the current full request")
 check(service.metrics().rejected==0 and service.state_for(full_id)=="loading","old response cannot install a full-art failure/cooldown")
 if failures>0:await finish();return
 check(service._http.get_instance_id()!=old_http_id,"native HTTPRequest is isolated per transfer, so old native request_done cannot cancel its successor")
 var deadline:=Time.get_ticks_msec()+15000
 while Time.get_ticks_msec()<deadline:
  var m: Dictionary=service.metrics()
  if m.active.is_empty() and m.queued==0 and m.completed>=2:break
  await process_frame
 var done: Dictionary=service.metrics();observations.completed=done
 check(done.completed==2 and done.rejected==0 and done.cancelled==1,"real full body and resumed compact both verify after the stale callback")
 var full=ART.resolve({"id":full_id},"full",owner_node,false)
 var preview=ART.resolve({"id":compact_id},"compact",owner_node,false)
 check(full.texture!=null and full.texture.get_size()==Vector2(1448,1086) and not full.preview_only and full.delivery_state=="ready","native-size actual full art survives handoff")
 check(preview.texture!=null and preview.texture.get_size()==Vector2(compact.width,compact.height),"actual compact request resumes independently")
 check(done.recent_events.size()<=32 and done.recent_failures.size()<=16,"transfer evidence has fixed memory bounds")
 check(done.stale_callbacks==1,"only the deliberately injected old callback was ignored")
 for frame in 2:await process_frame
 check(service.get_child_count()==0,"completed transfer HTTPRequest nodes do not accumulate")
 # A first real HTTP503 followed by HTTP200 models a transient outage. The
 # fixture advances only its retry deadline, not the production cooldown rule.
 service.free();ART.clear_cache()
 service=DELIVERY.new(base+"recover-"+str(Time.get_ticks_usec())+"/");service.name="ArtDelivery";root.add_child(service)
 service.request_full(full_id,owner_node)
 var until:=Time.get_ticks_msec()+15000
 while Time.get_ticks_msec()<until and service.metrics().rejected<1:await process_frame
 var outage: Dictionary=service.metrics()
 check(service.state_for(full_id)=="failed" and not outage.recent_failures.is_empty() and outage.recent_failures.back().http_status==503,"actual transient HTTP503 is rejected and retained as per-transfer evidence")
 if outage.recent_failures.is_empty():await finish();return
 var key:="full|"+full_id
 check(int(service._retry_after.get(key,0))>Time.get_ticks_msec() and DELIVERY.RETRY_MSEC==30000,"production thirty-second cooldown remains enforced")
 service._retry_after[key]=Time.get_ticks_msec()+60
 until=Time.get_ticks_msec()+15000
 while Time.get_ticks_msec()<until and service.metrics().completed<1:await process_frame
 var recovered: Dictionary=service.metrics();observations.recovered=recovered
 check(recovered.completed==1 and recovered.rejected==1 and recovered.started==2 and ART.has_full_texture(full_id),"visible owner retries after cooldown without redraw, reopen or another request call")
 check(recovered.last_failure.is_empty() and recovered.recent_failures.size()==1 and recovered.recent_failures[0].http_status==503,"later success cannot erase the actual prior failure evidence")
 # Once visibility ownership ends, even an elapsed cooldown must not restart.
 service.free();ART.clear_cache()
 service=DELIVERY.new(base+"missing/");service.name="ArtDelivery";root.add_child(service)
 service.request_full(full_id,owner_node)
 until=Time.get_ticks_msec()+15000
 while Time.get_ticks_msec()<until and service.metrics().rejected<1:await process_frame
 service.release_owner(owner_node);owner_node.free()
 service._retry_after[key]=Time.get_ticks_msec()-1
 until=Time.get_ticks_msec()+120
 while Time.get_ticks_msec()<until:await process_frame
 check(service.metrics().started==1 and service.metrics().queued==0,"expired retries remain cancelled when no visible owner survives")
 await finish()
func finish() -> void:
 DirAccess.make_dir_recursive_absolute("res://work/production-art")
 var file=FileAccess.open("res://work/production-art/transfer-identity-result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"source_sha256":FileAccess.get_sha256("res://scripts/production/art_delivery.gd"),"scope":"controlled late callback using real loopback compact bytes, followed by verified actual full/compact HTTP; browser timing proof is separate","observations":observations},"  "));file.close()
 if is_instance_valid(owner_node):owner_node.free()
 if is_instance_valid(service):service.free()
 ART.clear_cache()
 for i in 2:await process_frame
 print("PRODUCTION ART TRANSFER IDENTITY: ",assertions," assertions, ",failures," failures; late cancelled callback, real full/preview verification, bounded diagnostics")
 root.get_node("GameAudio").request_quit(1 if failures else 0)
