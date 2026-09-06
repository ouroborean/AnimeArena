extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Killua deals 15 piercing damage to one enemy and gives them one stack of Decapitation. The following 2 turns, this skill and Heart Ripper will deal 10 additional damage."

func split_desc():
	return [
		"Deals 15 piercing damage to target enemy",
		"Applies 1 stack of Decapitation",
		["For 2 turns, this skill and Heart Ripper deal 10 more damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var mark_desc = func (eff):
			return "This character has " + str(eff.stack_count()) + " stacks of Decapitation."
		var mark = Effect.mark(-1, mark_desc)
		mark.stackable = true
		mark.display_stacks = true
		mark.set_source(user.moveset.base_abilities[2])
		Character.add_hostile_effect(context, user, target, mark)
	
	var damage_mod = Effect.damage_mod_effect(10, 5, ["Claws Assassination", "Heart Ripper"])
	damage_mod.set_source(self)
	Character.add_allied_effect(context, user, user, damage_mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 150, 0.7)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
