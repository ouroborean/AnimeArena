extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Tokoyami gains 1 stack of Black Abyss each turn (Max 3)",
		["At 3 stacks, Sabbath's cooldown is increased by 1", Color.AQUA],
		["He loses 1 stack if he's Stunned, Silenced, or Blinded, and will not gain a stack the turn one of these effects is applied", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(-1, "Tokoyami will gain 1 stack of Black Abyss if he isn't Stunned, Silenced, or Blinded.")
	mark.set_source(self)
	mark.display_mag = true
	Character.add_allied_effect(context, user, user, mark)
	var label = Effect.trigger_effect(Trigger.always(abyss_tick), EffectType.Type.TICKING_TRIGGER, -1, "If Tokoyami is Stunned, Silenced, or Blinded, he will lose 1 stack of Black Abyss.")
	label.set_source(self)
	Character.add_allied_effect(context, user, user, label)

func abyss_tick(context):
	var mark = user.has_effect("Black Abyss", EffectType.Type.MARK)
	if mark.mag >= 3:
		return
	if user.has_stuns() or user.blind_check() or user.is_silenced():
		return
	mark.mag += 1
	user.manually_advance_mission(6, 1)
	if mark.mag == 3:
		var target_change1 = Effect.target_change_effect(TargetType.Type.ALL, -1, ["Sabbath", "Covert Black-Ops Arms", "Dark Aura"])
		target_change1.set_source(self)
		Character.add_allied_effect(context, user, user, target_change1)
		var sabbath_cooldown = Effect.cooldown_mod(1, -1, ["Sabbath"])
		sabbath_cooldown.set_source(self)
		Character.add_allied_effect(context, user, user, sabbath_cooldown)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
