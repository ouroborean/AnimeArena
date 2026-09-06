extends Ability


func describe(user):
	return ""

func split_desc():
	return [
		"Deals 15 damage to target enemy and Empowers her skills for 1 turn",
		["While Empowered, deals 25 damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = make_context(battle)
	var base_damage = 15
	if user.marked_by("Shabon Spray"):
		base_damage = 25
	deal_damage_to_targets(context, base_damage)
	var mark = Effect.mark(3, "Mercury's skills are Empowered.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	var cooldown_mod = Effect.cooldown_mod(-3, 3, ["Shine Aqua Illusion"])
	cooldown_mod.set_source(self)
	cooldown_mod.system = true
	Character.add_allied_effect(context, user, user, cooldown_mod)
	

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context)

func target(user, battle):
	default_hostile_target_function(user, battle)
