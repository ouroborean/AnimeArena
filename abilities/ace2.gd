extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ace applies 1 stack of Firefly to all enemies. Whenever deals new damage to a marked enemy, Ace will consume those marks to deal 10 damage for each mark consumed."

func split_desc():
	return [
		"Marks all enemies with 1 stack of Firefly",
		["Marked enemies take 10 damage per stack if Ace deals new damage to them", Color.ORANGE],
		"This consumes all stacks of Firefly on the target",
		"Ace gains 10 Damage Reduction until the end of his next turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trigger = Effect.trigger_effect(Trigger.always(firefly_damage_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "This character will take 10 damage for each mark the next time Ace deals new damage to them.")
		trigger.set_source(self)
		trigger.cleansable = true
		trigger.stackable = true
		trigger.display_stacks = true
		trigger.ability_only = true
		Character.add_hostile_effect(context, user, target, trigger)
	var dr = Effect.damage_reduction_effect(10, 3)
	dr.set_source(self)
	Character.add_allied_effect(context, user, user, dr)

func firefly_damage_trigger(context):
	var ace = context['owner']
	if ace != user:
		return
	user.manually_advance_mission(6, context['effect'].stacks)
	var target = context['target']
	Character.resolve_effect_damage(context, context['effect'], target, 10 * context['effect'].stacks, DamageType.Type.ENERGY)
	target.effects.full_remove_effect_by_name("Firefly")

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
