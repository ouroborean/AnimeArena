extends Ability

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 10 damage to target enemy and Taunts them for 2 turns. All other enemies are Blinded for the duration. Channeled",
		["Lasts 1 more turn for each stack of Venus Burning Love consumed by this skill's use", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = make_context(battle)

	# Read stack count for duration bonus before dealing damage
	var bonus_duration = 0
	var burning_love = user.has_effect("Venus Burning Love", EffectType.Type.DAMAGE_MOD)
	if burning_love:
		bonus_duration = burning_love.stacks
		
	# Duration: 2 turns base + 1 per stack consumed
	# In the effect system, dur 3 = lasts ~2 turns (accounts for tick at end of current turn)
	var total_dur = 3 + (bonus_duration * 2)
	
	var cancels = []

	# Deal damage to main target (base 10, boosted by damage_mod stacks still active)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		var damage_eff = Effect.damage_effect(bonus_duration * 5, DamageType.Type.NORMAL, total_dur)
		damage_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_eff)
		var taunt = Effect.taunt_effect(total_dur, user)
		taunt.set_source(self)
		cancels.append(taunt)
		Character.add_hostile_effect(context, user, target, taunt)

	# Consume stacks AFTER damage is dealt so the boost applies
	if burning_love:
		Character.resolve_healing(context, user, 10 + 5 * burning_love.stack_count())
		user.effects.erase_effect(burning_love)

	# Blind all OTHER enemies
	for enemy in context['enemy_team'].characters:
		if enemy not in user.targeter.targets and not (enemy.dead or enemy.banished):
			var blind = Effect.blind_effect(total_dur)
			blind.set_source(self)
			cancels.append(blind)
			Character.add_hostile_effect(context, user, enemy, blind)

	# Channel cancel effect on Venus
	var cancel_eff = Effect.channel_cancel(total_dur, ability_name, cancels)
	cancel_eff.set_source(self)
	Character.add_allied_effect(context, user, user, cancel_eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	var stacks = 0
	var burning_love = user.has_effect("Venus Burning Love", EffectType.Type.DAMAGE_MOD)
	if burning_love:
		stacks = burning_love.stacks
	return behavior_single_target_hostile(context, 40 + (stacks * 15))

func target(user, battle):
	default_hostile_target_function(user, battle)
