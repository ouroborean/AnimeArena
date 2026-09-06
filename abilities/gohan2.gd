extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 4 turns, Gohan will permanently deal 5 more damage each time his allies take damage, up to 10 stacks",
		["If this effect is triggered, Gohan's Harmful skills cost 1 less Random energy until the next time one is used", Color.CADET_BLUE],
		["If one of Gohan's allies is dead when activated, this skill is replaced by Father-Son Kamehameha for the duration", Color.AQUA]
	]	

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var swapped = false
	for character in user.team.characters:
		if character.dead and not swapped:
			var swap = Effect.ability_swap_effect(4, 1, user, 9)
			swap.set_source(self)
			Character.add_allied_effect(context, user, user, swap)
			swapped = true
		if not character.dead and character != user:
			var damage_trigger = Effect.trigger_effect(Trigger.always(trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, 8, "If this character takes damage, Gohan will permanently deal 5 more damage and his skills will cost 1 less Random until the next time one is used.")
			damage_trigger.set_source(self)
			damage_trigger.system = true
			Character.add_allied_effect(context, user, character, damage_trigger)
	var mark = Effect.mark(8, "If either of Gohan's allies are damaged, he will permanently deal 5 more damage and his harmful skills will cost 1 less Random energy until the next time one is used.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

func trigger(context):
	# The +5 damage stack caps at 10 — once there, further ally-damage triggers grant no more
	# damage (the cost-reduction refresh below still fires).
	var existing = user.has_effect("Saiyan Rage", EffectType.Type.DAMAGE_MOD)
	if existing == null or existing.stacks < 10:
		var damage_mod = Effect.damage_mod_effect(5, -1, ["Merciless Punch", "Brutal Kick", "Father-Son Kamehameha"])
		damage_mod.set_source(self)
		damage_mod.stackable = true
		damage_mod.stack_mag = true
		damage_mod.unique_render_id = 1
		damage_mod.display_stacks = true
		user.manually_advance_mission(9, 1)
		Character.add_allied_effect(context, user, user, damage_mod)
	if not user.has_effect("Saiyan Rage", EffectType.Type.COST_MOD):
		var cost_mod = Effect.cost_mod_effect(-1, -1, Energy.Type.RANDOM, ["Merciless Punch", "Brutal Kick", "Father-Son Kamehameha"])
		cost_mod.set_source(self)
		cost_mod.unique_render_id = 2
		Character.add_allied_effect(context, user, user, cost_mod)
		var use_trigger = Effect.trigger_effect(Trigger.always(harmful_use_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, -1, "If Gohan uses a new Harmful skill, this cost modification will end.")
		use_trigger.set_source(self)
		Character.add_allied_effect(context, user, user, use_trigger)
	
func harmful_use_trigger(context):
	user.effects.remove_effect("Saiyan Rage", EffectType.Type.COST_MOD)
	user.effects.remove_effect("Saiyan Rage", EffectType.Type.HARMFUL_USE_TRIGGER)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 60)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
