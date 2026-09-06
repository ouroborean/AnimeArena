extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mami deals 40 damage to the enemy affected by Ribbon Wrap, increased by 10 for each stack of Tiro Concert on the enemy. Afterwards, all stacks of Tiro Concert are removed from them."

func split_desc():
	return [
		"Deals 40 damage to the enemy affected by Ribbon Wrap",
		"+10 damage per stack of Tiro Concert on the target, then removes all stacks",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var base_damage = 40
		var concert = target.has_effect("Tiro Concert", EffectType.Type.ACTION_USE_TRIGGER, user)
		if concert:
			base_damage += (concert.stacks * 10)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		target.effects.full_remove_effect_by_name("Tiro Concert", user)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_single_require_mark(context, "Ribbon Wrap", EffectType.Type.MARK, 100)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, false, "Ribbon Wrap")
