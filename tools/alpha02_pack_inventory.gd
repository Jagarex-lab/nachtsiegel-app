## Read-only inventory of the mounted export; optional hard rejection of tooling.
extends SceneTree
var files=[]
func walk(path):
 var d=DirAccess.open(path)
 if d==null:return
 d.include_hidden=true;d.list_dir_begin()
 var n=d.get_next()
 while n!="":
  if n not in [".",".."]:
   var p=path.path_join(n)
   if d.current_is_dir():walk(p)
   else:
    var f=FileAccess.open(p,FileAccess.READ)
    if f:files.append({"path":p,"bytes":f.get_length(),"sha256":FileAccess.get_sha256(p)})
  n=d.get_next()
 d.list_dir_end()
func _initialize():
 walk("res://");files.sort_custom(func(a,b):return a.bytes>b.bytes)
 var forbidden=files.filter(func(f):return f.path.begins_with("res://node_modules/") or f.path.begins_with("res://work/") or f.path.begins_with("res://tests/") or f.path.begins_with("res://tools/") or f.path.begins_with("res://docs/"))
 var total=0
 for file in files:total+=int(file.bytes)
 print(JSON.stringify({"files":files,"resource_bytes":total,"forbidden":forbidden}))
 quit(1 if "--reject-test-assets" in OS.get_cmdline_user_args() and not forbidden.is_empty() else 0)
