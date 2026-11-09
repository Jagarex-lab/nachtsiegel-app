extends RefCounted
## Original enemyTurn decision order. Stable ties; no RNG, no free resources.
static func take_turn(m) -> void:
	var ep: Dictionary=m.state.enemy
	var hp: Dictionary=m.state.hero
	if ep.phase=="main" and int(ep.resonance)>=3 and not ep.tacticUsed:
		var options: Array=[]
		for i in 5:
			if ep.lanes[i]==null:continue
			for j in [i-1,i+1]:
				if j>=0 and j<5 and ep.lanes[j]==null:
					var score: int=(3 if hp.lanes[j]!=null else 2)-(1 if hp.lanes[i]!=null else 0)+(2 if int(hp.seals)>0 and hp.lanes[j]!=null else 0)
					options.append({"from":i,"to":j,"score":score})
		var best: Dictionary={}
		for option: Dictionary in options:
			if best.is_empty() or option.score>best.score:best=option
		if not best.is_empty() and best.score>=2:m.tactical_move("enemy",best.from,best.to)
	for _attempt in 8:
		if m.state.winner!=null or m.state.active!="enemy":break
		var p: Dictionary=m.state.enemy
		var best := choice(m,"enemy")
		if int(p.summons)>=2 or best.is_empty():
			if p.deck.is_empty() and m.recover("enemy"):continue
			break
		if not m.play("enemy",best.index,best.lane):break
	if int(ep.resonance)>=2 and not ep.fortifyUsed and int(ep.hp)<19:
		for i in 5:
			if ep.lanes[i]!=null:m.fortify("enemy",i);break
	if ep.pendingShift!=null:m.skip_shift("enemy")
	if m.state.winner==null:
		if ep.deck.is_empty():m.recover("enemy")
		m.end_turn("enemy")
static func choice(m, side: String) -> Dictionary:
	var p: Dictionary=m.state[side]
	var op: Dictionary=m.state[m._other(side)]
	var hard: bool=int(m.state.level)>=5
	var easy: bool=int(m.state.level)<=1
	var best: Dictionary={}
	for index in p.hand.size():
		var card: Dictionary=m.catalog.card(p.hand[index])
		if card.is_empty() or int(card.cost)>int(p.energy):continue
		for lane in 5:
			if p.lanes[lane]!=null:continue
			var target: Variant=op.lanes[lane]
			var score: float=float(card.atk)+float(card.hp)*.35+float(card.power)*.65-float(card.cost)*.22
			if target!=null:
				score+=( (5 if target.hp<=card.atk else 0)+(2 if card.hp>target.atk else 0)+float(target.atk)*.25 ) if hard else 1.5
			else:score+=float(card.atk)*.65 if hard else .4
			if card.effect=="strike":
				var occupied := false
				for u in op.lanes:
					if u!=null:occupied=true
				score+=2 if occupied else 1
			if card.effect=="rally" and ((lane>0 and p.lanes[lane-1]!=null) or (lane<4 and p.lanes[lane+1]!=null)):score+=4 if hard else 1
			if card.effect=="silence" and target!=null:score+=3 if hard else 1
			if card.effect=="guard" and p.hp<15:score+=2
			if card.effect=="mend" and p.hp<p.maxHp-4:score+=2
			if card.effect=="haste" and target==null:score+=4 if hard else 2
			if p.attune!=null and p.attune!=card.order:score+=3 if hard else 1
			if easy:score=float(card.atk)+float(card.hp)*.2+(.1 if lane==2 else 0)
			if best.is_empty() or score>best.score or (score==best.score and lane<best.lane):best={"index":index,"lane":lane,"score":score}
	return best
