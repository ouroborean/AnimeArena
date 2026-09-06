extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Eren marks one selected enemy and one random enemy. This skill stacks and cannot be removed. When Eren's health reaches 50 or below all marked enemies will take 10 damage for every stack they have. When triggered, Eren will heal 5 health for each stack of this skill and all of his skills swap to alternates for the rest of the game. This skill is invisible."

func split_desc():
	return [
		"Permanently marks target enemy and 1 random enemy",
		"When Eren's HP reaches 50 or less, Eren heals 5 HP per mark, and deals 10 damage to marked enemies for each mark they have",
		["Swaps to Titan Heal", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mark_eff = Effect.mark(-1, "When Eren's health reaches 50 or below, this character will take 10 damage per stack of this effect they have.")
		mark_eff.invisible = true
		mark_eff.stackable = true
		mark_eff.display_stacks = true
		mark_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, mark_eff)
	
	
	var targets = []
	for char in battle.all_characters():
		var hostile = Condition.is_hostile(user, char)
		if hostile.satisfied(context) and not (char.dead or char.banished):
			targets.append(char)
	if len(targets) > 0:
		var chosen_index = battle.roll(0, len(targets) - 1)
		var random_target = targets[chosen_index]
		var mark_eff2 = Effect.mark(-1, "When Eren's health reaches 50 or below, this character will take 10 damage per stack of this effect they have.")
		mark_eff2.invisible = true
		mark_eff2.stackable = true
		mark_eff2.display_stacks = true
		mark_eff2.set_source(self)
		Character.add_hostile_effect(context, user, random_target, mark_eff2, true)
	
	var transforming = Condition.has_effect(user, "Titan Transformation", EffectType.Type.HEALTH_CHANGE_TRIGGER, user)
	if not transforming.satisfied(context):
		
		var trigger_desc = func (eff):
			return "If Eren's health reaches 50 or below, he will deal 10 damage to each enemy per stack of Titan Transformation they have, heal 5 health for each stack triggered, and swap all his skills to their alternate versions."
		var trigger = Trigger.from_condition(Condition.health_is(user, -1, 50), transformation_trigger)
		var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.HEALTH_CHANGE_TRIGGER, -1, trigger_desc)
		trigger_eff.set_source(self)
		trigger_eff.invisible = true
		Character.add_allied_effect(context, user, user, trigger_eff)
		
		
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_spread_out(context, "Titan Transformation", EffectType.Type.MARK, 110, 0.75)
	
	return variations
	
func transformation_trigger(context):
	
	user.manually_advance_mission(10, 1)
	var swap1 = Effect.ability_swap_effect(5, 0, context['owner'], -1)
	swap1.set_source(self)
	var swap2 = Effect.ability_swap_effect(6, 1, context['owner'], -1)
	swap2.set_source(self)
	var swap3 = Effect.ability_swap_effect(7, 2, context['owner'], -1)
	swap3.set_source(self)
	var swap4 = Effect.ability_swap_effect(4, 3, context['owner'], -1)
	swap4.set_source(self)
	var prof_swap = Effect.portrait_change_effect(0, -1)
	prof_swap.set_source(self)
	
	Character.add_allied_effect(context, context['owner'], context['owner'], swap1)
	Character.add_allied_effect(context, context['owner'], context['owner'], swap2)
	Character.add_allied_effect(context, context['owner'], context['owner'], swap3)
	Character.add_allied_effect(context, context['owner'], context['owner'], swap4)
	Character.add_allied_effect(context, context['owner'], context['owner'], prof_swap)
	var total_stacks = 0
	for character in context['owner'].battle.all_characters():
		if character.effects.has_effect("Titan Transformation", EffectType.Type.MARK, context['owner']):
			var stack_count = character.effects.has_effect("Titan Transformation", EffectType.Type.MARK, context['owner']).stack_count()
			total_stacks += stack_count
			Character.resolve_effect_damage(context, context['source'], character, stack_count * 10, DamageType.Type.NORMAL)
			character.effects.remove_effect("Titan Transformation", EffectType.Type.MARK, context['owner'])
	
	context['owner'].effects.remove_effect("Titan Transformation", EffectType.Type.HEALTH_CHANGE_TRIGGER, context['owner'])
	
	Character.resolve_effect_healing(context, swap1, context['owner'], total_stacks * 5)
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
