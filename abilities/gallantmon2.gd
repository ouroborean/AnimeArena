extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Gallantmon deals 20 Piercing damage to one enemy. For 1 turn, Shield of the Just will reflect instead of counter. If this skill is countered, it will be replaced by Shield of the Just for 1 turn."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy",
		["Swaps to Shield of the Just for 1 turn if countered", Color.AQUAMARINE],
		"Shield of the Just will fully Reflect next turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var lightning_charged = user.marked_by("Gallant Guard", user)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		if lightning_charged:
			user.manually_advance_mission(9, 1)
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	
	var mark = Effect.mark(3, "Gallant Guard will reflect instead of counter.")
	mark.invisible = true
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	
	variations += behavior_single_target_damage(context, 50, 1.1)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
