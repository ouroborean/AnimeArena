extends Character
class_name Madoka


# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [2]
	character_name = "Madoka Kaname"
	path_name = "madoka"
	universe = CharacterConcept.Universe.MADOKA_MAGICA
	description = "Madoka Kaname, the strongest magical girl. A girl with no wish, caught at the conflux of a destiny so incredible that it transcends time and space. As a magical girl, Madoka fights with her enchanted bow and arrow, and does everything she can to keep her friends safe from harm."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func gain_corruption():
	var passive = effects.has_effect("Soul Gem: Madoka", EffectType.Type.MARK, self)
	# The gem is death-cleansed while the passive machinery is not, so a revived Madoka can be asked
	# for corruption with no gem on her. Mami and Sayaka have always guarded this; here it was only
	# ever reachable through a Shield break, and a per-turn ticker would hit it EVERY turn instead.
	if not passive:
		return
	passive.change_mag(1)
	if passive.mag >= 12:
		die(self, moveset.base_abilities[4])
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
