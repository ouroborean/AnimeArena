extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.
var triggering = false
func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 5 Piercing damage to one enemy, then 15 Bleed damage to them next turn. This skill's initial Piercing damage permanently increases by 5 each time it is used."

func split_desc():
	return [
		"Deals 5 Piercing damage to target enemy (+5 per use)",
		["Next turn, that enemy takes 15 Bleed damage", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	if user.marked_by("Bloodthirsty Rampage"):
		var valid_targets = []
		for character in context['enemy_team'].characters:
			if not character.dead and not character.banished and not character.is_invuln(self):
				valid_targets.append(character)
		if len(valid_targets) > 0:
			var roll = user.battle.roll(0, len(valid_targets) - 1)
			var random_target1 = valid_targets[roll]
			
			var roll2 = user.battle.roll(0, len(valid_targets) - 1)
			var random_target2 = valid_targets[roll2]
			user.targeter.clear_targets()
			user.targeter.targets.append(random_target1)
			user.targeter.targets.append(random_target2)
		else:
			return
	
	# Initial Piercing damage ramps by 5 for each prior use, tracked by a stacking "Tentacle Pierce"
	# mark on Kaneki (distinct from the same-named Bleed DoT, which is a DAMAGE effect on the target).
	var tracker = user.has_effect("Tentacle Pierce", EffectType.Type.MARK, user)
	var stacks = tracker.stacks if tracker else 0
	var initial = 5 + 5 * stacks

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, initial, DamageType.Type.PIERCING)
		if target.has_effect("Tentacle Pierce", EffectType.Type.DAMAGE, user):
			user.manually_advance_mission(7, 1)
		var duration = 3
		var damage_eff = Effect.damage_effect(15, DamageType.Type.BLEED, duration)
		damage_eff.set_source(self)
		damage_eff.unique_render_id = int(Time.get_ticks_msec())
		damage_eff.last_turn_only = true
		damage_eff.remove_on_death = false
		Character.add_hostile_effect(context, user, target, damage_eff)

	# Gain 1 stack per target struck, so a single Bloodthirsty Rampage cast (2 targets) grants 2 stacks.
	var gained = len(user.targeter.targets)
	if gained > 0:
		if tracker == null:
			tracker = Effect.mark(-1, "Tentacle Pierce's initial damage is increased by 5 per stack.")
			tracker.stackable = true
			tracker.display_stacks = true
			tracker.stacks = 0
			tracker.set_source(self)
			Character.add_allied_effect(context, user, user, tracker)
		tracker.stacks += gained


func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	if user.marked_by("Bloodthirsty Rampage"):
		variations += behavior_self_panic_button(context, 100)
	else:
		variations += behavior_single_target_damage(context, 35)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	if user.marked_by("Bloodthirsty Rampage"):
		default_self_target_function(user, battle)
	else:
		default_hostile_target_function(user, battle)
	
