extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Asta equips the Demon-Slayer Sword. While equipped, he deals 5 additional damage and enemies damaged by him are permanently marked. If Asta damages a marked enemy while wielding a different sword, he will consume the mark to taunt that enemy for 1 turn. Asta can only have one sword equipped at a time."

func split_desc():
	return [
		"Liebe Unite deals +5 damage and any enemy it damages receives 10 Nullify (stacks)",
		"Asta can only have one Sword effect at a time"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	user.call_unique("asta", "change_equip", [])
	var damage_mod = Effect.damage_mod_effect(5, -1, ["Liebe Unite"])
	damage_mod.set_source(self)
	var damage_trigger = Effect.trigger_effect(Trigger.always(slayer_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, "Asta will give 10 Nullify to enemies he damages.")
	damage_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, damage_trigger)
	Character.add_allied_effect(context, user, user, damage_mod)

func slayer_trigger(context):
	var asta = context['owner']
	var target = context['target']
	if context['source'].source.ability_name == "Liebe Unite":
		var mark = Effect.barrier_effect(10, -1)
		mark.set_source(self)
		mark.stack_mag = true
		mark.display_mag = true
		mark.stackable = true
		Character.add_hostile_effect(context, asta, target, mark)

func slayer_mark_trigger(context):
	var asta = context['owner']
	var target = context['target']
	if not asta.path_name == "asta":
		return
	if asta.has_effect("Demon-Destroyer Sword", EffectType.Type.DAMAGE_DEALT_TRIGGER, asta) or asta.has_effect("Demon-Dweller Sword", EffectType.Type.DAMAGE_DEALT_TRIGGER, asta):
		var taunt = Effect.taunt_effect(3, asta)
		taunt.set_source(self)
		Character.add_hostile_effect(context, asta, target, taunt)
		target.effects.remove_effect("Demon-Slayer Sword", EffectType.Type.DAMAGE_RECEIVE_TRIGGER, asta)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 0)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.has_effect("Demon-Slayer Sword", EffectType.Type.DAMAGE_DEALT_TRIGGER, user) == null
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
