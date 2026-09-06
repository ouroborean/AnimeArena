extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 damage to target enemy for 4 turns (refreshes)",
		["Permanently, Renamon deals 5 Piercing damage to all enemies affected by Diamond Storm when it uses a non-Strategic skill (Bypassing)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		var damage = Effect.damage_effect(10, DamageType.Type.NORMAL, 7)
		damage.refresh = true
		damage.set_source(self)
		Character.add_hostile_effect(context, user, target, damage)
	if not user.has_effect("Diamond Storm", EffectType.Type.ACTION_USE_TRIGGER):
		var trigger = Effect.trigger_effect(Trigger.always(renamon_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "Renamon will deal 5 Piercing damage to all enemies affected by Diamond Storm when it uses a non-Strategic skill")
		trigger.set_source(self)
		Character.add_allied_effect(context, user, user, trigger)

func renamon_trigger(context):
	if context.source.classes["Strategic"]:
		return
	for character in user.battle.all_characters():
		if user.is_hostile(character) and not character.dead and not character.banished:
			if character.has_effect("Diamond Storm", EffectType.Type.DAMAGE):
				Character.resolve_damage(context, character, 5, DamageType.Type.PIERCING)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
