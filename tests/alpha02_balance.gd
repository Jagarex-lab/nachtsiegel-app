extends SceneTree
const Model=preload("res://scripts/alpha/model.gd")
const Catalog=preload("res://scripts/alpha/catalog.gd")
var records: Array=[]
func _initialize():call_deferred("run")
func make_game(a: String,b: String,seed_value: int):
 var m=Model.new();m.start_alpha(m.catalog.deck(a),m.catalog.deck(b),seed_value,2)
 var exchange: Array=[]
 for i in m.state.hero.hand.size():
  if m.catalog.card(m.state.hero.hand[i]).cost>3:exchange.append(i)
 m.mulligan(exchange)
 return m
func seeds_for(a: String,b: String) -> Array:
 var selected: Array=[];var counts={"hero":0,"enemy":0}
 for seed_value in 2048:
  var m=make_game(a,b,seed_value)
  if counts[m.state.coin]<8:selected.append(seed_value);counts[m.state.coin]+=1
  if counts.hero==8 and counts.enemy==8:return selected
 push_error("Cannot counterbalance seeds");return []
func run():
 for a in Catalog.new().deck_ids():
  for b in Catalog.new().deck_ids():
   var seeds=seeds_for(a,b)
   for condition in ["official","convergence_off","origin_shield_off"]:
    for seed_value in seeds:
     var m=make_game(a,b,seed_value)
     m.convergence_enabled=condition!="convergence_off";m.state.convergence_enabled=m.convergence_enabled
     if condition=="origin_shield_off":m.state.origin_used={"hero":true,"enemy":true}
     m.choose_origin(2)
     if m.state.stage=="second":
      # Mirror the existing opponent's second-player heuristic, without
      # introducing a new production rule or pretending human optimal play.
      var highest=-1
      for i in m.state.hero.hand.size():
       if m.catalog.card(m.state.hero.hand[i]).cost>3:highest=i
      if highest>=0:m.second_exchange(highest)
      m.second_change((int(m.state.origins.hero)+1)%5);m.finish_opening()
     var turns=0
     while m.state.winner==null and m.state.error.is_empty() and turns<400:
      m.ai_turn("hero");turns+=1
     var declarations=0;var broken=0
     for e in m.events:
      if e.kind=="convergence_declared":declarations+=1
      if e.kind=="convergence_failed":broken+=1
     records.append({"condition":condition,"hero":a,"enemy":b,"seed":seed_value,"first":m.state.coin,"winner":m.state.winner,"round":m.state.round,"declarations":declarations,"broken":broken,"convergence":not m.events.is_empty() and m.events[-1].kind=="convergence_win","longest_chain":m.longest_chain,"error":m.state.error,"censored":m.state.winner==null})
 var f=FileAccess.open("res://work/alpha02/balance.json",FileAccess.WRITE);f.store_string(JSON.stringify(records));f.close()
 var errors=0
 for r in records:
  if not r.error.is_empty():errors+=1
 print("ALPHA02 BALANCE: %d deterministic games, %d engine errors; censored games recorded explicitly" % [records.size(),errors])
 quit(0 if errors==0 and records.size()==768 else 1)
