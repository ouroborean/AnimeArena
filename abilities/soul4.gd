extends Ability
var base_healing = 50
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Soul heals 50 health and permanently increases the bonus damage effect from Scythe Transformation by 5. Soul must deal 100 damage before each use of this skill."

func split_desc():
	return [
		["Soul heals 50 health", Color.CADET_BLUE],
		["Permanently increases Scythe Transformation's bonus damage by 5", Color.CADET_BLUE],
		["Soul must deal 100 damage before each use", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)	
	Character.resolve_healing(context, user, 50)
	user.effects.has_effect("Consume Soul", EffectType.Type.DAMAGE_DEALT_TRIGGER, user).mag -= 100
	var soul_count = user.effects.has_effect("Consume Soul", EffectType.Type.MARK, user)
	if soul_count == null:
		# The soul-count (a cleansable OUTCOME) was stripped off Soul — re-create it from zero so the
		# +5-per-soul bonus re-accumulates. The DAMAGE_DEALT_TRIGGER generator is protected, so it
		# survives (and extra_usable requires it) — only this counter needs re-seeding.
		soul_count = Effect.mark(-1, func (eff): return "Soul has eaten " + str(eff.stacks) + " souls.")
		soul_count.set_source(user.moveset.base_abilities[3])
		soul_count.stacks = 0
		Character.add_allied_effect(context, user, user, soul_count)
	soul_count.stacks += 1
		
func extra_usable(user):
	return user.effects.has_effect("Consume Soul", EffectType.Type.DAMAGE_DEALT_TRIGGER, user) != null and user.effects.has_effect("Consume Soul", EffectType.Type.DAMAGE_DEALT_TRIGGER, user).mag >= 100

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 35, 1.4)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
	
