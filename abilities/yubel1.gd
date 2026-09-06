extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Taunts target enemy for 1 turn (Invisible). During this time, each time Yubel receives a new Harmful skill, Yubel's allies deal 5 more non-Affliction damage for 1 turn."

func split_desc():
	return [
		"Taunts target enemy for 1 turn (Invisible)",
		["Each time Yubel receives a new Harmful skill while this is active, Yubel's allies deal 5 more non-Affliction damage for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var taunt = Effect.taunt_effect(2, user)
		taunt.set_source(self)
		taunt.invisible = true
		Character.add_hostile_effect(context, user, target, taunt)
	var mark = Effect.trigger_effect(Trigger.always(receive_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 2, "If Yubel receives a Harmful skill, her allies will deal 5 more non-Affliction damage for 1 turn.")
	mark.set_source(self)
	mark.invisible = true
	Character.add_allied_effect(context, user, user, mark)

func receive_trigger(context):
	print("Yubel's S1 Triggered!")
	for ally in user.team.characters:
		if ally != user:
			var mod = Effect.damage_mod_effect(5, 2, [], [], [DamageType.Type.AFFLICTION])
			mod.set_source(self)
			mod.stackable = true
			mod.stack_mag = true
			mod.display_mag = true
			Character.add_allied_effect(context, user, ally, mod)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 50)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
