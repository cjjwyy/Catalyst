class_name State
extends RefCounted

enum { NONE, BURNING, STEAMED, FROZEN, ASH }

const NAMES = {
	NONE: "NONE", BURNING: "BURNING", STEAMED: "STEAMED", FROZEN: "FROZEN", ASH: "ASH"
}

static func from_string(s: String) -> int:
	for k in NAMES.keys():
		if NAMES[k] == s.to_upper():
			return k
	return NONE