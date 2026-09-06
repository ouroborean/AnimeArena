extends Ability
var base_damage = 10
var base_retaliation = 15
var base_permanent = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 affliction damage to one enemy. For 1 turn they will take 15 affliction damage if they use a skill. If they do not, they receive 10 affliction damage permanently. "

func split_desc():
	return [
		"For 1 turn, if target enemy uses a Harmful skill, they will be countered and take 25 damage (Invisible)",
		["If this effect is not triggered, that enemy takes 10 damage instead", Color.CADET_BLUE]
	]
	
func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_USE, 2, "If this character uses a new Harmful skill, they will take 25 damage.", ["Harmful"])
		counter.wrapup_func = timeout_trigger
		counter.set_source(self)
		counter.invisible = true
		Character.add_hostile_effect(context, user, target, counter)

func timeout_trigger(context):
	Character.resolve_effect_damage(context, context.effect, context.target, 10, DamageType.Type.NORMAL)
	default_counter_timeout(context)

func counter_trigger(context):
	Character.resolve_effect_damage(context, context.effect, context.owner, 25, DamageType.Type.NORMAL)
	default_counter_trigger(context)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Revenge Counter")

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 80, 1.2)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
