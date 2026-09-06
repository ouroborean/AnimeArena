extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 damage to one enemy. Uncounterable. Targets with active Counter effects take an additional 10 damage from this skill. If the target is currently affected by Tsubaki: Enchanted Sword Mode, they take an additional 10 damage from this skill. Both of these effects can activate."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mod_damage = base_damage
		if len(target.effects.get_effects_by_type(EffectType.Type.COUNTER_RECEIVE)) > 0:
			mod_damage += 10
		Character.resolve_damage(context, target, mod_damage, DamageType.Type.NORMAL)

func split_desc():
	return [
		"Deals 25 damage to target enemy (Uncounterable)",
		"+10 damage if target has a Counter effect or is taunted by Tsubaki: Enchanted Sword Mode",
		"(Both can activate)"
	]
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 65, 0.9, context['owner'].marked_by("Tsubaki: Smoke Bomb", context['owner']))
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, user.marked_by("Tsubaki: Smoke Bomb", user))
