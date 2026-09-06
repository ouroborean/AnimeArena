extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 Piercing damage to one target. The following turn, this skill may be used again for 1 random, dealing the same damage and making Black Star invulnerable for 1 turn. While enhanced, this skill has a 2 turn cooldown."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy and enhances this skill for 1 turn",
		"While enhanced, this skill costs 1 Random, makes Black Star Invulnerable for 1 turn, and has +2 cooldown",
		["Swaps to The Unexplored Path during Tsubaki: Enchanted Sword Mode", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var marked = user.marked_by("Speed Star", user)
	
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	if marked:
		cooldown = 2
		var invuln = Effect.invuln_effect(2)
		invuln.set_source(self)
		Character.add_allied_effect(context, user, user, invuln)
	else:
		cooldown = 0
		var cost_change = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, 3, ["Speed Star"])
		cost_change.set_source(self)
		var mark = Effect.mark(3, func (eff): return "Speed Star will make Blackstar Invulnerable for 1 turn.")
		mark.set_source(self)
		var counter_ignore = Effect.ignore_counter_effect(3, ["Black Star Big Wave"])
		counter_ignore.set_source(self)
		Character.add_allied_effect(context, user, user, mark)
		Character.add_allied_effect(context, user, user, cost_change)
		Character.add_allied_effect(context, user, user, counter_ignore)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	var base_mod = 50
	if context['owner'].marked_by("Speed Star", context['owner']):
		base_mod += 35
	variations += behavior_single_target_damage(context, base_mod, 1.1, context['owner'].marked_by("Tsubaki: Smoke Bomb", context['owner']))
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, user.marked_by("Tsubaki: Smoke Bomb", user))
