extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Orihime Inoue"
	path_name = "orihime"
	character_colors = [2]
	universe = CharacterConcept.Universe.BLEACH
	description = "Orihime Inoue, comrade of Kurosaki Ichigo. Though not a Shinigami herself, in a time of true crisis Orihime awakened the Shun Shun Rikka, a clade of six heavenly flowers that protect her and those important to her from harm."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
