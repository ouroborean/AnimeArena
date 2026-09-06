extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 3 turns, Ryohei will ignore harmful stun effects and changes to his ability costs. During this time, Maximum Cannon becomes piercing, Ryohei gains 1 stack of To The Extreme!! each turn, and Kangaryu also grants 10 damage reduction every turn it is active. "

func split_desc():
	return [
		["For 3 turns, Ryohei ignores harmful stun effects and cost changes", Color.CADET_BLUE],
		["Maximum Cannon becomes piercing", Color.CADET_BLUE],
		["Ryohei gains 1 stack of To The Extreme!! each turn", Color.CADET_BLUE],
		["Kangaryu also grants 10 damage reduction every turn it is active", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var stun_ign = Effect.ignore_effect_effect(6, EffectType.Type.STUN)
	stun_ign.set_source(self)
	var cost_ign = Effect.ignore_effect_effect(6, EffectType.Type.COST_MOD)
	cost_ign.set_source(self)
	var mark = Effect.mark(6, "Maximum Cannon will deal piercing damage and Kangaryu will grant affected allies 10 damage reduction.")
	mark.set_source(self)
	var tick = Effect.trigger_effect(Trigger.always(ticking_trigger), EffectType.Type.TICKING_TRIGGER, 5, "Ryohei will gain 1 stack of To The Extreme!!")
	tick.set_source(self)
	
	var ryohei = user
	var mark2 = user.has_effect("To the Extreme!!", EffectType.Type.MARK, user)

	if mark2:
		mark2.stacks += 1
	else:
		mark2 = Effect.mark(-1, func (eff): return "Ryohei has " + str(eff.stacks) + " stacks of To the Extreme!! (" + str(eff.mag) + "/20)")
		mark2.stackable = true
		mark2.stacks = 1
		# Name the stack mark "To the Extreme!!" (via base_abilities[3]), NOT "Vongola Headgear" (self),
		# so it's the SAME mark every lookup / Kangaryu's consume / the 20-damage trigger reference.
		mark2.set_source(user.moveset.base_abilities[3])
		Character.add_allied_effect(context, ryohei, ryohei, mark2)
	
	var damage_mod = Effect.damage_mod_effect(15, -1, ["Maximum Cannon"])
	damage_mod.stackable = true
	damage_mod.per_stack = true
	damage_mod.unique_render_id = 5
	damage_mod.display_stacks = true
	damage_mod.set_source(user.moveset.base_abilities[3])
	var empty = Effect.empty(-1, func (eff): return "Kangaryu will last for " + str(eff.stacks) + " more turns.")
	empty.set_source(user.moveset.base_abilities[3])
	empty.stackable = true
	empty.unique_render_id = 5
	empty.display_stacks = true
	var cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM, ["Maximum Cannon", "Kangaryu"])
	cost_mod.set_source(user.moveset.base_abilities[3])
	cost_mod.stackable = true
	cost_mod.per_stack = true
	cost_mod.unique_render_id = 5
	cost_mod.display_stacks = true
	Character.add_allied_effect(context, ryohei, ryohei, damage_mod)
	Character.add_allied_effect(context, ryohei, ryohei, empty)
	Character.add_allied_effect(context, ryohei, ryohei, cost_mod)
	
	Character.add_allied_effect(context, user, user, tick)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, stun_ign)
	Character.add_allied_effect(context, user, user, cost_ign)

func ticking_trigger(context):
	var ryohei = context['effect'].target
	var mark = ryohei.has_effect("To the Extreme!!", EffectType.Type.MARK, ryohei)
	if mark:
		mark.stacks += 1
	else:
		mark = Effect.mark(-1, func (eff): return "Ryohei has " + str(eff.stacks) + " stacks of To the Extreme!! (" + str(eff.mag) + "/20)")
		mark.stackable = true
		mark.stacks = 1
		mark.set_source(user.moveset.base_abilities[3])   # "To the Extreme!!", not "Vongola Headgear"
		Character.add_allied_effect(context, ryohei, ryohei, mark)
		
	var damage_mod = Effect.damage_mod_effect(15, -1, ["Maximum Cannon"])
	damage_mod.stackable = true
	damage_mod.per_stack = true
	damage_mod.unique_render_id = 5
	damage_mod.display_stacks = true
	damage_mod.set_source(user.moveset.base_abilities[3])
	var empty = Effect.empty(-1, func (eff): return "Kangaryu will last for " + str(eff.stacks) + " more turns.")
	empty.set_source(user.moveset.base_abilities[3])
	empty.stackable = true
	empty.unique_render_id = 5
	empty.display_stacks = true
	var cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM, ["Maximum Cannon", "Kangaryu"])
	cost_mod.set_source(user.moveset.base_abilities[3])
	cost_mod.stackable = true
	cost_mod.per_stack = true
	cost_mod.unique_render_id = 5
	cost_mod.display_stacks = true
	Character.add_allied_effect(context, ryohei, ryohei, damage_mod)
	Character.add_allied_effect(context, ryohei, ryohei, empty)
	Character.add_allied_effect(context, ryohei, ryohei, cost_mod)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
