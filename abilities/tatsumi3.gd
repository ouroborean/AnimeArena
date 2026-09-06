extends Ability
var base_damage = 40
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 40 piercing damage to one enemy, marking them permanently. Skills and effects will consider the marked enemy to be stunned."

func split_desc():
	return [
		"Deals 40 Piercing damage to one enemy",
		["Marks the target permanently; skills and effects consider them stunned", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var mark = Effect.false_stun(-1)
		mark.set_source(self)
		Character.add_allied_effect(context, user, target, mark)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.marked_by("Incursio", user)

func custom_behavior(context):
	var variations = []
	var bypass = false
	if context['owner'].has_effect("Incursio", EffectType.Type.MARK, context['owner']) and context['owner'].is_invuln():
		bypass = true
	variations += behavior_single_target_damage(context, 35, 0.8, bypass)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, (user.has_effect("Incursio", EffectType.Type.MARK, user) and user.is_invuln()))
