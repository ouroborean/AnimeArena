extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Targets one enemy invisibly for 1 turn. The following turn they take 15 damage that Bypasses Invulnerability and Yamamoto gains 1 stack of Asari Ugetsu. If the target used a skill this turn, they receive 10 additional damage and Yamamoto gains 2 stacks of Asari Ugetsu instead."

func split_desc():
	return [
		["Targets one enemy invisibly for 1 turn", Color.ORANGE_RED],
		"The following turn they take 15 damage that Bypasses Invulnerability",
		["Yamamoto gains 1 stack of Asari Ugetsu", Color.CADET_BLUE],
		"If the target used a skill this turn, they take 10 additional damage",
		["Yamamoto gains 2 stacks of Asari Ugetsu instead", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var damage_eff = Effect.trigger_effect(Trigger.always(asari_damage_trigger), EffectType.Type.TICKING_TRIGGER, 3, func (eff): return "This character will take " + str(base_damage + (10* eff.mag)) + " damage.")
		damage_eff.mag = 0
		damage_eff.set_source(self)
		damage_eff.damage_type = DamageType.Type.NORMAL
		damage_eff.invisible = true
		damage_eff.bypassing = true
		var trigger_eff = Effect.trigger_effect(Trigger.always(asari_retaliation_trigger), EffectType.Type.ACTION_USE_TRIGGER, 2, "If this character uses a new skill, Utsuhi Ame will have double effect against them.")
		trigger_eff.set_source(self)
		trigger_eff.invisible = true
		Character.add_hostile_effect(context, user, target, damage_eff)
		Character.add_hostile_effect(context, user, target, trigger_eff)
		

func asari_damage_trigger(context):
	var enemy = context['target']
	var yamamoto = context['owner']
	var asari = context['effect']
	
	Character.resolve_effect_damage(context, asari, enemy, base_damage + (10 * asari.mag), DamageType.Type.NORMAL)
	yamamoto.call_unique("yamamoto", "gain_flames", [asari.mag])
	

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 100)
	
	return variations

func asari_retaliation_trigger(context):
	var attacker = context['owner']
	var yamamoto = context['effect'].user
	
	if attacker.effects.has_effect("Utsuhi Ame", EffectType.Type.TICKING_TRIGGER, yamamoto):
		attacker.effects.has_effect("Utsuhi Ame", EffectType.Type.TICKING_TRIGGER, yamamoto).mag += 1

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
