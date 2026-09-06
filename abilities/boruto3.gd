extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Marks target enemy for 1 turn (Invisible)",
		["Next turn, deals 25 Piercing damage to the marked enemy and stuns them for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var mark = Effect.mark(3, "Boruto has fired a Vanishing Rasengan.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	
	for target in user.targeter.targets:
		var tick = Effect.trigger_effect(Trigger.always(ticking_trigger), EffectType.Type.TICKING_TRIGGER, 3, "This character will receive 25 Piercing damage and be stunned for 1 turn.")
		tick.set_source(self)
		tick.damage_type = DamageType.Type.PIERCING
		tick.invisible = true
		Character.add_hostile_effect(context, user, target, tick)

func ticking_trigger(context):
	var enemy = context.target
	Character.resolve_effect_damage(context, context.effect, enemy, 25, DamageType.Type.PIERCING)
	var stun = Effect.stun_effect(2)
	stun.set_source(self)
	Character.add_hostile_effect(context, user, enemy, stun)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 15)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
