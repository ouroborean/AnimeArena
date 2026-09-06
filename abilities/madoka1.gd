extends Ability

var base_damage = 15


#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 damage to one enemy. This skill deals 5 additional damage for each Shield or Nullify effect on Madoka and her target."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		["+5 damage for each Shield or Nullify effect on Madoka and on the target", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var barrier_count = len(user.effects.get_effects_by_type(EffectType.Type.BARRIER))
	var shield_count = len(user.effects.get_effects_by_type(EffectType.Type.SHIELD))
	
	for target in user.targeter.targets:
		var enemy_barrier_count = len(target.effects.get_effects_by_type(EffectType.Type.BARRIER))
		var enemy_shield_count = len(target.effects.get_effects_by_type(EffectType.Type.SHIELD))
		
		var mod_damage = base_damage
		mod_damage += barrier_count * 5
		mod_damage += shield_count * 5
		mod_damage += enemy_barrier_count * 5
		mod_damage += enemy_shield_count * 5
		
		Character.resolve_damage(context, target, mod_damage, DamageType.Type.NORMAL)
		
		
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	var barrier_count = len(user.effects.get_effects_by_type(EffectType.Type.BARRIER))
	var shield_count = len(user.effects.get_effects_by_type(EffectType.Type.SHIELD))
	for character in context['enemy_team'].characters:
		var enemy_barrier_count = len(character.effects.get_effects_by_type(EffectType.Type.BARRIER))
		var enemy_shield_count = len(character.effects.get_effects_by_type(EffectType.Type.SHIELD))
		
		var total_mod = barrier_count + shield_count + enemy_barrier_count + enemy_shield_count
		total_mod = total_mod * 10
		
		if (not character.is_invuln(self)) and not (character.dead or character.banished):
			var missing_hp = 100 - character.health.hp
			variations.append([100 + int(missing_hp) + total_mod, [user, self, [character]]])
		if len(variations) == 0:
			variations.append([0, [user, "PASS", []]])
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
