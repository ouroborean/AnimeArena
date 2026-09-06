extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Natsu deals 20 physical damage to one enemy and for one turn if they use a new skill, it is delayed for 2 turns. If they do not, Natsu deals 15 physical damage and 5 affliction damage to the enemy team."

func split_desc():
	return [
		"Deals 20 damage to target enemy and for 1 turn, if they use a new skill, it is delayed for 2 turns",
		["If they do not, Natsu deals 15 damage and 5 Affliction damage to the enemy team", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var delay_eff = Effect.delay_eff(2, 2)
		delay_eff.set_source(self)
		delay_eff.wrapup_func = wing_attack_trigger
		var mark_eff = Effect.mark(2, "If this character does not use a new skill, Natsu will deal 15 Physical damage and 5 Affliction damage to the enemy team.")
		mark_eff.set_source(self)
		
		Character.add_hostile_effect(context, user, target, delay_eff)
		Character.add_hostile_effect(context, user, target, mark_eff)
	

func wing_attack_trigger(context):
	var natsu = context['owner']
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self):
			Character.resolve_effect_damage(context, context['effect'], character, 15, DamageType.Type.NORMAL)
			Character.resolve_effect_damage(context, context['effect'], character, 5, DamageType.Type.AFFLICTION)

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
