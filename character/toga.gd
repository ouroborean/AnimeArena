extends Character
class_name Toga


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = []
	extra_button_label = "Disguise"
	character_name = "Himiko Toga"
	universe = CharacterConcept.Universe.MY_HERO_ACADEMIA
	path_name = "toga"
	description = "Himiko Toga is a cheerful girl with a sadistic streak, boasting membership in multiple powerful Villain groups. Once her attacks have siphoned blood from a victim, she can use her Quirk to Transform into them, allowing for easy infiltration and surprise attacks."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "toga_unlock" in player.unlocks

# (The disguise-picker panel override lived here for the retired desktop client
# and loaded res://ui/toga_disguise_panel.tscn. The web client renders its own
# disguise UI in app.js, so the override is gone with ui/.)

func _process(delta):
	pass
