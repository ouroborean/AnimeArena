extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Target enemy is permanently stunned and will take 10 true damage each turn. After applying this effect, Gray dies. This skill cannot be countered or reflected, and this death cannot be prevented with effects."

func split_desc():
	return [
		"Permanently stuns target enemy",
		["They take 10 true damage each turn for the rest of the game", Color.ORANGE_RED],
		["Gray then dies; this death cannot be prevented", Color.DIM_GRAY],
		["Cannot be countered or reflected", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.TRUE)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.TRUE, -1)
		damage_eff.set_source(self)
		damage_eff.remove_on_death = false
		var stun_eff = Effect.stun_effect(-1)
		stun_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, stun_eff)
		Character.add_hostile_effect(context, user, target, damage_eff)
	
	user.instant_kill(user, self)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	for character in context['enemy_team'].characters:
		var mod = (100 - context['owner'].health.hp) * 2
		if not character.is_invuln(self) and not (character.dead or character.banished):
			if character.ignoring_effect_type(EffectType.Type.STUN):
				mod -= 50
			variations.append([120 + mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
