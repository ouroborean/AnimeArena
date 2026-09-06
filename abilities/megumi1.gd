extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 20 damage to target enemy and Stuns their non-Physical skills for 1 turn",
		["Affected enemy is marked for 3 turns", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var shikigami = user.has_effect("Shikigami Summoning", EffectType.Type.TICKING_TRIGGER)
	var target_class
	if not shikigami:
		target_class = "Physical"
	else:
		target_class = shikigami.mag
	
	for target in user.targeter.targets:
		#Put execution per target here
		Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
		var stun = Effect.stun_effect(2, [], [target_class])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
		
		var mark = Effect.mark(7, "This character has been marked by Bottomless Well.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_stun(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
