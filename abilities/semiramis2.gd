extends Ability
var base_damage = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 Affliction damage to all enemies for 3 turns. Affected enemies can remove this effect by ending their turn while Invulnerable, and if it expires normally, the target is stunned for 1 turn."

func split_desc():
	return [
		"Deals 10 Affliction damage to all enemies for 3 turns",
		["Affected enemies can remove this effect by ending their turn while Invulnerable", Color.CADET_BLUE],
		["If it expires normally, the target is stunned for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.AFFLICTION, 5, false)
		damage_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_eff)
		var trigger = Effect.trigger_effect(Trigger.always(effect_expire_trigger), EffectType.Type.TICKING_TRIGGER, 5, "If this skill ends naturally, this character will be stunned.")
		trigger.set_source(self)
		Character.add_hostile_effect(context, user, target, trigger)
		var cleanse_trigger = Effect.trigger_effect(Trigger.always(remove_trigger), EffectType.Type.END_OF_TURN_TRIGGER, 5, "If this character ends their turn while Invulnerable, this skill will end.")
		cleanse_trigger.set_source(self)
		Character.add_hostile_effect(context, user, target, cleanse_trigger)
		
func remove_trigger(context):
	var enemy = context['target']
	var semiramis = context['effect'].user
	var target_invuln = Condition.is_invuln(enemy)
	if target_invuln.satisfied(context):
		enemy.effects.full_remove_effect_by_name("Mystical Beast - Hydra", semiramis)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func effect_expire_trigger(context):
	if context['effect'].duration > 1:
		return
	var trigger = Effect.stun_effect(2)
	trigger.set_source(self)
	Character.add_hostile_effect(context, user, context['effect'].target, trigger)
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 50, 1.2)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
