extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 damage to target enemy for 3 turns",
		["While active, can be used to deal 10 damage to target enemy and stun their Strategic skills for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if user.marked_by("Courechouse Assault"):
			Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
			var stun = Effect.stun_effect(2, ["Strategic"])
			stun.set_source(self)
			stun.unique_render_id = 5
			Character.add_hostile_effect(context, user, target, stun)
		else:
			Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
			var tick = Effect.damage_effect(10, DamageType.Type.NORMAL, 5)
			tick.set_source(self)
			Character.add_hostile_effect(context, user, target, tick)
			var mark = Effect.mark(5, "Courechouse Assault can be used to deal 10 damage to an enemy and stun their Strategic skills for 1 turn.")
			mark.set_source(self)
			Character.add_allied_effect(context, user, user, mark)
			
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 20)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
