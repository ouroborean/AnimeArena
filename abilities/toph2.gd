extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Stuns target enemy's Physical skills for 2 turns and deals 10 damage per turn while active",
		["If Toph uses Stone Pillar on that enemy, they will lose 1 random energy", Color.CADET_BLUE],
		["While Toph has Metal Armor, her skills deal 5 more damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		var stun = Effect.stun_effect(2, ["Physical"])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
		var ticking = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, 3, "This character's Physical skills will be stunned for 1 turn")
		ticking.set_source(self)
		Character.add_hostile_effect(context, user, target, ticking)
		var mark = Effect.mark(3, "Stone Pillar will remove 1 random energy from this character.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)
		var dot = Effect.damage_effect(10, DamageType.Type.NORMAL, 3)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)
	var mark = Effect.mark(3, "Toph is using Earthen Shackles. If she is stunned, it will be paused.")
	mark.set_source(self)
	Character.add_hostile_effect(context, user, user, mark)

func tick_trigger(context):
	var stun = Effect.stun_effect(2, ["Physical"])
	stun.set_source(self)
	Character.add_hostile_effect(context, user, context.target, stun)
	var mark = Effect.mark(3, "Stone Pillar will remove 1 random energy from this character.")
	mark.set_source(self)
	Character.add_hostile_effect(context, user, context.target, mark)

func extra_damage_calc(damager, target, damage):
	if damager.has_effect("Metal Armor", EffectType.Type.SHIELD, damager):
		return damage + 5
	return damage

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []

	variations += behavior_single_target_stun(context, 45)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
