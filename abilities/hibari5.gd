extends Ability

var flame_damage = 5

func describe(user):
	return "Whenever an enemy uses an Invisible skill, Hibari deals 5 permanent Affliction damage to them (stacks)."

func split_desc():
	return [
		"Whenever an enemy uses an Invisible skill, Hibari deals 5 permanent Affliction damage to them",
		["This damage stacks", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in context['enemy_team'].characters:
		var watcher = Effect.trigger_effect(
			Trigger.always(cloud_flame_trigger),
			EffectType.Type.ACTION_USE_TRIGGER,
			-1,
			""
		)
		watcher.set_source(self)
		watcher.system = true
		Character.add_hostile_effect(context, user, character, watcher, true)

func cloud_flame_trigger(context):
	var used_skill = context['source']
	if not (used_skill is Ability) or not used_skill.invisible:
		return
	var enemy = context['owner']
	if enemy == null or enemy.dead or enemy.banished:
		return
	var hibari = context['effect'].user
	if hibari == null or hibari.dead or hibari.banished:
		return
	var qc = QueryContext.from_game_state(hibari, hibari.battle)
	var flames = Effect.damage_effect(flame_damage, DamageType.Type.AFFLICTION, -1)
	flames.set_source(self)
	flames.stackable = true
	flames.per_stack = true
	flames.display_stacks = true
	Character.add_hostile_effect(qc, hibari, enemy, flames)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
