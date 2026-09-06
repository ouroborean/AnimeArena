extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to all enemies. The following 2 turns, Frankenstein will ignore non-damage effects and will use Bridal Chest on a random enemy every turn."

func split_desc():
	return [
		"Deals 20 damage to all enemies",
		["For the next 2 turns, Frankenstein ignores negative non-damage effects and uses Bridal Chest on a random enemy", Color.CADET_BLUE],
		["Deals 5 more damage while Galvanism is active", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
	var ignore = Effect.ignore_non_damage_effect(4)
	ignore.set_source(self)
	Character.add_allied_effect(context, user, user, ignore)
	var tick = Effect.trigger_effect(Trigger.always(rampage_trigger), EffectType.Type.TICKING_TRIGGER, 5, "Frankenstein will use Bridal Chest on a random enemy.")
	tick.set_source(self)
	tick.damage_type = DamageType.Type.NORMAL
	Character.add_allied_effect(context, user, user, tick)
	
func rampage_trigger(context):
	var valid_targets = []
	for character in context['enemy_team'].characters:
		if not character.dead and not character.banished and not character.is_invuln(self):
			valid_targets.append(character)
	if len(valid_targets) > 0:
		
		var cooldown_mod = 1
		if user.marked_by("Galvanism", user):
			cooldown_mod += 1
		user.manually_advance_mission(7, cooldown_mod)
		var roll = user.battle.roll(0, len(valid_targets) - 1)
		var target = valid_targets[roll]
		Character.resolve_effect_damage(context, context['effect'], target, base_damage, DamageType.Type.NORMAL)
		var valid_skills = []
		for ability in target.moveset.display_abilities():
			valid_skills.append(ability)
		var skill_roll = user.battle.roll(0, len(valid_skills) - 1)
		valid_skills[skill_roll].cooldown_remaining += cooldown_mod
		if target.marked_by("Bridal Chest"):
			user.manually_advance_mission(9, 1)
		else:
			var mark = Effect.mark(1, "")
			mark.set_source(self)
			mark.system = true
			Character.add_hostile_effect(context, user, target, mark, true)

func extra_damage_calc(damager, target, damage):
	if damager.marked_by("Galvanism", damager):
		return damage + 5
	return damage

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []

	variations += behavior_hostile_aoe_damage(context, 70)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
