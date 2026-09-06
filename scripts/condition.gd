class_name Condition

var satisfied_condition = func(query_context): return true 

	
static func always() -> Condition:
	var condition = Condition.new()
	return condition

static func is_not(q_condition) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		return not q_condition.satisfied(query_context)
	
	condition.set_satisfied(satisfied_function)
	
	return condition

static func multi(conditions) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		for sub_cond in conditions:
			if not sub_cond.satisfied(query_context):
				return false
		return true
	condition.set_satisfied(satisfied_function)
	
	return condition

static func any(conditions) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		for sub_cond in conditions:
			if sub_cond.satisfied(query_context):
				return true
		return false
	condition.set_satisfied(satisfied_function)
	
	return condition

static func is_invuln(character, ability=null) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func (query_context):
		return character.is_invuln(ability) and not character.def_broken()
	
	condition.set_satisfied(satisfied_function)
	return condition

static func is_alive(character) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func(query_context):
		return not (character.dead or character.banished)
	
	condition.set_satisfied(satisfied_function)
	return condition

static func is_hostile(character, target) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func (query_context):
		var enemy_team = query_context.battle.get_team_factions_from_character(character)[1]
		return target in enemy_team.characters
	condition.set_satisfied(satisfied_function)
	
	return condition
	
static func is_damageable(character, ability_source) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func (query_context):
		return not character.is_ignoring_damage(ability_source)
	condition.set_satisfied(satisfied_function)
	
	return condition

static func can_apply_effect(user, target, effect) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func (query_context):
		return target.can_be_affected(user, effect)
	condition.set_satisfied(satisfied_function)
	
	return condition

static func is_healable(character) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func(query_context):
		#TODO: add isolation/heal-ban effect check
		return not character.is_isolated()
	condition.set_satisfied(satisfied_function)
	
	return condition

static func is_helpable(character) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func(query_context):
		return not character.is_isolated()
	condition.set_satisfied(satisfied_function)
	return condition

static func can_apply_hostile_effect(user, target, effect, bypassing=false) -> Condition:
	var effect_apply_condition = Condition.can_apply_effect(user, target, effect)
	var invuln_check = Condition.is_not(Condition.is_invuln(target, effect.source))
	var alive = Condition.is_alive(target)
	var conditions = [effect_apply_condition, alive]
	if not bypassing:
		conditions.append(invuln_check)
	var condition = Condition.multi(conditions)
	
	return condition
	
static func can_apply_allied_effect(user, target, effect, bypassing=false) -> Condition:
	var effect_apply_condition = Condition.can_apply_effect(user, target, effect)
	var helpable = Condition.is_helpable(target)
	var alive = Condition.is_alive(target)
	var conditions = [effect_apply_condition, alive]
	if not bypassing and effect.source.classes["Helpful"]:
		conditions.append(helpable)
	var condition = Condition.multi(conditions)
	return condition

static func extra_targetable(targeter, target, targeting_ability=null) -> Condition:
	var extra_sukuna = Condition.is_not(Condition.has_effect(target, "Sealed King", EffectType.Type.MARK, target))
	var iron_maiden_ok = Condition.iron_maiden_targetable(targeter, target)
	var gibbet_target_ok = Condition.gibbet_target_unrestricted(targeter, target)
	var gibbet_actor_ok = Condition.gibbet_actor_unrestricted(targeter, target)
	var always_extra = Condition.always()
	var conditions = [extra_sukuna, iron_maiden_ok, gibbet_target_ok, gibbet_actor_ok, always_extra]
	var condition = Condition.multi(conditions)
	return condition

static func iron_maiden_targetable(targeter, target) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		if targeter == target:
			return true
		return target.effects.has_effect("Iron Maiden", EffectType.Type.MARK, target) == null
	condition.set_satisfied(satisfied_function)
	return condition

static func gibbet_target_unrestricted(targeter, target) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		var mark = target.effects.has_effect("Gibbet", EffectType.Type.MARK)
		if mark == null:
			return true
		if targeter == target:
			return true
		if targeter == mark.user:
			return true
		return false
	condition.set_satisfied(satisfied_function)
	return condition

static func gibbet_actor_unrestricted(targeter, target) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		var mark = targeter.effects.has_effect("Gibbet", EffectType.Type.MARK)
		if mark == null:
			return true
		if targeter == target:
			return true
		if target == mark.user:
			return true
		return false
	condition.set_satisfied(satisfied_function)
	return condition

static func can_hostile_target(targeter, target, targeting_ability, bypassing=false) -> Condition:
	var not_invuln = Condition.is_not(Condition.is_invuln(target, targeting_ability))
	var hostile = Condition.is_hostile(targeter, target)
	var alive = Condition.is_alive(target)
	var extra = Condition.extra_targetable(targeter, target, targeting_ability)
	var conditions = [hostile, alive, extra]
	if not bypassing:
		conditions.append(not_invuln)
	var condition = Condition.multi(conditions)
	#TODO add check for targeting limitations
	
	return condition
	
static func can_allied_target(targeter, target, bypassing=false) -> Condition:
	var helpable = Condition.is_helpable(target)
	var allied = Condition.is_not(Condition.is_hostile(targeter, target))
	var alive = Condition.is_alive(target)
	var extra = Condition.extra_targetable(targeter, target)
	var conditions = [allied, alive, extra]
	if not bypassing:
		conditions.append(helpable)
	var condition = Condition.multi(conditions)
	return condition

static func has_effect(target, effect_name, effect_type, user) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		return target.effects.has_effect(effect_name, effect_type, user)
	
	condition.set_satisfied(satisfied_function)
	return condition

static func value_is(value, minimum_value = -1, maximum_value = -1) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		return (minimum_value == -1 or value >= minimum_value) and (maximum_value == -1 or value <= maximum_value)
	
	condition.set_satisfied(satisfied_function)
	return condition

static func health_is(target, min=-1, max=-1) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		var value_check = Condition.value_is(target.health.hp, min, max)
		return value_check.satisfied(query_context)
	condition.set_satisfied(satisfied_function)
	return condition

static func mag_is(target, effect_name, effect_type, user, min = -1, max = -1) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		var has_effect = Condition.has_effect(target, effect_name, effect_type, user)
		if has_effect.satisfied(query_context):
			var mag = target.effects.has_effect(effect_name, effect_type, user).mag
			var value_check = Condition.value_is(mag, min, max)
			return value_check.satisfied(query_context)
		return false
	condition.set_satisfied(satisfied_function)
	return condition
		

static func stack_count_is(target, effect_name, effect_type, user, minimum_count=-1, maximum_count = -1) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		var has_effect = Condition.has_effect(target, effect_name, effect_type, user)
		if has_effect.satisfied(query_context):
			var stacks = target.effects.has_effect(effect_name, effect_type, user).stacks
			var value_check = Condition.value_is(stacks, minimum_count, maximum_count)
			return value_check.satisfied(query_context)
		return false
	condition.set_satisfied(satisfied_function)
	return condition

static func has_ability_class(ability_class, ability) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		return ability.classes[ability_class]
	
	condition.set_satisfied(satisfied_function)
	return condition

static func action_countered(ability, effect) -> Condition:
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		var class_match = false
		
		var user_hostile = Condition.is_hostile(ability.user, effect.user)
		if user_hostile.satisfied(query_context):
			for ability_type in effect.class_targets:
				if Condition._acts_as_class(ability_type, ability, query_context):
					class_match = true
			if effect.class_targets == []:
				class_match = true
			for ability_type in effect.exclusion_targets:
				if Condition._acts_as_class(ability_type, ability, query_context):
					return false
		return class_match

	condition.set_satisfied(satisfied_function)
	return condition

# Faction-aware class check for counter/reflect matching: "Harmful"/"Helpful" match a dual-classed skill
# ONLY while it is actually acting on that faction (aimed at an enemy / an ally). Every other class
# matches on the static ability class exactly as before.
static func _acts_as_class(ability_class, ability, query_context) -> bool:
	if ability_class == "Harmful":
		return Character.ability_acts_harmful(ability)
	if ability_class == "Helpful":
		return Character.ability_acts_helpful(ability)
	return Condition.has_ability_class(ability_class, ability).satisfied(query_context)

static func is_acting_alone(actor):
	var condition = Condition.new()
	var satisfied_function = func satisfied(query_context):
		for character in actor.team.characters:
			if character.acted and character.character_name != actor.character_name:
				return false
		return true
	condition.set_satisfied(satisfied_function)
	return condition

func set_satisfied(sat_func):
	satisfied_condition = sat_func

func satisfied(query_context):
	return satisfied_condition.call(query_context)
