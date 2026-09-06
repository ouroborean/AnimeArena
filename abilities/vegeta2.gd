extends Ability
var base_damage = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Vegeta gains one stack of Ki Blast, then uses Ki Blast on the enemy team."

func split_desc():
	return [
		"Uses Ki Blast on the enemy team",
		["Vegeta gains one stack of Ki Blast", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var boost_stacks = 1
		if user.has_effect("Ki Blast", EffectType.Type.DAMAGE_MOD, user):
			boost_stacks += user.has_effect("Ki Blast", EffectType.Type.DAMAGE_MOD, user).stack_count()
		var weakness = Effect.damage_mod_effect(-5 - (5 * boost_stacks), 2, [], [], [DamageType.Type.AFFLICTION])
		weakness.set_source(user.moveset.base_abilities[0])
		Character.add_hostile_effect(context, user, target, weakness)
	if user.has_effect("Ki Blast", EffectType.Type.DAMAGE_MOD, user):
		for mod in user.effects.get_effects_by_type(EffectType.Type.DAMAGE_MOD):
			if mod.source.ability_name == "Ki Blast":
				user.effects.erase_effect(mod)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 30, 1.2)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
