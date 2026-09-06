extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 Piercing damage to all enemies. If this ability hits all living enemies, Spirit Dive: Sylph has its cost reduced by 1 blue energy until its next use."

func split_desc():
	return [
		"Deals 10 Piercing damage to all enemies",
		["If it hits all living enemies, Spirit Dive: Sylph costs 1 less blue energy until its next use", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var damaged_enemies = []
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		damaged_enemies.append(target)
	for character in context['enemy_team'].characters:
		if not character in damaged_enemies and not (character.dead or character.banished):
			return
	var cost_mod = Effect.cost_mod_effect(-1, -1, Energy.Type.BLUE, ["Spirit Dive: Sylph"])
	cost_mod.set_source(self)
	cost_mod.stackable = true
	cost_mod.display_stacks = true
	cost_mod.per_stack = true
	Character.add_allied_effect(context, user, user, cost_mod)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
