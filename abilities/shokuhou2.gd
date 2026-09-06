extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 1 turn, if Shokuhou or target ally would be Stunned, they are fully cleansed of enemy effects",
		["Shokuhou uses Mental Out on the enemy that triggers this effect if it is not currently on cooldown", Color.ORANGE_RED],		
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var duration = 2
	if user.marked_by("Exterior"):
		duration += 4
	
	for target in user.targeter.targets:
		var trigger = Effect.trigger_effect(Trigger.always(stun_trigger), EffectType.Type.STUN_RECEIVED_TRIGGER, duration, "If this character is Stunned, they will be fully Cleansed of enemy effects.")
		trigger.set_source(self)
		trigger.invisible = true
		trigger.wrapup_func = default_counter_timeout
		Character.add_allied_effect(context, user, target, trigger)
	
	
	user.effects.full_remove_effect_by_name("Exterior")

func stun_trigger(context):
	var shokuhou = user
	var eff = context['effect']
	var enemy = context['owner']
	if shokuhou in enemy.team.characters:
		return
	user.manually_advance_mission(8, 1)
	eff.target.effects.full_remove_effect_by_name("Plan to Lose")
	eff.target.effects.cleanse_all_enemy_effects(eff.target)
	
	if user.moveset.base_abilities[0].cooldown_remaining != 0:
		return
	var stun = Effect.stun_effect(3)
	stun.set_source(user.moveset.base_abilities[0])
	Character.add_hostile_effect(context, user, enemy, stun)
	for i in range(4):
		var copy = Effect.copy_effect(enemy.moveset.get_active_abilities(enemy)[i], i, 3, user)
		copy.system = true
		copy.set_source(user.moveset.base_abilities[0])
		Character.add_allied_effect(context, user, user, copy)
	


func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
