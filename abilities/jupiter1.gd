extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 20 damage to target enemy and stuns their Helpful skills for 1 turn",
		["+5 damage per stack of Thunder Antenna on Jupiter", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
		var stun = Effect.stun_effect(2, ["Helpful"])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
	var damage_boost = Effect.damage_mod_effect(5, -1, ["Supreme Thunder"])
	damage_boost.set_source(user.moveset.base_abilities[4])
	damage_boost.stackable = true
	damage_boost.stack_mag = true
	damage_boost.display_stacks = true
	Character.add_allied_effect(context, user, user, damage_boost)
	user.manually_advance_mission(6, 1)
	
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
