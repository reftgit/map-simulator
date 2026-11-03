extends RefCounted
## Axis and unit detection of the import tool (docs/MAP_CONTRACT.md, C2 and
## C3): which way is up, from the model's box and the orientation of its flat
## faces, and whether the model is in a common unit other than metres, from
## its extent and the size of its objects. Functions of measurements only, so
## the tests feed them numbers.

## Rotation that turns each up direction to +Y.
const TO_Y_UP := {
	"+y": Basis.IDENTITY,
	"-y": Basis(Vector3.RIGHT, PI),
	"+z": Basis(Vector3.RIGHT, -PI / 2.0),
	"-z": Basis(Vector3.RIGHT, PI / 2.0),
	"+x": Basis(Vector3.BACK, PI / 2.0),
	"-x": Basis(Vector3.BACK, -PI / 2.0),
}
## Configuration values of "up_axis" and the direction each names.
const UP_AXES := {"y": "+y", "-y": "-y", "z": "+z", "-z": "-z", "x": "+x", "-x": "-x"}
## A model is flat along an axis when its extent there is at most FLAT of its
## middle extent, very flat at FLATTEST. A flat face is within 30° of an axis.
const FLAT := 0.5
const FLATTEST := 0.25
## One axis holds clearly more flat faces than another at this ratio; one
## side of an axis faces up when it holds SIDE_RATIO times the other's area.
const AREA_RATIO := 1.5
const SIDE_RATIO := 1.5
## The base of a model (its ground, a printed relief's flat underside) is
## the end of the up axis where its flat faces gather: END_RATIO times the
## flat area of the other end, each end being END_BAND of the extent.
const END_RATIO := 2.0
const END_BAND := 0.02
## Common units other than metres, with their size in metres.
const UNITS := [["millimetres", 0.001], ["centimetres", 0.01], ["inches", 0.0254], ["feet", 0.3048]]
## C2: horizontal extent of a map (m), the height of its typical object (m)
## for a unit to fit, and the size a suggested scale gives the typical object.
const MIN_EXTENT := 20.0
const MAX_EXTENT := 10000.0
const MIN_OBJECT := 2.0
const MAX_OBJECT := 40.0
const TYPICAL := 8.0


## The up direction of a model from its box `size`, its face statistics
## `faces` (map_geometry.gd, stats(): the area facing each direction "+x" …
## "-z" and "at_<direction>", the area-weighted coordinate along that axis),
## and, when known, `ends`: the flat face area in the low and the high
## END_BAND of the extent along the axis this function chose before.
## A map is wide and flat: its smallest extent and most of its flat faces
## (ground, roofs) are across the up axis. Which side is up: the end where the
## flat faces gather is the base (ground, a printed relief's underside); else
## the side with more faces toward it (open ground has no underside); for a
## closed shape with both sides alike, the side whose faces lie higher. When
## the base and the faces' winding disagree (an inside-out model, or a mesa
## top), nothing is decided. Returns {"axis": "x" | "y" | "z" | "", "up": "+y" …,
## "decided": bool, "winding": "+" | "-" | "", "reason": text}.
static func detect_up(size: Vector3, faces: Dictionary, ends := Vector2(-1.0, -1.0)) -> Dictionary:
	var extents := {"x": size.x, "y": size.y, "z": size.z}
	var by_extent := ["x", "y", "z"]
	by_extent.sort_custom(func(a: String, b: String) -> bool: return extents[a] < extents[b])
	var flattest: String = by_extent[0]
	var flatness: float = extents[flattest] / maxf(extents[by_extent[1]], 1e-9)
	var flat_area := {}
	for axis in ["x", "y", "z"]:
		flat_area[axis] = float(faces.get("+" + axis, 0.0)) + float(faces.get("-" + axis, 0.0))
	var by_area := ["x", "y", "z"]
	by_area.sort_custom(func(a: String, b: String) -> bool: return flat_area[a] > flat_area[b])
	var most: String = by_area[0]
	var clearly_most: bool = flat_area[most] >= AREA_RATIO * flat_area[by_area[1]]
	var axis := ""
	var why := ""
	if most == flattest and (flatness <= FLAT or clearly_most):
		axis = most
		why = "flattest across %s (%.2f of its middle extent) and most flat faces across it" % [axis.to_upper(), flatness]
	elif flatness <= FLATTEST:
		axis = flattest
		why = "very flat across %s (%.2f of its middle extent), though most flat faces are across %s" % [axis.to_upper(), flatness, most.to_upper()]
	elif clearly_most and flat_area[most] >= 2.0 * flat_area[by_area[1]]:
		axis = most
		why = "most flat faces across %s, though flattest across %s" % [axis.to_upper(), flattest.to_upper()]
	var areas := "flat faces: %.0f across X, %.0f across Y, %.0f across Z; box %.1f × %.1f × %.1f" % [flat_area.x, flat_area.y, flat_area.z, size.x, size.y, size.z]
	if axis.is_empty():
		return {"axis": "", "up": "+y", "decided": false, "winding": "", "reason": "neither the box nor the faces show the up axis (%s)" % areas}
	var big := axis.to_upper()
	var plus := float(faces.get("+" + axis, 0.0))
	var minus := float(faces.get("-" + axis, 0.0))
	var winding := ""
	if minus >= SIDE_RATIO * plus and minus > 0.0:
		winding = "-"
	elif plus >= SIDE_RATIO * minus and plus > 0.0:
		winding = "+"
	var base := ""
	if ends.x >= 0.0:
		if ends.x >= END_RATIO * ends.y and ends.x > 0.0:
			base = "+"
		elif ends.y >= END_RATIO * ends.x and ends.y > 0.0:
			base = "-"
	var faced := "%.0f faces toward +%s, %.0f toward −%s" % [plus, big, minus, big]
	var based := "flat faces at the low end %.0f, at the high end %.0f" % [ends.x, ends.y]
	var sign := ""
	if not base.is_empty() and not winding.is_empty() and base != winding:
		return {"axis": axis, "up": "+y", "decided": false, "winding": winding,
				"reason": "%s, but the base (%s) and the faces (%s) point opposite ways: inside out, or a flat top? (%s)" % [why, based, faced, areas]}
	elif not base.is_empty():
		sign = base
		why += "; its base is at the %s end (%s)" % ["low" if base == "+" else "high", based]
	elif not winding.is_empty():
		sign = winding
		why += "; " + faced
	else:
		var plus_at := float(faces.get("at_+" + axis, 0.0)) / maxf(plus, 1e-9)
		var minus_at := float(faces.get("at_-" + axis, 0.0)) / maxf(minus, 1e-9)
		sign = "+" if plus_at >= minus_at else "-"
		why += "; both sides alike, the faces toward %s%s lie higher (%.1f against %.1f)" % [sign, big, maxf(plus_at, minus_at), minf(plus_at, minus_at)]
	return {"axis": axis, "up": sign + axis, "decided": true, "winding": winding, "reason": "%s (%s)" % [why, areas]}


## The common unit a model is in when it is not in metres: the unit that
## gives a map-sized `extent` and a typical object `typical_height` of
## plausible height. {} when none fits; {"choices": [...]} when several fit
## about as well (the user must say which).
static func unit_of(extent: float, typical_height: float) -> Dictionary:
	var fits := []
	for unit: Array in UNITS:
		var factor: float = unit[1]
		if extent * factor >= MIN_EXTENT and extent * factor <= MAX_EXTENT \
				and typical_height * factor >= MIN_OBJECT and typical_height * factor <= MAX_OBJECT:
			fits.append([unit[0], factor, absf(log(typical_height * factor / TYPICAL))])
	if fits.is_empty():
		return {}
	fits.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	if fits.size() > 1 and fits[1][2] - fits[0][2] < 0.3:
		return {"choices": fits.map(func(fit: Array) -> String: return "%s (%s)" % [fit[0], str(fit[1])])}
	return {"name": fits[0][0], "factor": fits[0][1]}


## A scale for a model in unknown units: its typical object (75th percentile
## of its separate objects' heights and widths) becomes at least TYPICAL m
## tall and wide, rounded to 1, 2, 2.5, or 5 times a power of ten. A bigger
## guess is the safer one: streets too wide still play, too narrow do not.
static func suggest_scale(typical_height: float, typical_width: float) -> float:
	var wanted := 0.0
	if typical_height > 0.0:
		wanted = TYPICAL / typical_height
	if typical_width > 0.0:
		wanted = maxf(wanted, TYPICAL / typical_width)
	return nice(wanted) if wanted > 0.0 else 1.0


## 1, 2, 2.5, or 5 times a power of ten, nearest to `value`.
static func nice(value: float) -> float:
	var power := pow(10.0, floor(log(value) / log(10.0)))
	var best := power
	for step in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if absf(step * power - value) < absf(best - value):
			best = step * power
	return best
