extends Ability

# Stone Pillar. 20 damage. After it is used, its cost becomes 1 Random until Toph uses a different
# skill (a COST_CHANGE cleared by an ACTION_USE_TRIGGER watcher). While Toph herself carries Metal
# Armor, her skills deal 5 more damage (extra_damage_calc, shared idiom with Earthen Shackles).

func describe(user):
	return "Deals 20 damage to target enemy. After being used, Stone Pillar costs 1 Random until Toph uses a different skill."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["After being used, Stone Pillar costs 1 Random until Toph uses a different skill", Color.AQUAMARINE],
		["While Toph has Metal Armor, her skills deal 5 more damage", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
		if target.marked_by("Earthen Shackles", user):
			user.manually_advance_mission(7, 1)
			target.lose_energy(user)
	# Repeated use costs Random instead of Green, until a different skill is used.
	var cc = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, -1, ["Stone Pillar"])
	cc.set_source(self)
	cc.refresh = true
	Character.add_allied_effect(context, user, user, cc)
	if user.has_effect("Stone Pillar", EffectType.Type.ACTION_USE_TRIGGER, user) == null:
		var watcher = Effect.trigger_effect(Trigger.always(reset_cost), EffectType.Type.ACTION_USE_TRIGGER, -1, "Using a skill other than Stone Pillar returns its cost to normal.")
		watcher.set_source(self)
		Character.add_allied_effect(context, user, user, watcher)

func reset_cost(context):
	var toph = context['owner']
	if toph.used_ability != null and toph.used_ability.ability_name == "Stone Pillar":
		return
	toph.effects.remove_effect("Stone Pillar", EffectType.Type.COST_CHANGE, toph)

func extra_damage_calc(damager, target, damage):
	if damager.has_effect("Metal Armor", EffectType.Type.SHIELD, damager):
		return damage + 5
	return damage

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
