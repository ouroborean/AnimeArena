extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Mine"
	path_name = "mine"
	character_colors = [1]
	universe = CharacterConcept.Universe.AKAME_GA_KILL
	description = "Mine, a member of the assassin group Night Raid. A sharp-tongued genius sniper who wields the Teigu known as Pumpkin, a powerful long-range weapon that becomes more dangerous the more cornered its user is."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
