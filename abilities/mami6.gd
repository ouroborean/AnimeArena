extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mami permanently ignores stun effects and gains 1 stack of this effect each turn. While she has at least 3 stacks, Tiro Finale can be used. While she has at least 4 stacks, Tiro Concert deals 5 more damage and she gains 1 more stack each turn. When Mami has 8 stacks of this effect, she instantly dies."

func split_desc():
	return [
		"Mami permanently ignores stun effects and gains 1 stack of Soul Gem: Mami per turn",
		"While she has 3+ stacks, Tiro Finale can be used",
		"While she has 4+ stacks, Tiro Concert deals +5 damage",
		"When she has 8+ stacks, she instantly dies"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var passive_mark = Effect.mark(-1, "If Mami has 8 stacks of this skill, she will instantly die.")
	passive_mark.set_source(self)
	passive_mark.mag = 0
	passive_mark.display_mag = true
	passive_mark.cleansable = false
	Character.add_allied_effect(context, user, user, passive_mark)
	var stun_ignore = Effect.ignore_effect_effect(-1, EffectType.Type.STUN)
	stun_ignore.set_source(self)
	stun_ignore.cleansable = false
	Character.add_allied_effect(context, user, user, stun_ignore)
	var ticking = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Mami will gain 1 stack of Soul Gem: Mami.")
	ticking.set_source(self)
	Character.add_allied_effect(context, user, user, ticking)

func tick_trigger(context):
	user.gain_corruption()
	


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
