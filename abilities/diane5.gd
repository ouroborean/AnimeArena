extends Ability
var base_damage = 30
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 piercing damage to an enemy affected by Queen's Embrace. Affected enemies receive 5 Bleed damage the following turn."

func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy affected by Queen's Embrace, and 5 Bleed damage next turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var damage_eff = Effect.damage_effect(5, DamageType.Type.BLEED, 3)
		damage_eff.set_source(self)
		damage_eff.last_turn_only = true
		Character.add_hostile_effect(context, user, target, damage_eff)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_single_require_mark(context, "Queen's Embrace", EffectType.Type.MARK, 75)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, false, "Queen's Embrace")
