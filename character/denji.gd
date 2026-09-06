extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Denji"
	character_colors = [2, 3]
	universe = CharacterConcept.Universe.CHAINSAW_MAN
	path_name = "denji"
	description = "A dirt-poor devil hunter who fused with his pet devil Pochita to become the Chainsaw Devil. Reckless, blunt, and driven by the simplest of wants, Denji tears through enemies with roaring chainsaws, bleeding them dry and feeding on the wounds he opens."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

# Starter character: no is_unlocked override — the CharacterConcept default
# (always owned) applies, matching naruto and the rest of starter_squads().

func _process(delta):
	pass
