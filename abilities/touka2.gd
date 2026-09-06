extends Ability

var base_damage = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Touka deals 5 piercing damage to all enemies and increases their cooldowns by 1 for 2 turns. This deals 15 additional damage during 'Crystallized Ukaku'."

func split_desc():
	return [
		"Deals 5 piercing damage to all enemies, +15 during 'Crystallized Ukaku'",
		["Increases enemy cooldowns by 1 for 2 turns", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		user.manually_advance_mission(8, 1)
		var mark_desc = func (eff):
			return "This character will take 5 more damage from Ukaku Slam."
		var mark_eff = Effect.from(EffectType.Type.MARK, {"description": mark_desc, "duration": 3})
		mark_eff.set_source(self)
		
		var cooldown_eff = Effect.cooldown_mod(1, 4)
		cooldown_eff.set_source(self)
		
		Character.add_hostile_effect(context, user, target, cooldown_eff)
		Character.add_hostile_effect(context, user, target, mark_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	if target_type() == TargetType.Type.SINGLE:
		variations += behavior_single_target_damage(context, 35)
	else:
		variations += behavior_hostile_aoe_damage(context, 15)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
