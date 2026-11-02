extends RefCounted
## The render categories as RenderSettings matched them before they moved into
## each map's CategoryRules (2026-11-02): node-name prefixes, checked in this
## order. Kept only so tests can prove the move changed no mesh's category.

const CATEGORIES := {
	"facade_detail": ["Detail_", "MosqueDetail_", "LandmarkDetail_"],
	"decor": ["Galata_Bridge_Detail", "Halic_Metro_Bridge_Detail", "BridgeDetail_", "BridgeGlass_",
			"RoadPaint_", "TrafficSignals_", "SignalGlow_", "Ferry_"],
	"lamps": ["StreetLamps_", "LampGlow_"],
	"trees": ["Trees_", "TreeTrunks_", "Shrubs_"],
	"buildings": ["Buildings_", "Mosque_", "Landmark_"],
	"ground": ["Ground_", "Road_", "Pavement_", "Quays_", "Gardens_", "Galata_Bridge", "Halic_Metro_Bridge",
			"Ataturk_Bridge"],
	"water": ["Water"],
}
const OCCLUDER_CATEGORIES := ["buildings", "ground"]
const FOG_COLOR := Color(0.843137, 0.866667, 0.815686)


static func category_of(node_name: String) -> String:
	for category in CATEGORIES:
		for prefix: String in CATEGORIES[category]:
			if node_name.begins_with(prefix):
				return category
	return ""
