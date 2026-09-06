extends Ability
var base_damage = 20
var base_healing = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Targets a character marked by Ofuda. If they are an enemy, they receive 20 damage and are Stunned for 1 turn. If they are an ally, they are healed for 25 HP."

func split_desc():
	return [
		["If used on an enemy marked by Ofuda, deals 20 damage and stuns them for 1 turn", Color.ORANGE_RED],
		["If used on an ally marked by Ofuda, heals 25 HP", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target in user.team.characters:
			Character.resolve_healing(context, target, base_healing)
		else:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_helpful_single_require_mark(context, "Ofuda", EffectType.Type.MARK, 50)
	variations += behavior_hostile_single_require_mark(context, "Ofuda", EffectType.Type.MARK, 50)
	
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, false, "Ofuda")
	default_allied_target_function(user, battle, false, "Ofuda")
