extends Character
class_name Sayaka

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_colors = [1]
	character_name = "Sayaka"
	path_name = "sayaka"
	universe = CharacterConcept.Universe.MADOKA_MAGICA
	description = "Sayaka Miki, Madoka's close friend. A rash, stubborn, but ultimately kind warrior, Sayaka becamse a Magical Girl to protect Madoka from harm, but carries on her duties with a heart full of justice and a resolute wish."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func gain_corruption():
	if not has_effect("Soul Gem: Sayaka", EffectType.Type.MARK):
		return
	effects.has_effect("Soul Gem: Sayaka", EffectType.Type.MARK, self).change_mag(1)
	if effects.has_effect("Soul Gem: Sayaka", EffectType.Type.MARK, self).mag >= 10:
		die(self, moveset.base_abilities[4])

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
