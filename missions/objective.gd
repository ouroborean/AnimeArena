extends Node
class_name Objective

var current_progress = 0
@export var obj_id: String
var mission_id: String
@export var max_progress = 0
var performer_character_requirement
var target_character_requirement
var trigger_effect
var helper_effects = []
var ally_effects = []
var enemy_effects = []
var description
var once_per_battle
var triggered
var streak = false
var required_skill = ""
var effect_source = false
var conditions = []
var placeholder = false
var player
var categories = {
	"sword": ["zoro", "meliodas", "erza", "sayaka", "asta", "blackstar", "tatsumi", "akame", "tanjiro", "zenitsu", "inosuke", "rengoku", "muichiro", "yamamoto", "squalo", "eren", "mikasa", "kurapika", "emiya", "saber", "emiyaarcher", "ryuko", "satuski", "ichigo", "byakuya", "nimaiya", "omnimon", "inuyasha", "crona", "uzui"],
	"air": ["naruto", "yuno", "aang", "korra", "hawkmon"],
	"water": ["lucy", "hashirama", "noelle", "aang", "korra", "tanjiro", "muichiro", "yamamoto", "squalo"],
	"earth": ["diane", "hashirama", "aang", "toph", "korra", "alphonse"],
	"ice": ["gray"],
	"fire": ["sasuke", "bakugou", "natsu", "meliodas", "frieren", "ace", "sukuna", "aang", "korra", "rengoku", "tsuna", "genos", "shinra", "tamaki", "mars", "megumin", "marco"],
	"lightning": ["sasuke", "zenitsu", "genos", "killua", "misaka", "frankenstein", "jupiter"],
	"undead": ["jack", "ken", "touka", "myotismon", "hashirama", "ban", "arima"],
	"ninja": ["naruto", "sasuke", "sakura", "hinata", "hashirama", "tsubaki"],
	"hero": ["midoriya", "uraraka", "bakugo", "saitama", "genos", "tatsumaki", "gilgamesh", "gallantmon", "omnimon", "tsuyu"],
	"fairy tail": ["natsu", "lucy", "gray", "erza"],
	"vongola": ["tsuna", "yamamoto", "ryohei", "xanxus", "squalo"],
	"leader": ["luffy", "meliodas", "hashirama", "rob", "tsuna", "xanxus", "rimuru"],
	"brawler": ["luffy", "yuji", "midoriya", "bakugo", "goku", "vegeta", "natsu", "rob", "ryohei", "saitama", "genos", "shinra", "sogiita", "gogeta"],
	"servant": ["saber", "gilgamesh", "emiyaarcher", "jack", "semiramis", "frankenstein", "mash"],
	"team 7": ["naruto", "sasuke", "sakura"],
	"karakura": ["ichigo", "orihime"],
	"shinigami": ["ichigo", "byakuya", "nimaiya"],
	"straw hat": ["luffy", "zoro", "usopp"],
	"titan": ["eren"],
	"esper": ["tatsumaki", "misaka", "kuroko", "sogiita", "shokuho"],
	"magical girl": ["madoka", "sayaka", "mami", "mars", "jupiter", "saturn"],
	"night raid": ["tatsumi", "akame", "sheele"],
	"sins": ["meliodas", "king", "diane", "ban"],
	"villain": ["sasuke", "gilgamesh", "ken", "vegeta", "machinedramon", "xanxus", "toga", "sukuna", "rob", "myotismon"],
	"black bulls": ["asta", "noelle"],
	"digimon": ["gatomon", "ominmon", "myotismon", "machinedramon", "gallantmon", "renamon", "hawkmon"],
	"assassin": ["rob", "blackstar", "tatsumi", "sheele", "akame", "killua", "jack", "semiramis", "nagisa", "tsubaki"],
	"non human" : ["koro", "diane", "king", "meliodas", "eren", "gatomon", "omnimon", "myotismon", "machinedramon", "omnimon", "gallantmon", "renamon", "hawkmon", "sukuna"],
	"mage" : ["asta", "noelle", "yuno", "natsu", "gray", "lucy", "semiramis", "megumin", "frieren"],
	"pirate": ["luffy", "zoro", "usopp", "ace", "marco"]
}


static func specific_ally_win_objective(win_count, is_streak, description, valid_performers = [], valid_targets = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = win_count
	obj.performer_character_requirement = valid_performers
	obj.target_character_requirement = valid_targets
	obj.streak = is_streak
	obj.description = func (obj):
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.win_game_with_ally_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_GAME_END, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj
	

static func deal_damage_objective(damage_count, valid_skills = [], damage_type = null):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = damage_count
	obj.performer_character_requirement = valid_skills
	obj.target_character_requirement = damage_type
	obj.description = func (obj):
		var description = "Deal " + str(int(obj.max_progress)) + " "
		if damage_type != null:
			description += DamageType.get_damage_type_name(damage_type, true) + " "
		description += "damage "
		if valid_skills != []:
			description += "with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.deal_damage_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_DAMAGE, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj

static func reduce_damage_dealt_objective(damage_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = damage_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Reduce " + str(int(obj.max_progress)) + " "
		description += "damage"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.weakness_absorb_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_WEAKNESS_ABSORB, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj

static func reduce_damage_taken_objective(damage_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = damage_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Reduce " + str(int(obj.max_progress)) + " "
		description += "damage"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.dr_absorb_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_DR_ABSORB, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj

static func stun_objective(stun_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = stun_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Stun " + str(int(obj.max_progress)) + " enemies"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.stun_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_STUN, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj

static func shield_objective(shield_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = shield_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Generate " + str(int(obj.max_progress)) + " Shield"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.shield_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_SHIELD, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj
	
static func nullify_objective(shield_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = shield_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Generate " + str(int(obj.max_progress)) + " Nullify"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.nullify_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_NULLIFY, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj
	
static func blind_objective(blind_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = blind_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Blind " + str(int(obj.max_progress)) + " enemies"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.blind_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_BLIND, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj
	
static func shatter_objective(shatter_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = shatter_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Shatter " + str(int(obj.max_progress)) + " enemies"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.shatter_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_SHATTER, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj
		
static func silence_objective(silence_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = silence_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Silence " + str(int(obj.max_progress)) + " enemies"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.silence_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_SILENCE, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj
	
static func taunt_objective(taunt_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = taunt_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Taunt " + str(int(obj.max_progress)) + " enemies"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.taunt_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_TAUNT, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj

static func invuln_objective(invuln_count, valid_skills = [], selfless=false):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = invuln_count
	obj.performer_character_requirement = valid_skills
	obj.streak = selfless
	obj.description = func (obj):
		var opener_word = "Gain "
		if selfless:
			opener_word = "Grant allies "
		var description = opener_word + "Invulnerability " + str(int(obj.max_progress)) + " times"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.invuln_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_INVULN, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj

static func counter_objective(counter_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = counter_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Counter " + str(int(obj.max_progress)) + " enemies"
		if valid_skills != []:
			description += " with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.counter_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_COUNTER, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj
	


static func deal_healing_objective(healing_count, valid_skills = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = healing_count
	obj.performer_character_requirement = valid_skills
	obj.description = func (obj):
		var description = "Give " + str(int(obj.max_progress)) + " "
		description += "healing "
		if valid_skills != []:
			description += "with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
		return description
	var trigger = Trigger.from_condition(Condition.always(), obj.deal_healing_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_HEAL, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj


static func win_objective(win_count, is_streak, valid_performers = [], valid_targets = [], helpers = [], conditions = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = win_count
	obj.performer_character_requirement = valid_performers
	obj.target_character_requirement = valid_targets
	obj.streak = is_streak
	obj.conditions = conditions
	obj.description = func (obj):
		var description = "Win battles "
		if obj.streak:
			description += " in a row "
		if len(obj.target_character_requirement) > 0:
			description += "against "
			for i in range(len(obj.target_character_requirement)):
				description += obj.target_character_requirement[i]
				
				if not i == len(obj.target_character_requirement) - 1 and not len(obj.target_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.target_character_requirement) - 2:
					description += "or "
		if len(obj.performer_character_requirement) > 0:
			description += "with "
			for i in range(len(obj.performer_character_requirement)):
				description += obj.performer_character_requirement[i]
				
				if not i == len(obj.performer_character_requirement) - 1 and not len(obj.performer_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.performer_character_requirement) - 2:
					description += "or "
			
		description = description.rstrip(" ")
		return description
	
	var trigger = Trigger.from_condition(Condition.always(), obj.win_game_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_GAME_END, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.helper_effects = helpers
	obj.trigger_effect = trigger_eff
	return obj

static func default_kill_objective(kill_count, valid_performers = [], valid_targets = [], required_skill = "", effect_source=false, conditions = []):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.max_progress = kill_count
	obj.performer_character_requirement = valid_performers
	obj.target_character_requirement = valid_targets
	obj.required_skill = required_skill
	obj.effect_source = effect_source
	obj.conditions = conditions
	
	obj.description = func (obj):
		var description = "Kill "
		if len(obj.target_character_requirement) > 0:
			
			for i in range(len(obj.target_character_requirement)):
				description += obj.target_character_requirement[i]
				
				if not i == len(obj.target_character_requirement) - 1 and not len(obj.target_character_requirement) == 2:
					description += ", "
				else:
					description += " "
				if i == len(obj.target_character_requirement) - 2:
					description += "or "
		else:
			description += "enemies " 
		if required_skill != "":
			description += "with " + required_skill
		description = description.rstrip(" ")
		return description
	
	var trigger = Trigger.from_condition(Condition.always(), obj.kill_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.MISSION_TRIGGER_ON_KILL, -1)
	trigger_eff.set_source(Ability.passive_ability_source("system"))
	trigger_eff.system = true
	obj.trigger_effect = trigger_eff
	return obj
	

static func placeholder_objective(count, description):
	var obj = load("res://missions/objective.tscn").instantiate()
	obj.placeholder = true
	obj.max_progress = count
	obj.description = func (obj):
		return description
	var trigger = Effect.trigger_effect(Trigger.always(obj.placeholder_trigger), EffectType.Type.MISSION_TRIGGER_GAME_END, -1)
	trigger.set_source(Ability.passive_ability_source("system"))
	trigger.system = true
	obj.trigger_effect = trigger
	return obj

func placeholder_trigger(context):
	pass

func deal_damage_trigger(context):
	if context['battle'].match_type == 0:
		return
	var damage = context['value']
	var damager = context['owner']
	var skill = context['source']
	if context['source'] is Effect:
		skill = context['source'].source
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not skill.ability_name in performer_character_requirement:
			satisfied = false
	if target_character_requirement != null:
		if context['damage_type'] != target_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, damage)

func deal_healing_trigger(context):
	if context['battle'].match_type == 0:
		return
	var healing = context['value']
	var healer = context['owner']
	var skill = context['source']
	if context['source'] is Effect:
		skill = context['source'].source
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not skill.ability_name in performer_character_requirement:
			satisfied = false
	if target_character_requirement != null:
		if context['damage_type'] != target_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, healing)


func weakness_absorb_trigger(context):
	if context['battle'].match_type == 0:
		return
	var weakened_amount = context['value']
	var weakener = context['effect'].user
	var skill = context['source']
	if context['source'] is Effect:
		skill = context['source'].source
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, weakened_amount)


func dr_absorb_trigger(context):
	if context['battle'].match_type == 0:
		return
	var weakened_amount = context['value']
	var weakener = context['source'].user
	var skill = context['source']
	if context['source'] is Effect:
		skill = context['source'].source
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, weakened_amount)

func stun_trigger(context):
	if context['battle'].match_type == 0:
		return
	var stunning_skill = context['source']
	if context['source'] is Effect:
		stunning_skill = context['source'].source
	var stunner = context['owner']
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not stunning_skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, 1)

func shield_trigger(context):
	if context['battle'].match_type == 0:
		return
	var shielding_skill = context['source']
	if context['source'] is Effect:
		shielding_skill = context['source'].source
	var shielder = context['owner']
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not shielding_skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, context['source'].mag)
		
func nullify_trigger(context):
	if context['battle'].match_type == 0:
		return
	var shielding_skill = context['source']
	if context['source'] is Effect:
		shielding_skill = context['source'].source
	var shielder = context['owner']
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not shielding_skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, context['source'].mag)

func blind_trigger(context):
	if context['battle'].match_type == 0:
		return
	var blinding_skill = context['source']
	if context['source'] is Effect:
		blinding_skill = context['source'].source
	var blinder = context['owner']
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not blinding_skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, 1)

func shatter_trigger(context):
	print("Checking shatter trigger!")
	if context['battle'].match_type == 0:
		return
	var shatter_skill = context['source']
	if context['source'] is Effect:
		shatter_skill = context['source'].source
	var shatter = context['owner']
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not shatter_skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, 1)

func silence_trigger(context):
	if context['battle'].match_type == 0:
		return
	var shatter_skill = context['source']
	if context['source'] is Effect:
		shatter_skill = context['source'].source
	var shatter = context['owner']
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not shatter_skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, 1)

func taunt_trigger(context):
	if context['battle'].match_type == 0:
		return
	var taunting_skill = context['source']
	if context['source'] is Effect:
		taunting_skill = context['source'].source
	var taunter = context['owner']
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not taunting_skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, 1)

func invuln_trigger(context):
	if context['battle'].match_type == 0:
		return
	var shielding_skill = context['source']
	
	if context['source'] is Effect:
		shielding_skill = context['source'].source
		
	if streak and shielding_skill.user == context['effect'].target:
		return
	var shielder = context['owner']
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not shielding_skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, 1)

func counter_trigger(context):
	if context['battle'].match_type == 0:
		return
	var countering_skill = context['source']
	if context['source'] is Effect:
		countering_skill = context['source'].source
	var stunner = context['owner']
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not countering_skill.ability_name in performer_character_requirement:
			satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, 1)

func kill_trigger(context):
	if context['battle'].match_type == 0:
		return
	var killer = context['owner']
	var killed = context['target']
	var used = context['source']
	var satisfied = true
	if len(performer_character_requirement) > 0:
		if not context['owner'].character_name in performer_character_requirement:
			satisfied = false
	if len(target_character_requirement) > 0:
			if not context['target'].character_name in target_character_requirement:
				satisfied = false
	if required_skill != "":
		var test = ""
		if used is Effect:
			#if not effect_source:
			#	satisfied = false
			test = used.source.ability_name
		else:
			if effect_source:
				satisfied = false
			test = used.ability_name
		if test != required_skill:
			satisfied = false
	if len(conditions) > 0:
		for condition in conditions:
			if not condition.call(context):
				satisfied = false
	if satisfied:
		update_current_progress(context['battle'].player, 1)

func win_game_with_ally_trigger(context):
	if context['battle'].match_type == 0:
		return
	if context['won']:
		var satisfied = true
		if len(performer_character_requirement) > 0:
			if not context['owner'].character_name in performer_character_requirement:
				satisfied = false
		if len(target_character_requirement) > 0:
			var char_found = false
			for character in context['owner'].team.characters:
				if character.character_name in target_character_requirement:
					char_found = true
				for target in target_character_requirement:
					if target in categories and character.path_name in categories[target] and character != context['owner']:
						char_found = true
			if not char_found:
				satisfied = false
		if len(conditions) > 0:
			for condition in conditions:
				if not condition.call(context):
					satisfied = false
		if satisfied:
			update_current_progress(context['battle'].player, 1)
	else:
		if streak:
			if context['battle'].player.mission_reference[mission_id].completed(context['battle'].player):
				return
			var satisfied = true
			if len(performer_character_requirement) > 0:
				if not context['owner'].character_name in performer_character_requirement:
					satisfied = false
			if len(target_character_requirement) > 0:
				var char_found = false
				for character in context['owner'].team.characters:
					if character.character_name in target_character_requirement:
						char_found = true
					for target in target_character_requirement:
						if target in categories and character.path_name in categories[target]:
							char_found = true
				if not char_found:
					satisfied = false
			if satisfied:
				set_current_progress(context['battle'].player, 0)

func win_game_trigger(context):
	if context['battle'].match_type == 0:
		return
	if context['won']:
		var satisfied = true
		if len(performer_character_requirement) > 0:
			if not context['owner'].character_name in performer_character_requirement:
				satisfied = false
		if len(target_character_requirement) > 0:
			var char_found = false
			for character in context['owner'].battle.enemy.team.characters:
				if character.character_name in target_character_requirement:
					char_found = true
				for target in target_character_requirement:
					if target in categories and character.path_name in categories[target]:
						char_found = true
			if not char_found:
				satisfied = false
		if len(conditions) > 0:
			for condition in conditions:
				if not condition.call(context):
					satisfied = false
		if satisfied:
			update_current_progress(context['battle'].player, 1)
	else:
		if streak:
			if context['battle'].player.mission_reference[mission_id].completed(context['battle'].player):
				return
			var satisfied = true
			if len(performer_character_requirement) > 0:
				if not context['owner'].character_name in performer_character_requirement:
					satisfied = false
			if len(target_character_requirement) > 0:
				var char_found = false
				for character in context['owner'].battle.enemy.team.characters:
					if character.character_name in target_character_requirement:
						char_found = true
					for target in target_character_requirement:
						if target in categories and character.path_name in categories[target]:
							char_found = true
				if not char_found:
					satisfied = false
			if satisfied:
				set_current_progress(context['battle'].player, 0)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	
func complete(player):
	if not mission_id in player.mission_data:
		return false
	if not obj_id in player.mission_data[mission_id]:
		player.mission_data[mission_id][obj_id] = 0
	return player.mission_data[mission_id][obj_id] >= max_progress
	
func update_current_progress(player, mod):
	if not triggered or not once_per_battle:
		player.mission_data[mission_id][obj_id] += mod
		if player.mission_data[mission_id][obj_id] > max_progress:
			player.mission_data[mission_id][obj_id] = max_progress
		triggered = true

func set_current_progress(player, prog):
	current_progress = prog
	player.mission_data[mission_id][obj_id] = prog

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
