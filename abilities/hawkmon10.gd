extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 Piercing damage to all enemies for 2 turns",
		["Affected enemies are Shattered, Isolated, and Blinded", Color.ORANGE_RED],
		["Does not apply effects if allies have applied effects of that type in the last 3 turns", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.PIERCING)
		var damage = Effect.damage_effect(10, DamageType.Type.PIERCING, 3)
		damage.set_source(self)
		Character.add_hostile_effect(context, user, target, damage)
		var effect_ids = [3, 4, 6]
		var marks = user.effects.get_effects_by_type(EffectType.Type.EMPTY)
		for mark in marks:
			if mark.mag in effect_ids:
				effect_ids.erase(mark.mag)
		for effect_id in effect_ids:
			match effect_id:
				3:
					user.manually_advance_mission(10, 1)
					var shatter = Effect.def_negate(4)
					shatter.set_source(self)
					Character.add_hostile_effect(context, user, target, shatter)
				4:
					user.manually_advance_mission(10, 1)
					var isolate = Effect.isolate(4)
					isolate.set_source(self)
					Character.add_hostile_effect(context, user, target, isolate)
				6:
					user.manually_advance_mission(10, 1)
					var blind = Effect.blind_effect(4)
					blind.set_source(self)
					Character.add_hostile_effect(context, user, target, blind)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
