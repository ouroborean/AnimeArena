extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Minene Uryuu"
	path_name = "minene"
	universe = CharacterConcept.Universe.MIRAI_NIKKI
	character_colors = []
	description = "The Ninth. A cold-blooded terrorist and bomber who wields the Escape Diary to slip any trap, Minene Uryu answers the Survival Game with grenades, landmines, and a talent for vanishing the instant the odds turn against her."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

# Engine hook: the damage pipeline calls this (via call_unique) after a >=20 hit is absorbed by Escape
# Diary (the mark is reduced 15%/stack, then erased), passing [stacks_consumed]. If 4 or more stacks were
# consumed, reset Escape Route's cooldown so Minene can immediately re-cast it. call_unique passes the args
# array through .call(), so this receives it as a single Array argument.
func on_escape_diary_consumed(args = []):
	var consumed = args[0] if typeof(args) == TYPE_ARRAY and args.size() > 0 else 0
	if consumed < 4:
		return
	if moveset.base_abilities.size() <= 3:
		return
	moveset.base_abilities[3].cooldown_remaining = 0

func is_unlocked(player):
	return "minene_unlock" in player.unlocks

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
