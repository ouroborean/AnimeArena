extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "The first time Machinedramon's health falls below 20, at the end of his next turn, he will deal 25 damage to all targetable characters and then die."

func split_desc():
	return [
		["The first time Machinedramon's health falls below 20, at the end of his next turn he deals 25 damage to all targetable characters", Color.ORANGE_RED],
		["Machinedramon then dies", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger_desc = func (eff):
		return "If Machinedramon's health is brought to 20 or lower, he will detonate on the following turn, dealing 25 damage to all targetable characters and then dying."
	var trigger = Trigger.from_condition(Condition.health_is(user, -1, 20), begin_sd_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.HEALTH_CHANGE_TRIGGER, -1, trigger_desc)
	trigger_eff.set_source(self)
	Character.add_allied_effect(context, user, user, trigger_eff)
		
func begin_sd_trigger(context):
	var duration = 2
	if not context['owner'].battle.waiting_for_turn:
		duration = 3
	var trigger = Effect.trigger_effect(Trigger.always(self_destruct_trigger), EffectType.Type.TICKING_TRIGGER, duration, "When this skill ends, all enemies and all allies will receive 25 damage, then Machinedramon will die.")
	trigger.set_source(self)
	Character.add_allied_effect(context, context['owner'], context['owner'], trigger)
		
func self_destruct_trigger(context):
	var user = context['owner']
	for character in user.battle.all_characters():
		if not character == user:
			var invuln = Condition.is_invuln(character, self)
			if not invuln.satisfied(context) and not (character.dead or character.banished):
				Character.resolve_effect_damage(context, context['effect'], character, base_damage, DamageType.Type.NORMAL)
	user.instant_kill(user, self)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
