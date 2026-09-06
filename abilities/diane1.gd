extends Ability
var base_damage = 30
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 damage to one enemy on the following turn. This damage Bypasses and if it hits an invulnerable target, they are stunned for 1 turn. The target of this skill is invisible, and it cannot be used while active."

func split_desc():
	return [
		"Deals 30 damage to target enemy next turn (Bypassing)",
		"If this damages an Invulnerable target, they are stunned for 1 turn",
		"The target of this skill is invisible",
		"Cannot be used while active"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var duration = 3
		var mod_damage = base_damage
		if user.has_effect("Heavy Metal", EffectType.Type.SHIELD, user):
			duration += 2
			mod_damage += 20
		var ticking_trigger = Effect.trigger_effect(Trigger.always(catastrophe_trigger), EffectType.Type.TICKING_TRIGGER, duration, func (eff): return "When this effect ends, Diane will deal " + str(eff.mag) + " damage to a targeted enemy.")
		ticking_trigger.mag = mod_damage
		ticking_trigger.ability_targets = target
		ticking_trigger.set_source(self)
		ticking_trigger.damage_type = DamageType.Type.NORMAL
		Character.add_allied_effect(context, user, user, ticking_trigger)

func catastrophe_trigger(context):
	if context['effect'].duration == 1:
		Character.resolve_effect_damage(context, context['effect'], context['effect'].ability_targets, context['effect'].mag, DamageType.Type.NORMAL)
		if context['effect'].ability_targets.is_invuln():
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, context['owner'], context['effect'].ability_targets, stun, true)
			context['owner'].effects.erase_effect(context['effect'])
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.has_effect("Mother Catastrophe", EffectType.Type.TICKING_TRIGGER, user) == null

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 50, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
