extends Character
class_name Bakugo


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset=false):

	character_colors = [3]
	character_name = "Bakugo Katsuki"
	path_name = "bakugo"
	universe = CharacterConcept.Universe.MY_HERO_ACADEMIA
	description = "One of the best UA rookies from the class 1-A. Bakugou has a short and aggressive temperament. His inviduality allows him to expel nitroglycerin from the palms and create forms of explosion. Besides this factor, Bakugou has a keen instinct and intelligence above the others."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
