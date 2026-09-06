extends Character


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Ichibe Hyosube"
	path_name = "ichibe"
	character_colors = [2]
	universe = CharacterConcept.Universe.BLEACH
	description = "Ichibe Hyosube, the monk of Squad Zero and the man who gives everything its true name. With his limitless ink, Ichibe strips his enemies of their meaning, diminishing their power until they are nothing before him."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true


func _process(delta):
	pass
