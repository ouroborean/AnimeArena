extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Fumikage Tokoyami"
	path_name = "tokoyami"
	character_colors = [3]
	universe = CharacterConcept.Universe.MY_HERO_ACADEMIA
	description = "Fumikage Tokoyami, the Jet-Black Hero: Tsukuyomi. His Quirk, Dark Shadow, allows him to manifest a sentient shadow with terrifying strength. As darkness gathers, Dark Shadow's power grows exponentially."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func on_control_effect_received(effect):
	var mark = has_effect("Black Abyss", EffectType.Type.MARK)
	if mark and mark.mag > 0:
		mark.mag -= 1
		if mark.mag < 3:
			effects.remove_effect("Black Abyss", EffectType.Type.TARGET_CHANGE)

func is_unlocked(player):
	return "tokoyami_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
