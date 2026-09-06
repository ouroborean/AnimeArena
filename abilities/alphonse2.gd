extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "The next time target ally deals new damage, they deal 15 piercing damage to their primary target. Cannot target a currently affected ally."

func split_desc():
	return [
		"Target ally deals 20 Piercing damage to their primary target the next time they deal new damage",
		"Cannot target a currently affected ally"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trigger = Effect.trigger_effect(Trigger.always(weapon_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, func (eff): return "The next time this character deals new damage, Alphonse will deal 20 piercing damage to their target.")
		trigger.set_source(self)
		trigger.cleansable = true
		trigger.remove_on_death = false
		Character.add_allied_effect(context, user, target, trigger)

func weapon_trigger(context):
	var damager = context['owner']
	var alphonse = context['effect'].user
	var damaged = context['target']
	var source = context['source']
	if source is Effect:
		return
	alphonse.manually_advance_mission(7, 1)
	var new_context = QueryContext.from_game_state(alphonse, alphonse.battle)
	new_context['source'] = context['effect']
	Character.resolve_effect_damage(new_context, context['effect'], damaged, base_damage, DamageType.Type.PIERCING)
	damager.effects.erase_effect(context['effect'])

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.marked_by("Transmutation Circle", user)
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 85)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if not character.effects.has_effect("Weapon Alchemy", EffectType.Type.DAMAGE_DEALT_TRIGGER, user):
			check_allied_target(user, character, context)
