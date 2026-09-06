extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Uranus or the ally marked by Uranus Lip Rod become Invulnerable for 1 turn."

func split_desc():
	return [
		"Uranus or the ally marked by Uranus Lip Rod becomes Invulnerable for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var invuln = Effect.invuln_effect(2)
		invuln.set_source(self)
		Character.add_allied_effect(context, user, target, invuln)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([60, [user, self, [user]]])
	var uranus = context['owner']
	var lip_rod_ally = _find_lip_rod_ally(uranus)
	if lip_rod_ally != null and not (lip_rod_ally.dead or lip_rod_ally.banished):
		variations.append([60, [user, self, [lip_rod_ally]]])
	return variations

func _find_lip_rod_ally(uranus):
	for ally in uranus.team.characters:
		if ally == uranus:
			continue
		if ally.marked_by("Uranus Lip Rod", uranus):
			return ally
	return null

func target(user, battle):
	# Custom targeting: only Uranus herself OR the Lip Rod ally is valid.
	# Bypass=true on both check_allied_target calls because the ally selection
	# isn't a generic "any teammate" pick — it's an explicit two-option choice.
	var context = QueryContext.from_game_state(user, battle)
	check_allied_target(user, user, context, true)
	var lip_rod_ally = _find_lip_rod_ally(user)
	if lip_rod_ally != null and not (lip_rod_ally.dead or lip_rod_ally.banished):
		check_allied_target(user, lip_rod_ally, context, true)
