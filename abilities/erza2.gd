extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 15 piercing damage to target enemy on the first turn and activates Heaven's Wheel Armor. The following turn, all enemies take 10 Piercing damage",
		["If Heaven's Wheel Armor is already active, deals 10 Piercing damage to target enemy and Stuns and Shatters them for 1 turn (Bypassing)", Color.CADET_BLUE],
		["Heaven's Wheel Armor: Erza ignores Affliction damage and Circle Blade costs 1 Random", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var equipped = user.call_unique("erza", "wearing_armor", ["Heaven's Wheel Armor"])
	if user.call_unique("erza", "wearing_armor", ["Nakagami's Armor"]):
		var cooldown_mod = Effect.cooldown_mod(-1, -1, ["Circle Blade"])
		cooldown_mod.set_source(self)
		cooldown_mod.stackable = true
		cooldown_mod.stack_mag = true
		cooldown_mod.display_stacks = true
		cooldown_mod.unique_render_id = 5
		Character.add_allied_effect(context, user, user, cooldown_mod)
	if not equipped:
		user.call_unique("erza", "requip_armor", ["heavens_wheel"])
	for target in user.targeter.targets:
		if not equipped:
			Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
			var tick = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, 3, "Erza will deal 10 Piercing damage to all enemies")
			tick.set_source(self)
			tick.damage_type = DamageType.Type.PIERCING
			Character.add_allied_effect(context, user, user, tick)
		else:
			Character.resolve_damage(context, target, 10, DamageType.Type.PIERCING)
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)
			var shatter = Effect.def_negate(2)
			shatter.set_source(self)
			Character.add_hostile_effect(context, user, target, shatter)

func tick_trigger(context):
	for character in context.enemy_team.characters:
		var invuln = Condition.is_invuln(character, self)
		if not invuln.satisfied(context) and not (character.dead or character.banished):
			Character.resolve_effect_damage(context, context['effect'], character, 10, DamageType.Type.PIERCING)

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var bypassing = false
	if user.call_unique("erza", "wearing_armor", ["Heaven's Wheel Armor"]):
		bypassing = true
	default_hostile_target_function(user, battle, bypassing)
	
