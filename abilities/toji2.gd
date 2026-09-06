extends Ability

# Playful Cloud — a 2-turn damage-over-time that also taxes the victim's skills +1 Green.
# While the DoT is active, Toji's passive (Heavenly Restriction) extends it whenever the
# victim uses a Harmful skill on Toji — see character/toji.gd toji_extend_playful_cloud.

var base_damage = 15

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 15 damage per turn to target enemy for 2 turns",
		["While affected, the target's skills cost 1 more Green energy", Color.CADET_BLUE],
		["Whenever the target uses a Harmful skill on Toji, this duration increases by 1", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var dot = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 3)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)
		var green_tax = Effect.cost_mod_effect(1, 4, Energy.Type.GREEN, [])
		green_tax.set_source(self)
		Character.add_hostile_effect(context, user, target, green_tax)
		Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 45)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
