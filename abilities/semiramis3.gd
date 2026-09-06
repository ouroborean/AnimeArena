extends Ability
var base_damage = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Semiramis deals 5 permanent Affliction damage to all enemies. Upon use, all active enemy Shield, Invulnerability, or heal-over-time effects are converted into additional stacks of 5 permanent Affliction damage. This skill Bypasses."

func split_desc():
	return [
		"Deals 5 permanent Affliction damage to all enemies",
		["Converts all active enemy Shield, Invulnerability, or heal-over-time effects into additional stacks of 5 permanent Affliction damage", Color.ORANGE_RED],
		["Bypasses", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.AFFLICTION, -1, false)
		damage_eff.stackable = true
		damage_eff.per_stack = true
		damage_eff.remove_on_death = false
		damage_eff.display_stacks = true
		damage_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_eff, true)
		var stack_count = 0
		for effect in target.effects.get_effects_by_type(EffectType.Type.SHIELD):
			stack_count += 1
		target.shatter_shields(user)
		for effect in target.effects.get_effects_by_type(EffectType.Type.INVULN):
			stack_count += 1
			if effect != null:
				target.effects.remove_effect(effect.effect_name(), EffectType.Type.INVULN)
		for effect in target.effects.get_effects_by_type(EffectType.Type.HEALING):
			stack_count += 1
			if effect != null:
				target.effects.remove_effect(effect.effect_name(), EffectType.Type.HEALING)
		Character.resolve_damage(context, target, base_damage + (stack_count * 5), DamageType.Type.AFFLICTION)
		for i in stack_count:
			var poison_eff = Effect.damage_effect(5, DamageType.Type.AFFLICTION, -1, false)
			poison_eff.set_source(self)
			poison_eff.stackable = true
			poison_eff.display_stacks = true
			poison_eff.per_stack = true
			poison_eff.remove_on_death = false
			Character.add_hostile_effect(context, user, target, poison_eff, true)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 60, 1.4, true)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
