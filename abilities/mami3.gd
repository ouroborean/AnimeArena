extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mami targets one enemy for 3 turns. During this time, that enemy will take 5 damage per turn and Mami will counter the first Harmful skill used on her each turn. Each time this effect counters a skill, the enemy gains a stack of Tiro Concert and Mami gains a stack of Mami Soul Gem."

func split_desc():
	return [
		"Deals 10 damage to target enemy for 4 turns. Each turn, Mami will counter the first Harmful skill used on her",
		["Gives the countered enemy a stack of Tiro Concert when triggered", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		var ticking = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, 7, "Mami will deal 10 damage to this enemy.")
		ticking.set_source(self)
		ticking.damage_type = DamageType.Type.NORMAL
		Character.add_hostile_effect(context, user, target, ticking)
	var counter = Effect.counter_effect(Trigger.always(tiro_counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "Mami will counter the first Harmful skill used on her.", ["Harmful"])
	counter.set_source(self)
	Character.add_allied_effect(context, user, user, counter)


func tiro_counter_trigger(context):
	var mami = context['effect'].user
	var trigger = Effect.trigger_effect(Trigger.always(on_use_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "This character will take 5 damage if they use a skill.")
	trigger.set_source(user.moveset.abilities[0])
	trigger.cleansable = true
	trigger.stackable = true
	trigger.display_stacks = true
	Character.add_hostile_effect(context, user, context['effect'].target, trigger)
	default_counter_trigger(context)
	

func on_use_trigger(context):
	var concert = context['effect']
	var count = concert.stacks
	var base = 5
	if user.corruption_stacks() >= 4:
		base = 10
	Character.resolve_effect_damage(context, context['effect'], context['owner'], base * count, DamageType.Type.NORMAL)
	

func tick_trigger(context):
	Character.resolve_effect_damage(context, context['effect'], context['target'], 5, DamageType.Type.NORMAL)
	var counter = Effect.counter_effect(Trigger.always(tiro_counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "Mami will counter the first Harmful skill used on her.", ["Harmful"])
	counter.set_source(self)
	Character.add_allied_effect(context, user, user, counter)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
