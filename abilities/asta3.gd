extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Asta equips the Demon-Destroyer Sword. While equipped, he deals 10 additional damage, and takes 10 affliction damage whenever Liebe Unite deals damage. Asta can only have one sword equipped at a time."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.call_unique("asta", "change_equip", [])
	var damage_mod = Effect.damage_mod_effect(10, -1, ["Liebe Unite"])
	damage_mod.set_source(self)
	var damage_trigger = Effect.trigger_effect(Trigger.always(destroyer_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, "If Asta deals damage to an enemy, he will take 10 affliction damage.")
	
	damage_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, damage_trigger)
	Character.add_allied_effect(context, user, user, damage_mod)

func split_desc():
	return [
		"Liebe Unite deals +10 damage and its damage is changed to Affliction, but Asta takes 10 Affliction damage whenever it deals damage",
		"Asta can only have one Sword effect at a time"
	]

func destroyer_trigger(context):
	var asta = context['owner']
	if context['source'].source.ability_name == "Liebe Unite":
		Character.resolve_effect_damage(context, context['effect'], asta, 10, DamageType.Type.AFFLICTION)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.has_effect("Demon-Destroyer Sword", EffectType.Type.DAMAGE_DEALT_TRIGGER, user) == null

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 0)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
