extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ryohei gains a stack of To The Extreme!!, empowering his skills. For the rest of the game, whenever Ryohei receives 20 total damage, he gains a stack of To The Extreme!!"

func split_desc():
	return [
		["Ryohei gains a stack of To The Extreme!!, empowering his skills", Color.CADET_BLUE],
		["For the rest of the game, every 20 total damage Ryohei receives grants a stack of To The Extreme!!", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger = Effect.trigger_effect(Trigger.always(extreme_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "Every 20 total damage Ryohei receives, he gains a stack of To The Extreme!!, empowering his abilities.")
	trigger.set_source(self)
	var mark = _build_mark(1)
	var damage_mod = Effect.damage_mod_effect(15, -1, ["Maximum Cannon"])
	damage_mod.stackable = true
	damage_mod.per_stack = true
	damage_mod.display_stacks = true
	damage_mod.unique_render_id = 5
	damage_mod.set_source(self)
	var empty = Effect.empty(-1, func (eff): return "Kangaryu will last for " + str(eff.stacks) + " more turns.")
	empty.set_source(self)
	empty.stackable = true
	empty.unique_render_id = 5
	empty.display_stacks = true
	var cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM, ["Maximum Cannon", "Kangaryu"])
	cost_mod.set_source(self)
	cost_mod.stackable = true
	cost_mod.unique_render_id = 5
	cost_mod.per_stack = true
	cost_mod.display_stacks = true
	Character.add_allied_effect(context, user, user, damage_mod)
	Character.add_allied_effect(context, user, user, empty)
	Character.add_allied_effect(context, user, user, cost_mod)
	Character.add_allied_effect(context, user, user, trigger)
	Character.add_allied_effect(context, user, user, mark)

## The accumulator MARK, so extreme_trigger can put one back after a buff-strip takes it.
func _build_mark(start_stacks: int):
	var mark = Effect.mark(-1, func (eff): return "Ryohei has " + str(eff.stacks) + " stacks of To the Extreme!! (" + str(eff.mag) + "/20)")
	mark.stackable = true
	mark.stacks = start_stacks
	mark.set_source(self)
	return mark


func extreme_trigger(context):
	var ryohei = context['effect'].target
	if ryohei == null or not is_instance_valid(ryohei) or ryohei.battle == null:
		return
	var mark = ryohei.has_effect("To the Extreme!!", EffectType.Type.MARK, ryohei)
	if mark == null:
		# A BUFF-STRIP splits this pair. Effect.mark leaves cleansable at its default true, but
		# trigger_effect sets cleansable = (dur >= 0), so THIS permanent trigger is cleanse-proof and
		# outlives its own accumulator. inuyasha3 cleanses the target and deals damage on the very
		# next line, which is exactly how this crashed on the deployed server.
		#
		# Rebuild at zero rather than dying: the strip legitimately took the earned stacks, but the
		# passive is permanent and has to keep counting the next 20.
		var qc = QueryContext.from_game_state(ryohei, ryohei.battle)
		Character.add_allied_effect(qc, ryohei, ryohei, _build_mark(0))
		mark = ryohei.has_effect("To the Extreme!!", EffectType.Type.MARK, ryohei)
		if mark == null:
			return
	mark.mag += context['value']
	while mark.mag >= 20:
		mark.mag -= 20
		mark.stacks += 1
		var damage_mod = Effect.damage_mod_effect(15, -1, ["Maximum Cannon"])
		damage_mod.stackable = true
		damage_mod.per_stack = true
		damage_mod.display_stacks = true
		damage_mod.unique_render_id = 5
		damage_mod.set_source(self)
		var empty = Effect.empty(-1, func (eff): return "Kangaryu will last for " + str(eff.stacks) + " more turns.")
		empty.set_source(self)
		empty.stackable = true
		empty.unique_render_id = 5
		empty.display_stacks = true
		var cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM, ["Maximum Cannon", "Kangaryu"])
		cost_mod.set_source(self)
		cost_mod.stackable = true
		cost_mod.per_stack = true
		cost_mod.unique_render_id = 5
		cost_mod.display_stacks = true
		Character.add_allied_effect(context, ryohei, ryohei, damage_mod)
		Character.add_allied_effect(context, ryohei, ryohei, empty)
		Character.add_allied_effect(context, ryohei, ryohei, cost_mod)
		
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 250)
	
	return variations
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	# Gate on the TRIGGER, not the mark. Two bugs came from keying on the mark:
	#   * after a buff-strip the mark is gone while the cleanse-proof trigger lives, so a recast
	#     stored a SECOND permanent trigger (it is neither stackable nor refresh, so add_effect falls
	#     through to storing a duplicate) and every hit then accrued stacks twice, compounding;
	#   * Vongola Headgear (ryohei3) creates the same mark, which permanently locked this skill out
	#     and meant the 20-damage trigger could never be installed for the rest of the match.
	return user.has_effect("To the Extreme!!", EffectType.Type.DAMAGE_RECEIVE_TRIGGER, user) == null
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
