extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	if "passive" in nbattle and nbattle.passive:
		return
	moveset.base_abilities[0].install_initial_state(self, nbattle)

func initialize(_moveset = false):
	character_name = "Iron Maiden Jeanne"
	character_colors = [2]
	universe = CharacterConcept.Universe.SHAMAN_KING
	path_name = "jeanne"
	description = "Iron Maiden Jeanne, the saintly figurehead of the X-Laws. Entombed within a spiked iron maiden as eternal penance, Jeanne channels the judgment of the ancient god Shamash to cleanse the wicked from the Shaman Fight. Her frail body belies an iron conviction and a willingness to suffer so that evil may be purged."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
