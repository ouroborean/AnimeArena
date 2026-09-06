extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Sogiita Gunha"
	character_colors = [2, 3]
	universe = CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN
	path_name = "gunha"
	description = "Sogiita Gunha, 7th-ranked esper in Academy City. Gunha's power is a mystery to even the most experienced scientists, though he personally believes that with a little guts, anything is possible."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func on_stun_received(effect) -> bool:
	if marked_by("Guts") and has_effect("Guts", EffectType.Type.MARK).mag > 1:
		has_effect("Guts", EffectType.Type.MARK).mag -= 1
		return true
	return false

func expend_guts(args):
	var guts_max = args[0]
	var guts = has_effect("Guts", EffectType.Type.MARK)
	if guts.mag >= guts_max:
		guts.mag -= guts_max
		manually_advance_mission(6, guts_max)
		return guts_max
	else:
		var expended = guts.mag
		guts.mag = 0
		manually_advance_mission(6, expended)
		return expended

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
