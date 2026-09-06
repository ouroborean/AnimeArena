extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 3 turns, one enemy will be Shattered and if they use a new harmful skill, they take 10 piercing damage. While this is active, Spirit Dive: Sylph has its cost reduced by 1 blue energy."

func split_desc():
	return [
		["One enemy is Shattered for 3 turns", Color.ORANGE_RED],
		["If they use a new harmful skill, they take 10 Piercing damage", Color.ORANGE_RED],
		["While active, Spirit Dive: Sylph costs 1 less blue energy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var shatter = Effect.def_negate(5)
		shatter.set_source(self)
		var trigger_eff = Effect.trigger_effect(Trigger.always(tornado_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, 6, "If this character uses a new harmful skill, they will take 10 piercing damage.")
		trigger_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, trigger_eff)
		Character.add_hostile_effect(context, user, target, shatter)
	var cost_mod = Effect.cost_mod_effect(-1, 5, Energy.Type.BLUE, ["Spirit Dive: Sylph"])
	cost_mod.set_source(self)
	Character.add_allied_effect(context, user, user, cost_mod)
		

func tornado_trigger(context):
	Character.resolve_effect_damage(context, context['effect'], context['target'], 10, DamageType.Type.PIERCING)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 35)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
