extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 damage to one enemy for 2 turns. If that enemy is affected by Tsubaki: Enchanted Sword Mode, they take 15 Piercing damage whenever they damage Black Star with a new skill."

func split_desc():
	return [
		"Deals 10 damage to target enemy for 2 turns",
		"If affected enemy is taunted by Tsubaki: Enchanted Sword Mode, deals 15 Piercing damage to them when they deal new damage to Black Star"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 3)
		damage_eff.set_source(self)
		
		var trigger = Effect.trigger_effect(Trigger.always(thorns_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, 4, func (eff): return "If this character deals new damage to Black Star while affected by Tsubaki: Enchanted Sword Mode, they will take 15 Piercing damage.")
		trigger.set_source(self)
		
		Character.add_hostile_effect(context, user, target, damage_eff, user.marked_by("Tsubaki: Smoke Bomb", user))
		Character.add_hostile_effect(context, user, target, trigger, user.marked_by("Tsubaki: Smoke Bomb", user))

func thorns_trigger(context):
	var blackstar = context['effect'].user
	var damage_target = context['owner']
	var damage_source = context['source']
	var thorns_eff = context['effect']
	if damage_source is Effect:
		return
	if damage_target.has_effect("Tsubaki: Enchanted Sword Mode", EffectType.Type.TAUNT, blackstar):
		var new_context = QueryContext.from_effect_end(thorns_eff)
		Character.resolve_effect_damage(new_context, thorns_eff, damage_target, 15, DamageType.Type.PIERCING)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35, 1.1, context['owner'].marked_by("Tsubaki: Smoke Bomb", context['owner']))
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, user.marked_by("Tsubaki: Smoke Bomb", user))
