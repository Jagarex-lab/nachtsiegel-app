extends RefCounted
## Persist the outbox before publishing. External consumers MUST honor grant.key.
signal grant_requested(reward_id: String, payload: Dictionary, idempotency_key: String)

func stage(reward_id: String, definition: Dictionary, data: Dictionary) -> bool:
	if data.reward_ledger.has(reward_id): return false
	var grant := {"key":"orafold-campaign:"+reward_id,"state":"pending","type":definition.get("type","external"),"target":definition.get("target",""),"payload":definition.get("payload",{}).duplicate(true)}
	if grant.type == "character_info":
		if not data.character_info.has(grant.target): data.character_info.append(grant.target)
		grant.state = "delivered"
	elif grant.type == "chapter":
		if not data.unlocked_chapters.has(grant.target): data.unlocked_chapters.append(grant.target)
		grant.state = "delivered"
	data.reward_ledger[reward_id] = grant
	return true

func pending(data: Dictionary) -> Array:
	var result: Array = []
	for id in data.reward_ledger:
		var grant: Dictionary = data.reward_ledger[id]
		if grant.state == "pending": result.append({"id":id,"key":grant.key,"payload":grant.duplicate(true)})
	return result

func publish_pending(data: Dictionary) -> void:
	for grant in pending(data): grant_requested.emit(grant.id,grant.payload,grant.key)

func acknowledge(data: Dictionary, reward_id: String, idempotency_key: String) -> bool:
	if not data.reward_ledger.has(reward_id): return false
	var grant: Dictionary = data.reward_ledger[reward_id]
	if grant.key != idempotency_key or grant.state != "pending": return false
	grant.state = "delivered"
	return true
