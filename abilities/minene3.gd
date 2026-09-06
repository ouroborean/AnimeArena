extends Ability

# Master of Disguise. For 1 turn Minene redirects 50% of the damage she takes to target enemy. A companion
# invisible DAMAGE_RECEIVE_TRIGGER flags whether Minene was hit during the window; on the redirect's expiry,
# if she took NO damage, she is rewarded with an Escape Diary stack (the disguise held).

# Per-window flag: set true when Minene takes any damage while the disguise is up. Reset at cast start and
# at wrapup. Safe as a single member var because the effect (dur 2) always expires before the cd (2) lets
# this recast, so windows never overlap.
var disguise_hit = false

func describe(user):
	return "For 1 turn, 50% of the damage Minene takes is redirected to target enemy. If Minene takes no damage during this time, she gains a stack of Escape Diary."

func split_desc():
	return [
		["For 1 turn, 50% of the damage Minene takes is redirected to the target enemy", Color.CADET_BLUE],
		["If Minene takes no damage during this time, she gains a stack of Escape Diary", Color.CADET_BLUE]
	]

func execute(user, battle):
	disguise_hit = false
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# DAMAGE_REDIRECT sits on the DAMAGED character (Minene); character_target = the enemy who receives
		# the redirected slice (check_damage_redirect uses redirect.character_target).
		var redirect = Effect.redirect_effect(0.5, target, 2)
		redirect.set_source(self)
		redirect.invisible = true
		redirect.wrapup_func = disguise_wrapup
		Character.add_allied_effect(context, user, user, redirect)
		var watch = Effect.trigger_effect(Trigger.always(disguise_damage_watch), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, 2, "Tracks whether Minene is hit while disguised.")
		watch.set_source(self)
		watch.invisible = true
		Character.add_allied_effect(context, user, user, watch)

func disguise_damage_watch(context):
	disguise_hit = true

func disguise_wrapup(context):
	var minene = context['effect'].user
	if minene != null and is_instance_valid(minene) and not (minene.dead or minene.banished):
		if not disguise_hit:
			minene.moveset.base_abilities[4].grant_diary_stack(minene, 1)
	disguise_hit = false

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 0)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
