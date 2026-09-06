extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 5 Piercing damage to all enemies for 4 turns",
		["Blast Wings and Grand Horn will make Aquilamon invulnerable for 1 turn", Color.CADET_BLUE],
		["This can only trigger once per skill", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 5, DamageType.Type.PIERCING)
		var damage = Effect.damage_effect(5, DamageType.Type.PIERCING, 7)
		damage.set_source(self)
		Character.add_hostile_effect(context, user, target, damage)
	var horn_trigger = Effect.trigger_effect(Trigger.always(horn_on_use), EffectType.Type.ACTION_USE_TRIGGER, 7, "Grand Horn will make Aquilamon Invulnerable for 1 turn.")
	horn_trigger.set_source(self)
	horn_trigger.unique_render_id = 4
	var wing_trigger = Effect.trigger_effect(Trigger.always(wings_on_use), EffectType.Type.ACTION_USE_TRIGGER, 7, "Blast Wings will make Aquilamon Invulnerable for 1 turn.")
	wing_trigger.set_source(self)
	wing_trigger.unique_render_id = 5
	Character.add_allied_effect(context, user, user, horn_trigger)
	Character.add_allied_effect(context, user, user, wing_trigger)
	

func horn_on_use(context):
	if not context.source.ability_name == "Grand Horn":
		return
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	user.effects.erase_effect(context.effect)

func wings_on_use(context):
	if not context.source.ability_name == "Blast Wings":
		return
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	user.effects.erase_effect(context.effect)
	
		
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
