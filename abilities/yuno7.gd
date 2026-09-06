extends Ability
var base_damage = 65
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 65 piercing damage to one enemy, Bypassing Invulnerability. If this ability is countered, it will automatically cast itself on the following turn. If this ability kills the target, Spirit Dive: Sylph has its duration increased by 2 turns."

func split_desc():
	return [
		"Deals 65 Piercing damage to one enemy, Bypassing Invulnerability",
		["If it kills the target, Spirit Dive: Sylph's duration is increased by 2 turns", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	user.effects.remove_effect("Gale White Bow", EffectType.Type.COST_MOD, user)
	for target in user.targeter.targets:
		var trigger = Effect.trigger_effect(Trigger.always(on_death_trigger), EffectType.Type.ON_DEATH_TRIGGER, 1, "")
		trigger.set_source(self)
		# bypassing=true: this skill bypasses invuln (Piercing damage lands on an invuln target), so the
		# on-death watcher must attach too — otherwise killing an invuln target wouldn't extend Sylph.
		Character.add_hostile_effect(context, user, target, trigger, true)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	

func on_death_trigger(context):
	var yuno = context['effect'].user
	if yuno.has_effect("Spirit Dive: Sylph", EffectType.Type.ABILITY_SWAP, yuno):
		var sylph_effects = yuno.effects.get_all_effects_by_name("Spirit Dive: Sylph", yuno)
		for effect in sylph_effects:
			effect.duration += 4

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 125, 0.9, true)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
