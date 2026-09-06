extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 Affliction damage to one enemy and Silences them for 1 turn, stealing health from the damage dealt. Also strikes every enemy permanently marked by Bloody Knife. Consuming Friendly Smile makes the Affliction damage repeat and extends the Silence, 1 turn for each stack."

func split_desc():
	return [
		"Deals 15 Affliction damage to target enemy",
		"Silences them for 1 turn",
		["Nagisa steals health from the damage dealt", Color.CADET_BLUE],
		["Consumes Friendly Smile: each stack makes the damage repeat for a turn and extends the Silence by 1 turn", Color.CADET_BLUE],
		["Also strikes every enemy marked by Bloody Knife", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Killing Intent now always steals health.
	health_drain = true
	var stacks = 0
	if user.marked_by("Friendly Smile", user):
		stacks = user.effects.has_effect("Friendly Smile", EffectType.Type.MARK).stack_count()
		user.manually_advance_mission(10, stacks)
		user.effects.full_remove_effect_by_name("Friendly Smile", user)
	for target in user.targeter.targets:
		_apply_killing_intent(context, user, target, stacks, false)
	# Also strike every enemy permanently marked by Bloody Knife. Extra instances get a
	# unique_render_id so they render separately even when the primary target is also marked.
	for enemy in user.battle.all_characters():
		if user.is_hostile(enemy) and not enemy.dead and not enemy.banished and enemy.marked_by("Bloody Knife", user):
			_apply_killing_intent(context, user, enemy, stacks, true)
	health_drain = false

func _apply_killing_intent(context, user, target, stacks, extra):
	var extra_id = int(Time.get_ticks_msec())
	# Instant hit. The health-drain flag is set on the ability (set in execute), so this immediate
	# resolve_damage drains too.
	Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
	# The lingering Affliction only exists when Friendly Smile is consumed. Each stack adds one turn of
	# DoT: duration 1 + 2*stacks (stacks 1 -> dur 3 = one extra tick after the instant hit, and so on).
	# With no stacks there is NO DoT — Killing Intent is a purely instant strike.
	if stacks > 0:
		var damage = Effect.damage_effect(base_damage, DamageType.Type.AFFLICTION, 1 + (stacks * 2))
		damage.set_source(self)
		damage.health_drain = true
		if extra:
			damage.unique_render_id = extra_id
		Character.add_hostile_effect(context, user, target, damage)
	# Base Silence is 1 turn (dur 2 = the shipped "1 turn" silence convention: emiya5/kuroko1/saber1);
	# each consumed Friendly Smile stack extends it by a further turn (+2).
	var silence = Effect.silence_effect(2 + (stacks * 2))
	silence.set_source(self)
	if extra:
		silence.unique_render_id = extra_id
	Character.add_hostile_effect(context, user, target, silence)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []

	variations += behavior_single_target_damage(context, 55)

	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
