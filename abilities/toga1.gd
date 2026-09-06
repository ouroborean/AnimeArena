extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Toga deals 15 piercing damage to target enemy and gains one stack of Twisted Love."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy",
		["Toga gains 1 stack of Twisted Love", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	if user.has_effect("Quirk: Transform", EffectType.Type.DISGUISE):
		user.manually_advance_mission(8, 1)

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	var mark = Effect.mark(-1, func (eff): return "Toga has " + str(eff.stack_count()) + " stacks of Twisted Love.")
	mark.set_source(user.moveset.base_abilities[3])
	mark.invisible = true
	mark.stackable = true
	mark.display_stacks = true
	Character.add_allied_effect(context, user, user, mark)
	user.manually_advance_mission(6, 1)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
