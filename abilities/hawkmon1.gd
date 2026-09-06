extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 15 damage to target enemy and increases their Cooldowns by 1 for 1 turn",
		["Hawkmon gains 1 stack of Hawkmon Digivolve", Color.DIM_GRAY],
		["Will trigger again on the following turn if the target is Silenced", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
		var mark = Effect.mark(-1, func (eff): return "Hawkmon has " + str(eff.stacks) + " stacks of Hawkmon Digivolve.")
		mark.stackable = true
		mark.display_stacks = true
		mark.set_source(user.moveset.base_abilities[2])
		Character.add_allied_effect(context, user, user, mark)
		if target.has_silences():
			var damage = Effect.damage_effect(15, DamageType.Type.NORMAL, 3)
			damage.set_source(self)
			Character.add_hostile_effect(context, user, target, damage)
			var ticking = Effect.trigger_effect(Trigger.always(ticking_trigger), EffectType.Type.TICKING_TRIGGER, 3, "Hawkmon will gain 1 stack of Hawkmon Digivolve.")
			ticking.set_source(self)
			Character.add_hostile_effect(context, user, target, ticking)


func ticking_trigger(context):
	var mark = Effect.mark(-1, func (eff): return "Hawkmon has " + str(eff.stacks) + " stacks of Hawkmon Digivolve.")
	mark.stackable = true
	mark.display_stacks = true
	mark.set_source(user.moveset.base_abilities[2])
	Character.add_allied_effect(context, user, user, mark)

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
