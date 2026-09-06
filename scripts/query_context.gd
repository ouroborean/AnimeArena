class_name QueryContext

var owner
var target
var battle
var ally_team
var enemy_team
var id
var effect
var source = 0
var value
var won
var damage_type

static func from_game_state(q_owner, q_match):
	var context = QueryContext.new()
	context.owner = q_owner
	context.battle = q_match
	var faction_orientation = q_match.get_team_factions_from_character(q_owner)
	context.ally_team = faction_orientation[0]
	context.enemy_team = faction_orientation[1]
	context.id = context.get_instance_id()
	
	return context

static func from_counter_check(q_targeter, q_target, q_effect, q_match):
	var context = QueryContext.new()
	context.owner = q_targeter
	context.target = q_target
	context.effect = q_effect
	context.battle = q_match
	var faction_orientation = q_match.get_team_factions_from_character(q_targeter)
	context.ally_team = faction_orientation[0]
	context.enemy_team = faction_orientation[1]
	context.id = context.get_instance_id()
	return context

static func from_effect_end(q_effect):
	var context = QueryContext.new()
	context.owner = q_effect.user
	context.target = q_effect.target
	context.battle = q_effect.user.battle
	context.source = q_effect
	context.effect = q_effect
	var faction_orientation = context.battle.get_team_factions_from_character(context.owner)
	context.ally_team = faction_orientation[0]
	context.enemy_team = faction_orientation[1]
	context.id = context.get_instance_id()
	
	return context

static func from_trigger_source(qsource, qtrigger, qtarget, qvalue=0):
	var context = QueryContext.new()
	if qsource is Ability:
		context.owner = qsource.user
		context.battle = qsource.user.battle
	if qsource is Effect:
		context.owner = qsource.user
		context.battle = qsource.user.battle
	context.source = qsource
	context.value = qvalue
	context.target = qtarget
	var faction_orientation = context.battle.get_team_factions_from_character(context.owner)
	context.ally_team = faction_orientation[0]
	context.enemy_team = faction_orientation[1]
	context.id = context.get_instance_id()
	context.effect = qtrigger
	return context
