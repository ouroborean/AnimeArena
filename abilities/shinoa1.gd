extends Ability

func describe(user):
	return "For the next 4 turns, Shinoa can use her skills. During this time, a random unmarked enemy will be marked with Four Scythe Child, and this skill is replaced by Doji Manifestation."

func split_desc():
	return [
		"Each turn, a random unmarked enemy is marked with Four Scythe Child for 4 turns",
		["This skill is replaced by Doji Manifestation", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	# Create end-of-turn trigger that marks a random unmarked enemy each turn
	var trigger_desc = func (eff):
		return "Each turn, a random unmarked enemy will be marked with Four Scythe Child."
	var trigger = Trigger.from_condition(Condition.always(), mark_random_enemy)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.END_OF_TURN_TRIGGER, 8, trigger_desc)
	trigger_eff.set_source(self)
	Character.add_allied_effect(context, user, user, trigger_eff)
	
	# Swap this ability (slot 0) with Doji Manifestation (slot 4)
	var swap = Effect.ability_swap_effect(4, 0, user, 9)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func mark_random_enemy(context):
	var eff = context['effect']
	var owner = eff.user
	var battle = owner.battle
	var unmarked_enemies = []
	for enemy in owner.enemy_team().characters:
		if not enemy.dead and not enemy.banished and not enemy.marked_by("Four Scythe Child", owner):
			unmarked_enemies.append(enemy)
	if unmarked_enemies.size() > 0:
		var random_index = battle.roll(0, unmarked_enemies.size() - 1)
		var target = unmarked_enemies[random_index]
		var mark = Effect.mark(-1, "This character is marked by Four Scythe Child.")
		mark.set_source(eff.source)
		var mark_context = QueryContext.from_game_state(owner, battle)
		Character.add_hostile_effect(mark_context, owner, target, mark)

func extra_usable(user):
	# Can't use while Four Scythe Child's marking effect is already active
	return not user.has_effect("Four Scythe Child", EffectType.Type.END_OF_TURN_TRIGGER, user)

func custom_behavior(context):
	var variations = []
	variations.append([175, [user, self, [user]]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
