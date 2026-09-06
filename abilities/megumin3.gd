extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 65 Piercing damage to target enemy",
		["For the next 3 turns, Megumin cannot use skills other than Face-first Slide", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 65, DamageType.Type.PIERCING)
	if user.has_effect("Crimson Incantation", EffectType.Type.COST_MOD):
		if user.has_effect("Crimson Incantation", EffectType.Type.COST_MOD).mag <= -4:
			user.manually_advance_mission(7, 1)
		user.effects.erase_effect(user.has_effect("Crimson Incantation", EffectType.Type.COST_MOD))
	var mark = Effect.mark(7, "Megumin can only use Face-first Slide")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Explosion")
	
func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 300)
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var bypass_state = false
	if user.marked_by("Waga wa Megumin!"):
		bypass_state = true
	default_hostile_target_function(user, battle, bypass_state)
