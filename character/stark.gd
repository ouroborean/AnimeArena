extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)
	# Axe Smash's slot is contested by two condition-driven swap-ins:
	#   Lightning Strike (base_abilities[6]) while ANY enemy is Stunned  -- takes priority
	#   Cleaving Light   (base_abilities[5]) while ANY enemy is at <= 30 HP
	# Evaluating both in ONE place is what makes the priority deterministic: get_active_abilities
	# resolves swaps in storage order, so leaving two live would make the winner depend on which was
	# applied first. Exactly one swap effect is ever installed. Toji's X-Slash is the same shape.
	#
	# Re-checked on a permanent invisible+system START_OF_TURN trigger (fires for both sides each
	# turn) AND after any damage Stark deals, so a swing that drops an enemy into execute range or a
	# stun landing mid-turn updates the slot immediately rather than a turn late.
	var turn = Effect.trigger_effect(Trigger.always(stark_reevaluate), EffectType.Type.START_OF_TURN_TRIGGER, -1, "")
	turn.set_source(moveset.base_abilities[5])
	turn.invisible = true
	# system AND remove_on_death=false, or the death cleanse takes both triggers with him and a
	# revived Stark never re-evaluates the slot again (startup() only runs once per match).
	turn.system = true
	turn.remove_on_death = false
	Character.add_allied_effect(context, self, self, turn)
	var dealt = Effect.trigger_effect(Trigger.always(stark_reevaluate), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, "")
	dealt.set_source(moveset.base_abilities[5])
	dealt.invisible = true
	dealt.system = true
	dealt.remove_on_death = false
	Character.add_allied_effect(context, self, self, dealt)
	stark_evaluate_swaps(context)

func initialize(_moveset = false):
	character_name = "Stark"
	path_name = "stark"
	universe = CharacterConcept.Universe.FRIEREN
	character_colors = [0]
	description = "Stark, the warrior who never stopped being afraid. He shakes before every fight and steps in front of his friends anyway - taking the blows meant for them, and swinging hardest at the moment his nerve should have failed."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass

# --- Axe Smash slot contest -------------------------------------------------------------

func _living_enemies() -> Array:
	var out := []
	if battle == null or not is_instance_valid(battle):
		return out
	for c in battle.all_characters():
		if c in team.characters:
			continue
		if c.dead or c.banished:
			continue
		out.append(c)
	return out

# Which hidden ability, if any, should be holding slot 1 right now. Lightning Strike wins ties.
func _wanted_swap_index() -> int:
	var axe = moveset.base_abilities[1]
	for foe in _living_enemies():
		if foe.is_stunned(axe):
			return 6
	for foe in _living_enemies():
		if foe.health.hp <= 30:
			return 5
	return -1

func stark_evaluate_swaps(context):
	if dead or banished or moveset == null:
		return
	var wanted := _wanted_swap_index()
	var live_swaps = effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP)
	var current := -1
	var keep = null
	for swap in live_swaps:
		if not swap.source in moveset.base_abilities:
			continue
		# mag is Vector2(swap_in_slot, replaced_slot); only this contest owns slot 1.
		if int(swap.mag.y) != 1:
			continue
		if int(swap.mag.x) == wanted and keep == null:
			current = int(swap.mag.x)
			keep = swap
		else:
			# Anything else claiming the slot loses — including a duplicate of the winner.
			effects.erase_effect(swap)
	if wanted == -1 or current == wanted:
		return
	# set_source is load-bearing: apply_effect drops any ABILITY_SWAP whose source is not in the
	# applier's base_abilities, and get_active_abilities skips one whose source is not in the
	# owner's. Sourcing it to the ability being swapped IN satisfies both.
	var swap_eff = Effect.ability_swap_effect(wanted, 1, self, -1)
	swap_eff.set_source(moveset.base_abilities[wanted])
	Character.add_allied_effect(context, self, self, swap_eff)

func stark_reevaluate(context):
	if dead or banished:
		return
	if battle == null or not is_instance_valid(battle):
		return
	stark_evaluate_swaps(QueryContext.from_game_state(self, battle))
