extends Ability
var base_damage = 40
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 40 damage to target enemy, and 0 permanent Affliction damage to all enemies. This permanent damage can stack."

func split_desc():
	return [
		"Deals 40 damage to target enemy and 0 permanent Affliction damage to all enemies",
		"Permanent Affliction damage increased by Ace's total Damage Reduction"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var dr_effects = user.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION)
	var base_aff = 0
	for dr in dr_effects:
		base_aff += dr.mag
		user.manually_advance_mission(7, dr.mag)
	
	for target in user.targeter.targets:
		if target == user.targeter.main_target:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
		if base_aff < 0:
			return
		if not target.has_effect("Flame Emperor", EffectType.Type.DAMAGE):
			Character.resolve_damage(context, target, base_aff, DamageType.Type.AFFLICTION)
		var damage_eff = Effect.damage_effect(base_aff, DamageType.Type.AFFLICTION, -1)
		damage_eff.set_source(self)
		damage_eff.stackable = true
		damage_eff.stack_mag = true
		damage_eff.display_mag = true
		Character.add_hostile_effect(context, user, target, damage_eff)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_splash_aoe(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
