class_name Element
extends RefCounted

enum { NONE, WATER, STONE, EARTH, STEAM, LAVA, PLANT }

const NAMES = {
	NONE: "NONE", WATER: "WATER", STONE: "STONE", EARTH: "EARTH",
	STEAM: "STEAM", LAVA: "LAVA", PLANT: "PLANT"
}

static func from_string(s: String) -> int:
	for k in NAMES.keys():
		if NAMES[k] == s.to_upper():
			return k
	return NONE