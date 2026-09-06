extends Ability

var base_damage = 20

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to one enemy. This skill gains the following bonus effects, corresponding to the effects that have triggered Scars of Wrath: Received a stun effect -> Stuns the targeted enemy for 1 turn. Received Piercing damage -> Deals Piercing damage. Received Affliction damage -> Applies 5 permanent Affliction damage."

func split_desc():
	return [
		"Deals 20 damage to one enemy",
		["Scars of Wrath (stun triggered): Stuns the target for 1 turn", Color.ORANGE_RED],
		"Scars of Wrath (Piercing triggered): Deals Piercing damage",
		["Scars of Wrath (Affliction triggered): Applies 5 permanent Affliction damage", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var damage_type = DamageType.Type.NORMAL
	var wrath = user.effects.has_effect("Scars of Wrath", EffectType.Type.XANXUS_STORAGE, user)
	var wrath_storage = {}
	if wrath:
		wrath_storage = user.effects.has_effect("Scars of Wrath", EffectType.Type.XANXUS_STORAGE, user).storage
		if wrath_storage["piercing"] > 0:
			damage_type = DamageType.Type.PIERCING
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, damage_type)
		if wrath:
			if wrath_storage["stun"] > 0:
				var stun = Effect.stun_effect(2)
				stun.set_source(self)
				Character.add_hostile_effect(context, user, target, stun)
		if wrath:
			if wrath_storage["affliction"] > 0:
				var aff = Effect.damage_effect(5, DamageType.Type.AFFLICTION, -1, false)
				aff.set_source(self)
				aff.stackable = true
				aff.display_stacks = true
				aff.per_stack = true
				Character.add_hostile_effect(context, user, target, aff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 50, 1.1)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
