extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For one turn, each time Misaka takes new damage she will permanently deal 5 more damage with Railgun and apply 5 more Shield with Iron Sand. After Ultra Railgun has been used, this skill grants 2 stacks each time it triggers. After Iron Colossus has been used, this skill affects her entire team."

func split_desc():
	return [
		["For 1 turn, each time Misaka takes new damage she permanently deals 5 more damage with Railgun and applies 5 more Shield with Iron Sand", Color.CADET_BLUE],
		["Grants 2 stacks per trigger after Ultra Railgun has been used", Color.CADET_BLUE],
		["Affects her entire team after Iron Colossus has been used", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var damage_receive_trigger = Effect.trigger_effect(Trigger.always(overcharge_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, 2, "If this character takes new damage, Misaka will permanently deal 5 more damage with Railgun and apply 5 more Shield with Iron Sand.")
		damage_receive_trigger.set_source(self)
		
		Character.add_allied_effect(context, user, target, damage_receive_trigger)

func overcharge_trigger(context):
	var misaka = user
	
	var count = 1
	if user.marked_by("Ultra Railgun"):
		count = 2
	for i in range(count):
		misaka.manually_advance_mission(8, 1)
		var damage_boost = Effect.damage_mod_effect(5, -1, ["Railgun"])
		damage_boost.set_source(self)
		damage_boost.stackable = true
		damage_boost.per_stack = true
		damage_boost.display_stacks = true
		damage_boost.unique_render_id = 5
		
		var shield_boost = Effect.empty(-1, "Misaka will apply 5 more Shield with Iron Sand.")
		shield_boost.set_source(self)
		shield_boost.mag = 5
		shield_boost.stackable = true
		shield_boost.per_stack = true
		shield_boost.display_stacks = true
		shield_boost.unique_render_id = 5
		
		Character.add_allied_effect(context, misaka, misaka, damage_boost)
		Character.add_allied_effect(context, misaka, misaka, shield_boost)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25, 0.5)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	if user.marked_by("Iron Colossus"):
		default_allied_target_function(user, battle)
	else:
		default_self_target_function(user, battle)
