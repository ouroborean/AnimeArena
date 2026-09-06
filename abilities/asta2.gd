extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Asta equips the Demon-Dweller Sword. While equipped, he heals 10 health whenever Liebe Unite deals damage. If he is at full health when this occurs, he will gain 10 permanent Shield instead (this effect does not stack). Asta can only have one sword equipped at a time."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.call_unique("asta", "change_equip", [])
	var damage_trigger = Effect.trigger_effect(Trigger.always(dweller_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, "If Asta damages an enemy, he will heal 10 health. If he is already at full health, he will gain 10 permanent Shield instead.")
	damage_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, damage_trigger)

func split_desc():
	return [
		"Heals 10 HP whenever Liebe Unite deals damage",
		"If he is at full HP, he gains 10 Shield instead",
		"Asta can only have one Sword effect at a time"
	]

func dweller_trigger(context):
	var asta = context['owner']
	var target = context['target']
	if context['source'].source.ability_name == "Liebe Unite":
		
		if asta.health.hp == 100:
			asta.manually_advance_mission(8, 1)
			var shield = Effect.shield_effect(10, -1)
			shield.set_source(self)
			shield.stackable = false
			shield.stack_mag = false
			shield.refresh = true
			Character.add_allied_effect(context, asta, asta, shield)
		else:
			Character.resolve_effect_healing(context, context['effect'], asta, 10)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.has_effect("Demon-Dweller Sword", EffectType.Type.DAMAGE_DEALT_TRIGGER, user) == null

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 0)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
