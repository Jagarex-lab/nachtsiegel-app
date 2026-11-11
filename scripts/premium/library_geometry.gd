extends RefCounted
## Pure CSS/control-pixel geometry. Actual ScrollContainer width is authoritative,
## including when a desktop library shares the page with a separate deck pane.
const CARD_ASPECT := 63.0/88.0
const GAP := 8.0
const MINIMUM_WIDTH := 156.0
static func fit(available_width: float, desktop: bool=false) -> Dictionary:
	var width=maxf(44.0,available_width) if is_finite(available_width) else 44.0
	var maximum=6 if desktop else 4
	var columns=clampi(floori((width+GAP)/(MINIMUM_WIDTH+GAP)),1,maximum)
	var card_width=floorf((width-GAP*(columns-1))/columns)
	var card_height=roundf(card_width/CARD_ASPECT)
	return {"columns":columns,"card_width":card_width,"card_height":card_height,"grid_width":columns*card_width+GAP*(columns-1),"gap":GAP}
