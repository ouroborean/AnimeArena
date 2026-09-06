extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Toga deals 10 Bleed damage to one enemy for three turns, gaining one stack of Twisted Love each turn."

func split_desc():
	return [
		"Deals 10 Bleed damage to one enemy for 3 turns",
		["Toga gains 1 stack of Twisted Love each turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.BLEED)
		var trigger = Effect.trigger_effect(Trigger.always(syringe_trigger), EffectType.Type.TICKING_TRIGGER, 5, "This character will take 10 Bleed damage and Toga will gain 1 stack of Twisted Love.")
		trigger.set_source(self)
		trigger.damage_type = DamageType.Type.BLEED   # effectively a Bleed DoT — not dropped by ignore-non-damage / Ainz's negate
		Character.add_hostile_effect(context, user, target, trigger)
	var mark = Effect.mark(-1, func (eff): return "Toga has " + str(eff.stack_count()) + " stacks of Twisted Love.")
	mark.set_source(user.moveset.base_abilities[3])
	mark.invisible = true
	mark.stackable = true
	mark.display_stacks = true
	Character.add_allied_effect(context, user, user, mark)
	user.manually_advance_mission(6, 1)
	

func syringe_trigger(context):
	
	Character.resolve_effect_damage(context, context['source'], context['source'].target, base_damage, DamageType.Type.BLEED)
	
	var mark = Effect.mark(-1, func (eff): return "Toga has " + str(eff.stack_count()) + " stacks of Twisted Love.")
	mark.set_source(user.moveset.base_abilities[3])
	mark.invisible = true
	mark.stackable = true
	mark.display_stacks = true
	Character.add_allied_effect(context, user, user, mark)
	user.manually_advance_mission(6, 1)

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
