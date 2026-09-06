extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sukuna deals 10 Affliction damage to the ally marked by Sealed King. For 1 turn, that enemy receives triple effect from Sealed King's damage boost, and they ignore non-damage effects. Only usable while Sukuna is stunned by Sealed King and the marked ally is stunned by a different effect."

func split_desc():
	return [
		"Target ally gains +5 non-Affliction damage and ignores negative non-damage effects for 1 turn",
		"If that ally has 40 HP or less, they are instead executed and Sukuna activates Malevolent Shrine",
		"Requires Sealed King"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target.health.hp <= 40:
			target.execute_attempt(40, user, self)
			for character in user.battle.all_characters():
				if not character == user:
					character.execute_attempt(5, user, self)
			var tick = Effect.trigger_effect(Trigger.always(shrine_trigger), EffectType.Type.TICKING_TRIGGER,  -1, "")
			tick.set_source(user.moveset.abilities[0])
			tick.description = func (eff): return "Sukuna will execute any other character with " + str(eff.mag) + " or less HP."
			tick.display_mag = true
			tick.mag = 5
			var mark = Effect.mark(-1, "Sukuna can use Fire Arrow and Cleave and Dismantle.")
			mark.set_source(user.moveset.abilities[0])
			mark.cleansable = false
			Character.add_allied_effect(context, user, user, tick)
			Character.add_allied_effect(context, user, user, mark)
			if user.marked_by("Sealed King"):
				var seal = user.has_effect("Sealed King", EffectType.Type.MARK)
				user.effects.erase_effect(seal)
		else:
			var damage_mod = Effect.damage_mod_effect(5, 1, [], [], [DamageType.Type.AFFLICTION])
			damage_mod.set_source(self)
			Character.add_allied_effect(context, user, target, damage_mod)
			var hostile_ignore = Effect.ignore_non_damage_effect(3)
			hostile_ignore.set_source(self)
			Character.add_allied_effect(context, user, target, hostile_ignore)


func shrine_trigger(context):
	var shrine = context['effect']
	shrine.mag += 5
	for character in user.battle.all_characters():
		if not character == user:
			character.execute_attempt(shrine.mag, user, self)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.marked_by("Sealed King")
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_heal(context, 25, 2.0)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
