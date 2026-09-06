extends Ability

var base_damage = 35
var damage_inc = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Eren deals 35 damage to one enemy and loses 5 health. This skill will deal 5 additional damage to both Eren and his target each time it's used."

func split_desc():
	return ["Deals 35 damage to target enemy and Eren loses 5 HP","Permanently deals +5 damage", ["Swaps to Titan Bite during Titan Transformation", Color.AQUAMARINE]]


func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var recklessness = 0
	var reckless = Condition.has_effect(user, "Reckless Charge", EffectType.Type.DAMAGE_MOD, user)
	if reckless.satisfied(context):
		recklessness += user.effects.has_effect("Reckless Charge", EffectType.Type.DAMAGE_MOD, user).stack_count()
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
	var boost_effect = Effect.damage_mod_effect(5, -1, ["Reckless Charge"])
	boost_effect.set_source(self)
	boost_effect.stackable = true
	boost_effect.display_stacks = true
	boost_effect.per_stack = true
	
	Character.add_allied_effect(context, user, user, boost_effect)
	user.receive_damage(damage_inc + (5 * recklessness), user, self)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75, 0.85)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
