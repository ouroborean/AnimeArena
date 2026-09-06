extends Ability

func describe(user):
	return "Shinoa becomes Invulnerable to non-Strategic skills for 2 turns. During this time, her skills do not consume Four Scythe Child's mark, and marked enemies take 10 Affliction damage per turn."

func split_desc():
	return [
		"Shinoa becomes Invulnerable to non-Strategic skills for 2 turns",
		["Her skills do not consume Four Scythe Child's mark", Color.CADET_BLUE],
		["Marked enemies take 10 Affliction damage per turn", Color.INDIAN_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	# Invulnerable to non-Strategic skills for 2 turns
	var invuln = Effect.invuln_effect(4, [], ["Strategic"])
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	
	# Mark on self to flag that Doji Manifestation is active (prevents mark consumption)
	var manifestation_mark = Effect.mark(4, "Shinoa's skills do not consume Four Scythe Child's mark. Marked enemies take 10 Affliction damage per turn.")
	manifestation_mark.set_source(self)
	Character.add_allied_effect(context, user, user, manifestation_mark)
	
	# End-of-turn trigger: deal 10 Affliction damage to all enemies marked by Four Scythe Child
	var trigger_desc = func (eff):
		return "Enemies marked by Four Scythe Child take 10 Affliction damage per turn."
	var trigger = Trigger.from_condition(Condition.always(), damage_marked_enemies)
	var damage_trigger = Effect.trigger_effect(trigger, EffectType.Type.END_OF_TURN_TRIGGER, 4, trigger_desc)
	damage_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, damage_trigger)

func damage_marked_enemies(context):
	var eff = context['effect']
	var owner = eff.user
	var battle = owner.battle
	var dmg_context = QueryContext.from_game_state(owner, battle)
	for enemy in owner.enemy_team().characters:
		if not enemy.dead and not enemy.banished and enemy.marked_by("Four Scythe Child", owner):
			Character.resolve_damage(dmg_context, enemy, 10, DamageType.Type.AFFLICTION)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	var mod = 0
	# Higher priority if there are marked enemies
	for enemy in context['enemy_team'].characters:
		if not (enemy.dead or enemy.banished) and enemy.marked_by("Four Scythe Child", context['owner']):
			mod += 50
	variations.append([150 + mod + (100 - context['owner'].health.hp), [user, self, [user]]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
