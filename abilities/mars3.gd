extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Targets an enemy marked by Ofuda, dealing 15 affliction damage to them for 3 turns. During this time, any ally marked by Ofuda will heal 15 HP if they use a new Harmful skill on that enemy."

func split_desc():
	return [
		"Deals 15 Affliction damage to a target enemy marked by Ofuda each turn for 3 turns",
		["While active, any ally marked by Ofuda heals 15 HP when they use a new Harmful skill on that enemy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		var damage = Effect.damage_effect(base_damage, DamageType.Type.AFFLICTION, 5)
		damage.set_source(self)
		Character.add_hostile_effect(context, user, target, damage)
		var trigger = Effect.trigger_effect(Trigger.always(harmful_receive), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 5, "Characters marked by Ofuda will heal 15 HP if they use a new Harmful skill on this character.")
		trigger.set_source(self)
		Character.add_hostile_effect(context, user, target, trigger)
		

func harmful_receive(context):
	var ally = context['source'].user
	var snake = context['effect']
	if ally.marked_by("Ofuda", user):
		Character.resolve_effect_healing(context, snake, ally, 15)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 30)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, false, "Ofuda")
