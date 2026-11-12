extends RefCounted
## Presentation geometry in logical CSS pixels. It never reads or changes rules.
## Upright hit rectangles remain identical over flat, 2.5D and 3D backdrops.
const CARD_ASPECT := 63.0 / 88.0
const TOUCH := 44.0
const HEADER := 44.0
const GAP := 6.0

static func measure(view: Vector2, hand_count: int = 6, selected_index: int = -1) -> Dictionary:
	var width=maxf(320.0,view.x)
	var height=maxf(240.0,view.y)
	var emergency=height<280.0
	var header_h=52.0 if height>=560 else HEADER
	var dock_w=clampf(width*.255,184.0,264.0)
	var hand_h=minf(clampf(height*.345,112.0,190.0),height-header_h-(88.0 if emergency else 99.0)-GAP)
	var board_h=height-header_h-hand_h-GAP
	var hand_y=header_h+board_h+GAP
	var rail=Rect2(0,hand_y,width-dock_w-GAP,hand_h)
	var dock=Rect2(width-dock_w,hand_y,dock_w,hand_h)
	var count=maxi(1,hand_count)
	# Browser bars can leave only248CSS pixels. At that emergency height we
	# prioritise100px illustrations and all ten44px targets over decorative fan.
	var selected_scale=1.0 if emergency else 1.10
	var enlarged=selected_index>=0 and selected_index<hand_count
	var reserve=2.0 if emergency else 10.0
	var card_h=minf(minf(hand_h-reserve,(hand_h-2.0)/selected_scale),((rail.size.x-5.0*(count-1))/(count+selected_scale-1.0 if enlarged else count))/CARD_ASPECT)
	var card_w=card_h*CARD_ASPECT
	var span=card_w*(count+selected_scale-1.0 if enlarged else count)+5.0*(count-1)
	return {"header":Rect2(0,0,width,header_h),"board":Rect2(0,header_h,width,board_h),"hand":rail,"dock":dock,"card_size":Vector2(card_w,card_h),"hand_left":rail.position.x+(rail.size.x-span)/2.0,"card_gap":5.0,"selected_index":selected_index,"selected_scale":selected_scale,"emergency":emergency,"touch":TOUCH}

static func hand_rect(metrics: Dictionary, index: int, count: int, selected: bool=false) -> Rect2:
	var dimensions: Vector2=metrics.card_size
	# A restrained fan uses translation, never a skewed touch surface. Every card
	# retains its complete cost/name/stat area; selecting lifts it into the gutter.
	var center=(float(count)-1.0)/2.0
	var fan=0.0 if metrics.emergency else minf(3.0,absf(float(index)-center)*1.2)
	var at=Vector2(float(metrics.hand_left)+index*(dimensions.x+float(metrics.card_gap)),metrics.hand.position.y+(1.0 if metrics.emergency else 6.0)+fan)
	if int(metrics.selected_index)>=0 and index>int(metrics.selected_index):at.x+=dimensions.x*(float(metrics.selected_scale)-1.0)
	if selected:
		# Enlargement gets its own horizontal budget; no neighbour's cost, name,
		# or stat area is covered. Even the 248px tier stays within the safe area.
		at.y=metrics.hand.position.y+1.0
		dimensions*=float(metrics.selected_scale)
	return Rect2(at,dimensions)
