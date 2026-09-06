extends Ability

var base_damage = 20
# The recoil is now a flat literal rather than a share of base_damage: the enemy hit and the
# self/wielder hit are two independent numbers in the player-facing text (20 and 10).
var recoil_damage = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 affliction damage to one enemy and Soul. If an ally is wielding Soul, the damage is split between them."

func split_desc():
	return [
		"Deals 20 Affliction damage to one enemy",
		["Deals 10 Affliction damage to Soul", Color.DIM_GRAY],
		["If an ally is wielding Soul, that ally takes the 10 instead", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Nightmare Sonata's bonus applies to the ENEMY hit. It used to be folded into mod_damage,
	# which only fed the self/ally half, so it had never once boosted the damage the skill is
	# described as dealing; the recoil is now a fixed 10 and boosting THAT would make Sonata a
	# self-nerf.
	var target_damage = base_damage
	if user.marked_by("Nightmare Sonata", user):
		target_damage += 10

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, target_damage, DamageType.Type.AFFLICTION)

	# The wielder is resolved HERE, not at cast time: Scythe Transformation can move to another
	# ally, lapse, or be cleansed between the two. Whoever holds it eats the recoil INSTEAD of
	# Soul — when wielded, Soul takes 0 (this used to be a 50/50 split).
	var recoil_target = user
	for character in user.team.characters:
		if character.dead or character.banished:
			continue
		if character.has_effect("Scythe Transformation", EffectType.Type.MARK, user):
			recoil_target = character
			break
	Character.resolve_damage(context, recoil_target, recoil_damage, DamageType.Type.AFFLICTION)


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
