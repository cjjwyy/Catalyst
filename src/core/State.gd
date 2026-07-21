class_name State
extends RefCounted

enum { NONE, BURNING, STEAMED, FROZEN, ASH, DUST, SNOW, BLESSED, METEOR_LAVA }

const NAMES = {
	NONE: "NONE", BURNING: "BURNING", STEAMED: "STEAMED", FROZEN: "FROZEN", ASH: "ASH", DUST: "DUST", SNOW: "SNOW", BLESSED: "BLESSED", METEOR_LAVA: "METEOR_LAVA"
}

static func from_string(s: String) -> int:
	for k in NAMES.keys():
		if NAMES[k] == s.to_upper():
			return k
	return NONE