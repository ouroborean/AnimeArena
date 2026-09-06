extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Kurapika will ignore the next new enemy damage he receives. Invisible. While active, this skill cannot be used and Bokken Smash deals 10 more damage."

func split_desc():
	return [
		"Kurapika ignores the next new enemy damage he receives",
		["While active, Bokken Smash deals 10 more damage", Color.CADET_BLUE],
		["Invisible; cannot be used while active", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var damage_ignore = Effect.ignore_damage_effect(-1)
	damage_ignore.set_source(self)
	damage_ignore.invisible = true
	damage_ignore.full_remove_once_triggered = true
	damage_ignore.ability_only = true
	damage_ignore.wrapup_func = default_counter_timeout
	var damage_mod = Effect.damage_mod_effect(10, -1, ["Bokken Smash"])
	damage_mod.set_source(self)
	damage_mod.invisible = true
	Character.add_allied_effect(context, user, user, damage_ignore)
	Character.add_allied_effect(context, user, user, damage_mod)
		
func extra_usable(user):
	var context = QueryContext.from_game_state(user, user.battle)
	var scarlet = Condition.has_effect(user, "Scarlet Eyes", EffectType.Type.IGNORE_DAMAGE, user)
	
	return not scarlet.satisfied(context)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 20, 1.2)
	
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
