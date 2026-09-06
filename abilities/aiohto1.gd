extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Target enemy ignores Shield effects until the end of the turn, then Ai deals 15 Piercing damage to them. For 1 turn, if Ai's allies use a new skill on that enemy, they gain 10 Shield."

func split_desc():
	return [
		"Target enemy ignores Shield effects, then takes 15 Piercing damage",
		["For 1 turn, if an ally uses a new skill on that enemy, that ally gains 10 Shield", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# The enemy's Shield stops protecting them, so the Piercing lands on HP. Apply BEFORE the damage.
		var ignore_shield = Effect.ignore_effect_effect(2, EffectType.Type.SHIELD)
		ignore_shield.set_source(self)
		Character.add_hostile_effect(context, user, target, ignore_shield)
		Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
		# For 1 turn, an ally who uses a new skill on this enemy gains 10 Shield.
		var watcher = Effect.trigger_effect(Trigger.always(ally_shield_trigger), EffectType.Type.ACTION_RECEIVE_TRIGGER, 2, "If an ally of Ai uses a new skill on this character, that ally gains 10 Shield.")
		watcher.set_source(self)
		Character.add_hostile_effect(context, user, target, watcher)
		# Reloads Now I'm Mad!: its Green cost becomes Random for 2 turns (read by ai2.cost()).
		var reload = Effect.mark(4, "Now I'm Mad!'s Green cost is changed to Random.")
		reload.set_source(self)
		Character.add_allied_effect(context, user, user, reload)

func ally_shield_trigger(context):
	var actor = context['owner']       # who used a new skill on the marked enemy
	var ai = context['effect'].user
	if actor == null or ai == null:
		return
	if not (actor in ai.team.characters):   # only Ai's allies (her team, incl. herself)
		return
	if actor.dead or actor.banished:
		return
	var shield = Effect.shield_effect(10, 2)
	shield.set_source(self)
	Character.add_allied_effect(context, ai, actor, shield)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
