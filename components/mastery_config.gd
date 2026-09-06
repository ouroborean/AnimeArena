class_name MasteryConfig

const MAX_LEVEL = 100

# XP required to reach each level (cumulative). Index = level number.
const XP_THRESHOLDS: Array[int] = [
	0,           # Level 0 (starting point)
	100,         # Level 1
	250,         # Level 2
	475,         # Level 3
	800,         # Level 4
	1250,        # Level 5
	1850,        # Level 6
	2650,        # Level 7
	3700,        # Level 8
	5050,        # Level 9
	6750,        # Level 10
	8850,        # Level 11
	11400,       # Level 12
	14500,       # Level 13
	18200,       # Level 14
	22600,       # Level 15
	27800,       # Level 16
	34000,       # Level 17
	41300,       # Level 18
	49900,       # Level 19
	60000,       # Level 20
	71800,       # Level 21
	85600,       # Level 22
	101700,      # Level 23
	120400,      # Level 24
	142100,      # Level 25
	167300,      # Level 26
	196500,      # Level 27
	230300,      # Level 28
	269400,      # Level 29
	314600,      # Level 30
	366700,      # Level 31
	426700,      # Level 32
	495700,      # Level 33
	575000,      # Level 34
	666000,      # Level 35
	770300,      # Level 36
	889700,      # Level 37
	1026200,     # Level 38
	1182000,     # Level 39
	1359600,     # Level 40
	1561800,     # Level 41
	1791700,     # Level 42
	2052800,     # Level 43
	2348900,     # Level 44
	2684200,     # Level 45
	3063400,     # Level 46
	3491700,     # Level 47
	3974800,     # Level 48
	4519000,     # Level 49
	5131200,     # Level 50
	5819100,     # Level 51
	6590900,     # Level 52
	7455700,     # Level 53
	8423400,     # Level 54
	9504800,     # Level 55
	10711600,    # Level 56
	12056600,    # Level 57
	13553600,    # Level 58
	15217900,    # Level 59
	17065300,    # Level 60
	19113500,    # Level 61
	21380900,    # Level 62
	23887500,    # Level 63
	26654800,    # Level 64
	29705700,    # Level 65
	33064700,    # Level 66
	36756900,    # Level 67
	40810900,    # Level 68
	45256100,    # Level 69
	50123600,    # Level 70
	55446200,    # Level 71
	61258500,    # Level 72
	67595300,    # Level 73
	74496100,    # Level 74
	82000700,    # Level 75
	90150700,    # Level 76
	98989400,    # Level 77
	108561700,   # Level 78
	118914600,   # Level 79
	130095700,   # Level 80
	142153400,   # Level 81
	155139500,   # Level 82
	169106200,   # Level 83
	184104400,   # Level 84
	200189900,   # Level 85
	217417500,   # Level 86
	235842300,   # Level 87
	255520000,   # Level 88
	276506300,   # Level 89
	298856700,   # Level 90
	322626400,   # Level 91
	347869800,   # Level 92
	374640400,   # Level 93
	402990400,   # Level 94
	432970500,   # Level 95
	464630000,   # Level 96
	498014100,   # Level 97
	533167600,   # Level 98
	570131600,   # Level 99
	608943800,   # Level 100
]

# XP awarded to each character on the winning team per match.
const XP_PER_WIN = 100

# XP deducted from each character on the losing team per match.
const XP_PER_LOSS = 40

# XP cannot drop below this value.
const XP_FLOOR = 0

# Cosmetic unlock thresholds (by mastery level).
const UNLOCK_THRESHOLDS = {
	"lesser_title": 2,
	"playercard": 3,
	"greater_title": 4,
	"action_frame": 5,
	"hat": 8,
	"elite_action_frame": 12,
}


static func xp_to_level(xp: int) -> int:
	for i in range(MAX_LEVEL, -1, -1):
		if xp >= XP_THRESHOLDS[i]:
			return i
	return 0


static func xp_to_next_level(xp: int) -> int:
	var level = xp_to_level(xp)
	if level >= MAX_LEVEL:
		return 0
	return XP_THRESHOLDS[level + 1] - xp


static func xp_at_current_level(xp: int) -> int:
	return XP_THRESHOLDS[xp_to_level(xp)]


static func xp_at_next_level(xp: int) -> int:
	var level = xp_to_level(xp)
	if level >= MAX_LEVEL:
		return XP_THRESHOLDS[MAX_LEVEL]
	return XP_THRESHOLDS[level + 1]


static func level_progress_fraction(xp: int) -> float:
	var level = xp_to_level(xp)
	if level >= MAX_LEVEL:
		return 1.0
	var floor_xp = XP_THRESHOLDS[level]
	var ceil_xp = XP_THRESHOLDS[level + 1]
	if ceil_xp == floor_xp:
		return 1.0
	return float(xp - floor_xp) / float(ceil_xp - floor_xp)


static func get_cosmetic_id(type: String, character_path: String) -> String:
	match type:
		"playercard": return "playercard_mastery_" + character_path
		"action_frame": return "gamepanel_mastery_" + character_path
		"hat": return "hat_mastery_" + character_path
		"elite_action_frame": return "mastery_panel_elite_" + character_path
	return ""


static func get_unlocked_cosmetics_for_character(mastery_level: int, character_path: String) -> Dictionary:
	var unlocks = {}
	for type in UNLOCK_THRESHOLDS:
		unlocks[type] = mastery_level >= UNLOCK_THRESHOLDS[type]
	return unlocks


static func can_equip_mastery_portrait(mastery_level: int) -> bool:
	return mastery_level >= 15


static func can_equip_mastery_skin(mastery_level: int) -> bool:
	return mastery_level >= 20
