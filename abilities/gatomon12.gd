extends Ability
var base_damage = 30
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ophanimon deals 30 True damage to the enemy team and fully blinds their skills for 1 turn. If any enemy uses any skills during this time, this effect is extended by 1 turn for the entire enemy team."


func split_desc():
	return [
		"Deals 30 True damage to all enemies and Blinds them for 1 turn",
		"Blind effect extends by 1 turn whenever affected enemies use skills"
	]
	


func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.TRUE)
		var blind = Effect.blind_effect(2)
		blind.set_source(self)
		Character.add_hostile_effect(context, user, target, blind)
		
		var trigger = Effect.trigger_effect(Trigger.always(extend_trigger), EffectType.Type.ACTION_USE_TRIGGER, 2, "If this character uses a new skill, Final Judgement's duration will be extended by 1 turn for all currently affected targets.")
		trigger.set_source(self)
		Character.add_hostile_effect(context, user, target, trigger)
		

func extend_trigger(context):
	var affected = context['effect'].target
	var ophanim = context['effect'].user
	ophanim.manually_advance_mission(9, 1)
	for character in affected.team.characters:
		if character.has_effect("Final Judgement", EffectType.Type.ACTION_USE_TRIGGER, ophanim):
			for effect in character.effects.get_all_effects_by_name("Final Judgement", ophanim):
				effect.duration += 2
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 35, 0.9)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
