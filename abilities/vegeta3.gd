extends Ability
var base_damage = 40
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 40 piercing damage to one enemy. This skill deals 5 additional damage every time it's used. Uncounterable."

func split_desc():
	return [
		"Deals 40 piercing damage to one enemy, +5 damage every time it's used",
		["Uncounterable", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	var damage_mod = Effect.damage_mod_effect(5, -1, ["Galick Gun"])
	damage_mod.set_source(self)
	damage_mod.stackable = true
	damage_mod.per_stack = true
	damage_mod.display_stacks = true
	Character.add_allied_effect(context, user, user, damage_mod)
	if user.has_effect("Energy Charge", EffectType.Type.COST_MOD, user):
		for mod in user.effects.get_effects_by_type(EffectType.Type.COST_MOD):
			if mod.source.ability_name == "Energy Charge":
				user.effects.erase_effect(mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 70, 0.9)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
