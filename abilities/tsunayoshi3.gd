extends Ability
var base_damage = 30
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 damage to one enemy, marking them permanently. If that enemy is damaged by X-Burner, they take 10 damage and are stunned for 1 turn, consuming the mark."

func split_desc():
	return [
		"Deals 30 damage to one enemy",
		["Marks the enemy permanently", Color.ORANGE_RED],
		["If the marked enemy is damaged by X-Burner, they take 10 damage and are stunned for 1 turn, consuming the mark", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var mark = Effect.trigger_effect(Trigger.always(axle_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "If this character is damaged by X-Burner, they will take 10 more damage and be stunned for 1 turn.")
		mark.set_source(self)
		mark.cleansable = true
		Character.add_allied_effect(context, user, target, mark)

func axle_trigger(context):
	var tsuna = context['effect'].user
	var target = context['target']
	if not context['source'] is Ability or not context['source'].ability_name == "X-Burner":
		return
	
	var stun_eff = Effect.stun_effect(2)
	stun_eff.set_source(self)
	Character.add_hostile_effect(context, tsuna, target, stun_eff)
	Character.resolve_effect_damage(context, context['effect'], target, 10, DamageType.Type.NORMAL)
	target.effects.remove_effect("Burning Axle", EffectType.Type.DAMAGE_RECEIVE_TRIGGER)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 60)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
