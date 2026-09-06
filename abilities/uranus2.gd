extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

# Set in execute() when this skill is cast on the Lip Rod ally; read in
# start_cooldown() to swap the base cooldown to 1 for this one use. Cleared
# back to false at the end of start_cooldown() so the next cast starts fresh.
var _was_cast_on_lip_rod = false

func describe(user):
	return "Targets an ally for 1 turn. If an enemy uses a Harmful skill on them during this time, that skill will be countered and the attacker takes 25 damage. Cooldown reduced to 1 turn if this targets the ally marked by Uranus Lip Rod."

func split_desc():
	return [
		"Targets an ally for 1 turn",
		["If an enemy uses a Harmful skill on them, it is countered and the attacker takes 25 damage", Color.CADET_BLUE],
		["Cooldown reduced to 1 turn if this targets the ally marked by Uranus Lip Rod", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# COUNTER_RECEIVE on the protected ally fires before the harmful skill
	# resolves (engine consults it inside countered() during the targeting
	# phase, returning true to cancel the action). class_targets=["Harmful"]
	# scopes the counter to Harmful skills only.
	var lip_rod_ally = _find_lip_rod_ally(user)
	_was_cast_on_lip_rod = false
	for target in user.targeter.targets:
		if target == lip_rod_ally:
			_was_cast_on_lip_rod = true
			cooldown_remaining = 2
		var counter = Effect.counter_effect(
			Trigger.always(intercepting_counter),
			EffectType.Type.COUNTER_RECEIVE,
			2,
			"The next Harmful skill used on this character will be countered, and the attacker takes 25 damage.",
			["Harmful"]
		)
		counter.invisible = true
		
		counter.wrapup_func = default_counter_timeout
		apply_allied(context, target, counter)

# Overridden to install the dynamic 1-turn cooldown when this skill landed on
# the Lip Rod ally. We temporarily swap the base `cooldown` field to 1, let
# the parent class compute cooldown_remaining with the normal start_mod and
# any COOLDOWN_MOD effects in play, then restore the base value. This keeps
# any future +1 / -1 cooldown_mod effects from other sources working normally.
func start_cooldown():
	if _was_cast_on_lip_rod:
		var saved = cooldown
		cooldown_remaining = 1
		super.start_cooldown()
		cooldown = saved
	else:
		super.start_cooldown()
	_was_cast_on_lip_rod = false

func intercepting_counter(context):
	var enemy = context['owner']
	var uranus = context['effect'].user
	if enemy == null or enemy.dead or enemy.banished:
		default_counter_trigger(context)
		return
	if uranus == null or uranus.dead or uranus.banished:
		default_counter_trigger(context)
		return
	# 25 damage to the countered attacker. Use resolve_effect_damage so the
	# damage is attributed to the counter effect (and to Uranus as eff.user)
	# rather than to some absent "active" Uranus ability.
	Character.resolve_effect_damage(context, context['effect'], enemy, 25, DamageType.Type.NORMAL)
	default_counter_trigger(context)

func _find_lip_rod_ally(user):
	for ally in user.team.characters:
		if ally == user:
			continue
		if ally.marked_by("Uranus Lip Rod", user):
			return ally
	return null

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	var uranus = context['owner']
	var lip_rod_ally = _find_lip_rod_ally(uranus)
	# Heavily prefer the Lip Rod ally (1-turn cooldown). Fall back to other
	# allies (or Uranus herself) at lower priority for the 3-turn cast.
	if lip_rod_ally != null and not (lip_rod_ally.dead or lip_rod_ally.banished):
		variations.append([90, [user, self, [lip_rod_ally]]])
	for ally in context['ally_team'].characters:
		if ally == lip_rod_ally:
			continue
		if ally.dead or ally.banished:
			continue
		variations.append([35, [user, self, [ally]]])
	if variations.is_empty():
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
