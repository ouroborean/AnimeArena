extends Ability
var base_damage = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to all enemies. For 1 turn, if King deals damage to affected enemies, he will heal all living allies for 5 health."

func split_desc():
	return [
		"Deals 5 damage to all enemies for 3 turns",
		["Deals 10 Piercing damage while Empowered", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var damage_type = DamageType.Type.NORMAL
	if user.marked_by("True Spirit Spear Chastifold"):
		damage_type = DamageType.Type.PIERCING
		base_damage = 10
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, damage_type)
	
		
		var damage = Effect.damage_effect(base_damage, damage_type, 5)
		damage.set_source(self)
		Character.add_hostile_effect(context, user, target, damage)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 50, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
