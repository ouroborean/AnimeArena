extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the rest of the game, Asta will randomly attack one enemy at the end of the turn, dealing 15 damage and applying any weapon effects from his equipped sword. The first time he falls below 70 health, he will counterattack the first person to target him with a skill every turn, dealing 10 damage. The first time he falls below 40 health, he may equip two swords at once."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger = Effect.trigger_effect(Trigger.always(liebe_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Asta will deal 15 damage to a random enemy.")
	trigger.set_source(self)
	
	var health_trigger1 = Effect.trigger_effect(Trigger.from_condition(Condition.health_is(user, -1, 69), liebe_first_threshold), EffectType.Type.HEALTH_CHANGE_TRIGGER, -1, "The first time Asta's health falls below 70, he will deal 20 damage to the first enemy to use a new skill on him each turn.")
	health_trigger1.set_source(self)
	var health_trigger2 = Effect.trigger_effect(Trigger.from_condition(Condition.health_is(user, -1, 39), liebe_second_threshold), EffectType.Type.HEALTH_CHANGE_TRIGGER, -1, "The first time Asta's health falls below 40, he can equip two swords at once for the rest of the game.")
	health_trigger2.set_source(self)
	
	
	
	Character.add_allied_effect(context, user, user, trigger)
	Character.add_allied_effect(context, user, user, health_trigger1)
	Character.add_allied_effect(context, user, user, health_trigger2)
	
	context['effect'] = trigger
	liebe_trigger(context)

func split_desc():
	return [
		"Asta deals 15 damage to a random enemy every turn",
		"If HP is less than 70, deals 10 damage to the first enemy to use a skill on Asta each turn",
		"If HP is less than 40, Asta can have 2 Sword effects at a time"
	]

func liebe_trigger(context):
	var asta = context['owner']
	var valid_targets = []
	for character in asta.battle.all_characters():
		if asta.is_hostile(character) and not character.is_invuln(self) and not (character.dead or character.banished):
			valid_targets.append(character)
	if len(valid_targets) < 1:
		return
	var target = valid_targets[asta.battle.roll(0, len(valid_targets) - 1)]
	var damage_type = DamageType.Type.NORMAL
	if user.has_effect("Demon-Destroyer Sword", EffectType.Type.DAMAGE_DEALT_TRIGGER):
		damage_type = DamageType.Type.AFFLICTION
	
	Character.resolve_effect_damage(context, context['effect'], target, base_damage, damage_type)
	

func liebe_first_threshold(context):
	var asta = context['owner']
	var trigger_eff = Effect.trigger_effect(Trigger.always(liebe_retaliate_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, "Asta will deal 10 damage to any enemy that uses a new harmful skill on him.")
	trigger_eff.set_source(self)
	Character.add_allied_effect(context, asta, asta, trigger_eff)
	asta.effects.consume_effect(context['effect'])

func liebe_second_threshold(context):
	var asta = context['owner']
	var mark = Effect.mark(-1, "Asta can equip two swords at once.")
	mark.set_source(self)
	mark.cleansable = false
	Character.add_allied_effect(context, asta, asta, mark)
	asta.effects.consume_effect(context['effect'])

func liebe_retaliate_trigger(context):
	var asta = context['target']
	var attacker = context['owner']
	Character.resolve_effect_damage(context, context['effect'], attacker, 10, DamageType.Type.NORMAL)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 400)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.has_effect("Liebe Unite", EffectType.Type.TICKING_TRIGGER, user) == null
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
