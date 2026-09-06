extends Node
class_name Mission

@export var _name: String
@export var mission_id: String
@export var description: String
@export var image: Texture
@export var rank_requirement: Rank.Type
var valid_characters = []
var objectives = []
var rewards = []
var obj_access = {}
var manual_toggle = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init():
	get_objectives()
	get_rewards()
	get_valid_characters()

func get_objectives():
	objectives = []

func get_rewards():
	rewards = []
	
func get_valid_characters():
	valid_characters = []

func completed(player):
	for objective in objectives:
		if not objective.complete(player):
			return false
	return true

func is_character_valid(char_name):
	return char_name in valid_characters

func assign_objective(objective):
	objective.obj_id = mission_id + "_" + str(len(objectives))
	objective.mission_id = mission_id
	objectives.append(objective)
	obj_access[objective.obj_id] = objective

func assign(character, player):
	if manual_toggle:
		objectives[0].player = player
		character.manual_toggle_missions[mission_id] = objectives[0]
		return
		
	if is_character_valid(character.path_name) and not completed(player) and not manual_toggle:
		for objective in objectives:
			objective.trigger_effect.user = character
			character.effects._effects.append(objective.trigger_effect)
			for eff in objective.helper_effects:
				eff.user = character
				character.effects._effects.append(eff)
			for helper in objective.ally_effects:
				var eff_type = helper[0]
				var eff_name = helper[1]
				for ally in character.team.characters:
					if eff_type == EffectType.Type.MARK:
						var helper_eff = Effect.mark(-1, "")
						helper_eff.system = true
						helper_eff.set_source(Ability.passive_ability_source(eff_name))
						character.apply_effect(helper_eff, ally)
					else:
						var eff_trigger = helper[2]
						var helper_eff = Effect.trigger_effect(Trigger.always(eff_trigger), eff_type, -1, "")
						helper_eff.system = true
						helper_eff.set_source(Ability.passive_ability_source(eff_name))
						character.apply_effect(helper_eff, ally)
				
			for helper in objective.enemy_effects:
				var eff_type = helper[0]
				var eff_name = helper[1]
				for enemy in character.battle.enemy.team.characters:
					if eff_type == EffectType.Type.MARK:
						var helper_eff = Effect.mark(-1, "")
						helper_eff.system = true
						helper_eff.set_source(Ability.passive_ability_source(eff_name))
						character.apply_effect(helper_eff, enemy)
					else:
						var eff_trigger = helper[2]
						var helper_eff = Effect.trigger_effect(Trigger.always(eff_trigger), eff_type, -1, "")
						helper_eff.system = true
						helper_eff.set_source(Ability.passive_ability_source(eff_name))
						character.apply_effect(helper_eff, enemy)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

static func initial_mission_status():
	
	
	
	var missions = [
		
	]
	

	var mission_data = {
		
	}
	
	for mission in missions:
		mission_data[mission.mission_id] = {}
		for objective in mission.objectives:
			mission_data[mission.mission_id][objective.obj_id] = 0
	
	return mission_data

static func all_missions():
	var missions = [
		
	]
	
	
	var mission_data = {
		
	}
	for mission in missions:
		mission_data[mission.mission_id] = mission
	return mission_data

static func mission_list():
	var missions = all_missions()
	var mission_dict = {
		"categories": [
			{
				"name": "Naruto Missions",
				"image": load("res://assets/images/naruto_mission_icon.png"),
				"missions": [
					missions['kakashi_unlock']
				]
			},
			{
				"name": "One Piece Missions",
				"image": load('res://assets/images/onepiece_mission_icon.png'),
				"missions": [
					
				]
			},
			{
				"name": "Demon Slayer Missions",
				"image": load('res://assets/images/demon_slayer_mission_icon.png'),
				"missions": [
					
				]
			}
		]
	}
	
	return mission_dict
