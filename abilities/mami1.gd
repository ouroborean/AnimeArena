extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mami permanently marks the enemy team. Whenever a marked enemy uses a skill, they will take 5 damage (stacks)."

func split_desc():
	return [
		"Permanently marks all enemies",
		"Deals 5 damage to marked enemies when they use a skill"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trigger = Effect.trigger_effect(Trigger.always(on_use_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "This character will take 5 damage if they use a skill.")
		trigger.set_source(self)
		trigger.cleansable = true
		trigger.stackable = true
		trigger.display_stacks = true
		Character.add_hostile_effect(context, user, target, trigger)
	

func on_use_trigger(context):
	var concert = context['effect']
	var count = concert.stacks
	var base = 5
	if user.call_unique("mami", "corruption_stacks", []) >= 4:
		base = 10
	Character.resolve_effect_damage(context, context['effect'], context['owner'], base * count, DamageType.Type.NORMAL)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 100)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
