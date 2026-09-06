extends Character
class_name Mash


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1]
	character_name = "Mash Kyrielight"
	path_name = "mash"
	universe = CharacterConcept.Universe.FATE
	description = "Mash Kyrielight is a Demi-Servant human fused with the Heroic Spirit Galahad. Created artifically to be a vessel for a Heroic Spirit's soul, she wields a Shield made from the Round Table to protect her Master."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func break_vow(args):
	var context = args[0]
	var effect = context['effect']
	for character in team.characters:
		character.effects.full_remove_effect_by_name("A Knight That Protects", self)
	var swap_eff = Effect.ability_swap_effect(4, 0, self, 2)
	swap_eff.set_source(moveset.base_abilities[3])
	Character.add_allied_effect(context, self, self, swap_eff)

	# The vow ending also discounts Around Round Crash by 1 Random for 1 turn
	# (dur 2). Sourced from A Knight That Protects like the swap above, and named
	# by ability so it cannot leak onto the rest of the kit. The full_remove above
	# has already cleared the old vow effects, so nothing collides with this.
	var crash_discount = Effect.cost_mod_effect(-1, 2, Energy.Type.RANDOM, ["Around Round Crash"])
	crash_discount.set_source(moveset.base_abilities[3])
	Character.add_allied_effect(context, self, self, crash_discount)

	# effect.breaker is null when the vow ends without an attributable breaker
	# (e.g. the Shield was cleansed rather than damaged) — skip the punish-mark
	# then, but the vow itself still breaks (swap-back + ally invuln removal above).
	if effect.breaker != null:
		var mark = Effect.mark(2, "Around Round Axe will stun this character for 1 turn and deal 5 more damage to them.")
		mark.set_source(moveset.base_abilities[3])
		Character.add_hostile_effect(context, self, effect.breaker, mark)

func is_unlocked(player):
	return "mash_unlock" in player.unlocks

func _process(delta):
	pass
