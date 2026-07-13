class_name Element
extends RefCounted

enum { NONE, WATER, STONE, EARTH, STEAM, LAVA, PLANT, ORE, GRASS }

const NAMES = {
	NONE: "NONE", WATER: "WATER", STONE: "STONE", EARTH: "EARTH",
	STEAM: "STEAM", LAVA: "LAVA", PLANT: "PLANT", ORE: "ORE", GRASS: "GRASS"
}

static func from_string(s: String) -> int:
	for k in NAMES.keys():
		if NAMES[k] == s.to_upper():
			return k
	return NONE