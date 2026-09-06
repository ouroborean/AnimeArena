extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sayaka gains 1 stack of this skill each turn. While Sayaka has at least 6 stacks, she heals 5 health per turn per 20 health she is missing. Sayaka ignores effects that prevent her healing. If Sayaka reaches 12 stacks of this effect, she instantly dies."

func split_desc():
	return [
		"Sayaka ignores effects that prevent her healing and gains 1 stack of Soul Gem: Sayaka each turn",
		["With 6 or more stacks: Sayaka heals 5 HP each turn per 20 HP she is missing", Color.CADET_BLUE],
		["With 10 or more stacks: Sayaka instantly dies", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	seed_gem(user)
	var trigger = Effect.trigger_effect(Trigger.always(corruption_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Sayaka will gain 1 stack of Soul Gem: Sayaka. If she has at least 6 stacks, she will heal 5 health per 20 health she is missing.")
	trigger.set_source(self)
	# A revive clears the Soul Gem MARK (owner ruling) but must NOT clear the passive that feeds it:
	# system + remove_on_death = false is the only combination the death cleanse spares, and
	# display_system keeps the ticker on the wire so the tick panel still lists it.
	trigger.system = true
	trigger.display_system = true
	trigger.remove_on_death = false
	Character.add_allied_effect(context, user, user, trigger)
	
	
	var heal_trigger_desc = func (eff):
		var total_eff = eff.user.effects.has_effect("Hero Slash", EffectType.Type.HEALING_GIVEN_TRIGGER, user)
		return "Sayaka has restored " + str(total_eff.mag) + " health with her abilities."
	
	var heal_trigger_eff = Effect.trigger_effect(Trigger.always(heal_trigger), EffectType.Type.HEALING_GIVEN_TRIGGER, -1, heal_trigger_desc)
	heal_trigger_eff.mag = 0
	heal_trigger_eff.set_source(user.moveset.base_abilities[0])
	# Same reasoning as the ticker: this accumulator IS the Hero Slash scaling passive, and its own
	# heal_trigger dereferences it unguarded, so losing it to a death cleanse both kills the passive
	# and leaves a null-deref behind every later heal.
	heal_trigger_eff.system = true
	heal_trigger_eff.display_system = true
	heal_trigger_eff.remove_on_death = false
	Character.add_allied_effect(context, user, user, heal_trigger_eff)

# The gem MARK is death-cleansed by design, so it has to be re-plantable: after a revive the ticker
# is still running and would otherwise tick forever against a gem that no longer exists.
func seed_gem(user):
	if user.has_effect("Soul Gem: Sayaka", EffectType.Type.MARK):
		return
	var passive_mark = Effect.mark(-1, "If Sayaka has 10 stacks of this skill, she will instantly die.")
	passive_mark.set_source(self)
	passive_mark.mag = 0
	passive_mark.display_mag = true
	passive_mark.cleansable = false
	Character.add_allied_effect(QueryContext.from_game_state(user, user.battle), user, user, passive_mark)

func heal_trigger(context):
	var total_eff = context['owner'].effects.has_effect("Hero Slash", EffectType.Type.HEALING_GIVEN_TRIGGER, user)
	var buff_eff = context['owner'].effects.has_effect("Hero Slash", EffectType.Type.DAMAGE_MOD, user)
	
	total_eff.mag += context['value']
	var damage_boost_count = total_eff.mag / 20
	if damage_boost_count > 0:
		if buff_eff:
			buff_eff.stacks = damage_boost_count
		else:
			var new_buff = Effect.damage_mod_effect(5, -1, ["Hero Slash"])
			new_buff.set_source(user.moveset.base_abilities[0])
			new_buff.per_stack = true
			new_buff.stackable = true
			new_buff.display_stacks = true
			new_buff.stacks = damage_boost_count
			Character.add_allied_effect(context, user, user, new_buff)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func corruption_trigger(context):
	seed_gem(context['owner'])
	context['owner'].gain_corruption()
	if context['owner'].effects.has_effect("Soul Gem: Sayaka", EffectType.Type.MARK, context['owner']) and context['owner'].effects.has_effect("Soul Gem: Sayaka", EffectType.Type.MARK, context['owner']).mag >= 6:
		var user = context['owner']
		var hp = user.health.hp
		var increments = ((100 - hp) / 20) * 5
		Character.resolve_effect_healing(context, context['effect'], user, increments)
	
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
