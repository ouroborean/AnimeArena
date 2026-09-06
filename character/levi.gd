extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Levi Ackerman"
	path_name = "levi"
	universe = CharacterConcept.Universe.ATTACK_ON_TITAN
	character_colors = [0, 3]
	description = "Humanity's Strongest Soldier. Captain of the Survey Corps' Special Operations Squad, Levi cuts down Titans with unmatched speed and precision on his ODM gear - relentless, disciplined, and never willing to let a comrade's death go unanswered."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
