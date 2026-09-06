extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 4 turns, another ally wields Soul. During this time, Soul gains 10 Damage Reduction, and the targeted ally deals 5 more non-Affliction damage and has their Red costs changed to Random costs."

func split_desc():
	return [
		["For 4 turns, another ally wields Soul", Color.CADET_BLUE],
		["Soul gains 10 Damage Reduction", Color.CADET_BLUE],
		["Wielding ally deals 5 more non-Affliction damage", Color.CADET_BLUE],
		["That bonus increases by 5 each time the wielding ally takes damage from Soul", Color.CADET_BLUE],
		["Wielding ally's Red costs changed to Random costs", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var soul_count = 0
	if user.has_effect("Consume Soul", EffectType.Type.MARK, user):
		soul_count = user.has_effect("Consume Soul", EffectType.Type.MARK, user).stacks
	user.manually_advance_mission(9, 1)
	for target in user.targeter.targets:
		var wield_eff = Effect.mark(8, "This character is wielding Soul.")
		wield_eff.set_source(self)
		var boost_eff = Effect.damage_mod_effect(5 * (soul_count + 1), 8, [], [], [DamageType.Type.AFFLICTION])
		boost_eff.set_source(self)
		# The boost GROWS mid-window (+5 per hit Soul lands on the wielder — see soul_damage_growth),
		# so it merges into one row instead of accumulating duplicates, and it carries its own
		# description: damage_mod_effect's built-in one closes over the CONSTRUCTOR magnitude and
		# would keep printing the original number after the mod has grown.
		boost_eff.stackable = true
		boost_eff.stack_mag = true
		boost_eff.description = func (eff):
			return "This character will deal " + str(eff.mag) + " more non-Affliction damage."
		var color_change = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.RED, 8)
		color_change.set_source(self)
		# Per damage INSTANCE, not once per turn — so this trigger stays armed for the whole wield
		# window rather than consuming itself on the first hit.
		var growth = Effect.trigger_effect(
			Trigger.always(soul_damage_growth), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, 8,
			"Each time Soul damages this character, they will deal 5 more non-Affliction damage."
		)
		growth.set_source(self)

		Character.add_allied_effect(context, user, target, wield_eff)
		Character.add_allied_effect(context, user, target, boost_eff)
		Character.add_allied_effect(context, user, target, color_change)
		Character.add_allied_effect(context, user, target, growth)

	var percent_dr = Effect.damage_reduction_effect(10, 8)
	percent_dr.set_source(self)
	Character.add_allied_effect(context, user, user, percent_dr)

func soul_damage_growth(context):
	# QueryContext.from_trigger_source puts the DEALER in 'owner' and the character that took the
	# hit in 'target'. Only damage from Soul himself counts, so an enemy hitting the wielder does
	# not feed the bonus. 'effect'.user is Soul even if this skill was copied onto someone else.
	var soul = context['effect'].user
	if context['owner'] != soul:
		return
	var boost = context['target'].has_effect(ability_name, EffectType.Type.DAMAGE_MOD, soul)
	if boost == null:
		return
	boost.change_mag(5)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var partner = false
	for character in context['ally_team'].characters:
		if character.path_name == "maka":
			partner = true
	
	for character in context['ally_team'].characters:
		#TODO: add isolation check
		if not character.is_isolated() and not (character.dead or character.banished) and not character == context['owner'] and (not partner or character.path_name == "soul"):
			variations.append([100, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var partnered = Condition.has_effect(user, "Partner: Maka", EffectType.Type.MARK, user)
	if not partnered.satisfied(context):
		default_allied_target_function(user, battle)
	else:
		for character in user.team.characters:
			if character.path_name == "maka":
				check_allied_target(user, character, context)
