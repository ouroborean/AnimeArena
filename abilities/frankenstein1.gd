extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to one enemy, and increases the remaining cooldown of one of their skills by 1."

func split_desc():
	return [
		"Deals 20 damage to target enemy and increases the remaining cooldown of one of their skills by 1",
		["Deals 5 more damage while Galvanism is active", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var cooldown_mod = 1
	if user.marked_by("Galvanism", user):
		cooldown_mod += 1
	user.manually_advance_mission(7, cooldown_mod)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var valid_skills = []
		for ability in target.moveset.display_abilities():
			valid_skills.append(ability)
		var roll = battle.roll(0, len(valid_skills) - 1)
		valid_skills[roll].cooldown_remaining += cooldown_mod
		if target.marked_by("Bridal Rampage"):
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

	variations += behavior_single_target_damage(context, 30)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
