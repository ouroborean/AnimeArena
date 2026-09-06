extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "One target ally will become stunned and invulnerable for 2 turns. During this time they will heal 15 health per turn."

func split_desc():
	return [
		"Enemies damaged by King receive 10 Bleed damage the following turn. This does not trigger if the damage is absorbed or avoided"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dmg_trigger = Effect.trigger_effect(Trigger.always(damage_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, "Enemies damaged by King will take 10 Bleed damage the following turn")
	dmg_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, dmg_trigger)
		
func damage_trigger(context):
	if context.source is Effect:
		if context.source.source.ability_name == "Disaster":
			return
	
	var bleed = Effect.damage_effect(10, DamageType.Type.BLEED, 3)
	bleed.last_turn_only = true
	bleed.set_source(self)
	Character.add_hostile_effect(context, user, context.target, bleed)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true


func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
