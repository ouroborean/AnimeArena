extends Node
class_name CharacterConcept

var character_name: String
var portrait_texture: Texture
var description: String
var path_name: String
enum Universe {
	NARUTO,
	BLEACH,
	ONE_PIECE,
	MY_HERO_ACADEMIA,
	BLACK_CLOVER,
	MADOKA_MAGICA,
	FAIRY_TAIL,
	SOUL_EATER,
	AVATAR,
	AKAME_GA_KILL,
	DEMON_SLAYER,
	SEVEN_DEADLY_SINS,
	KATEKYO_HITMAN_REBORN,
	ATTACK_ON_TITAN,
	ONE_PUNCH_MAN,
	FIRE_FORCE,
	HUNTER_X_HUNTER,
	A_CERTAIN_SCIENTIFIC_RAILGUN,
	FATE,
	KILL_LA_KILL,
	DEADMAN_WONDERLAND,
	TOKYO_GHOUL,
	THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME,
	JUJUTSU_KAISEN,
	DIGIMON,
	SAILOR_MOON,
	INVINCIBLE,
	DRAGON_BALL,
	MASHLE,
	EMINENCE_IN_SHADOW,
	FRIEREN,
	SOLO_LEVELING,
	CHAINSAW_MAN,
	AO_NO_EXORCIST,
	YUGIOH,
	INUYASHA,
	FULL_METAL_ALCHEMIST,
	ASSASSINATION_CLASSROOM,
	KONOSUBA,
	SERAPH_OF_THE_END,
	CHIVALRY_OF_A_FAILED_KNIGHT,
	GACHIAKUTA,
	SHAMAN_KING,
	RECORD_OF_RAGNAROK,
	SAINT_SEIYA,
	YU_YU_HAKUSHO,
	TOUGEN_ANKI,
	MIRAI_NIKKI,
	RE_ZERO,
	BAKI,
	SYMPHOGEAR,
	WONDER_EGG_PRIORITY,
	# Player-authored characters (block editor).
	CUSTOM,
	# APPEND-ONLY. Saved data stores universes as ORDINALS, so a new entry goes at the very END even
	# when that puts it out of thematic order - inserting above CUSTOM would renumber it and
	# repoint every authored character's stored universe.
	SWORD_ART_ONLINE,
	CLAYMORE,
	OVERLORD
}

var universe: Universe


static func create(char_name, path_name, port, desc, univ):
	var char_concept = load("res://components/character_concept.gd").new()
	char_concept.character_name = char_name
	char_concept.path_name = path_name
	
	if not DirAccess.dir_exists_absolute("res://assets/images/" + char_name):
		DirAccess.make_dir_absolute("res://assets/images/" + char_name)
		print("Directory created for " + char_name)
	
	char_concept.portrait_texture = port
	char_concept.description = desc
	char_concept.universe = univ
	
	return char_concept
