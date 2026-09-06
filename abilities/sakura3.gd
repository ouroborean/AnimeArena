extends Ability

var base_damage = 25

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sakura permanently marks herself or an ally. The first enemy to use a new harmful skill on them will receive 25 damage and be stunned for 1 turn. Invisible until triggered."

func split_desc():
	return [
		"For 3 turns, Sakura ignores stun effects and Cherry Blossom Fist deals 10 more damage",
		["During this time, this skill is replaced by Cherry Blossom Crash", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var stun_ignore = Effect.ignore_effect_effect(6, EffectType.Type.STUN)
	stun_ignore.set_source(self)
	Character.add_allied_effect(context, user, user, stun_ignore)
	var damage_mod = Effect.damage_mod_effect(10, 5, ["Cherry Blossom Fist"])
	damage_mod.set_source(self)
	Character.add_allied_effect(context, user, user, damage_mod)
	var swap = Effect.ability_swap_effect(4, 2, user, 5)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 50)
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
