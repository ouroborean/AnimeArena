extends Node
class_name Character

@export var effects: EffectStorageComponent
@export var health: HealthComponent
@export var stats: StatComponent
@export var _name: NameComponent
@export var moveset: MovesetComponent
@export var targeter: TargeterComponent
var targeted = false
var last_cancelled_channels := []   # source ability names of channels ended by the most recent cancel_channels()
var waiting = true
var used_ability = null
var acted = false
var dead = false
var enemy = false
var banished = false
var used_ability_index = -1
var manual_toggle_missions = {}
var was_countered = false
var universe: CharacterConcept.Universe
@export var mastery_portrait: Texture2D
@export var mastery_name: String

@export var portrait_texture: Texture2D
@export var alt_portraits: Array[Texture2D]
var hp_last_turn = 100
var hp_last_last_turn = 100
var character_colors = []
var beginner = false
var team: TeamComponent
var character_name = ""
var mastery_portrait_on = false
var mastery_skin_on = false
var description = ""
var battle
var passive_description = ""
var path_name
var initialized = false
var bot_character = false
var bot_acted = false
var portrait_frame = "portrait_color_default"
var action_frame = "gamepanel_color_default"
var hat = "None"
var disguise_name = ""
# Sung Jin-woo's equipped summon ("" | "red" | "green" | "white" | "blue"). Stamped by
# Match._apply_jinwoo_form from the queue payload before initialize(true) builds his form-specific
# moveset; also surfaced to the opponent in the wire snapshot (battle_manager._serialize_wire_team).
var summon_form = ""
var extra_button_label = ""
# Server-authoritative portrait override. The shadow resolves the active
# portrait (walking PORTRAIT_CHANGE / DISGUISE effects) and ships the result
# here, because passive clients have no runtime _effects for active_portrait()
# to walk. server_portrait_alt == -1 means "no alt"; server_portrait_disguise
# == "" means "no disguise". server_portrait_set is flipped on the first
# reconcile so local/bot paths (where _effects is populated locally) keep
# reading from effects instead of these overrides.
var server_portrait_alt: int = -1
var server_portrait_disguise: String = ""
var server_portrait_set: bool = false
signal cancel_action(character)
signal ability_selected(entity, ability)
signal character_selected(entity)
signal update()
signal finished_targeting()
signal request_aoe_targets(targeter, main_target, faction_specific)
signal hide_panel()
signal request_panel(panel, character)
signal targeting_changed(character)
signal request_random_targets(targeter)
signal damage_received(amount: int, source, dealer, is_ticking: bool, damage_type: int)
signal healing_received(amount: int, source, healer, is_ticking: bool)
signal acted_animation_requested(ability)

# Jaden's HERO teardown list (check_effect_breaking -> jaden.break_hero, which wipes every effect of
# that name off EVERY character, including the enemy-side debuffs). Only the HEROes whose Shield IS
# the state token belong here. Avian, Burstinatrix and Bubbleman no longer grant a Shield at all
# (patch 2026-08-02), so the old `begins_with("Elemental HERO")` prefix would have let any unrelated
# same-named Shield break wipe live state those three still own; they are deliberately absent.
# Clayman keeps its Shield but is NOT torn down with it (see below). All four fusions - Mudballman
# included - still end when theirs breaks.
const HERO_SHIELD_BOUND := [
	# Clayman is DELIBERATELY ABSENT. His Shield is not his identity — the TICKING_TRIGGER that
	# regenerates it is, and that ticker is what jaden6/jaden7 gate their fusions on. Tearing him
	# down when the Shield broke destroyed the ticker too, which both denied him the regeneration
	# he is supposed to keep for the effect's full duration AND locked out two fusions. The ticker
	# now rebuilds the Shield from nothing (see jaden3.clayman_tick), so breaking it costs the
	# opponent a turn of value rather than removing the card.
	"Elemental HERO Flame Wingman",
	"Elemental HERO Rampart Blaster",
	"Elemental HERO Mudballman",
	"Elemental HERO Mariner",
]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func change_name(new_name):
	_name.change_name(new_name)

# Send a custom message to the action log, attributed to this character.
# The log row shows this character's portrait + name, followed by the text.
# If `demand` is true, the message is flagged as urgent (subject to whatever
# treatment the display layer gives demand-flagged events).
func log_message(text: String, demand: bool = false):
	if battle == null or text == "":
		return
	var event = BattleLogEvent.make(BattleLogEvent.Kind.SYSTEM).with_actor(self).with_extra("text", text)
	if demand:
		event.as_demand()
	if battle.has_method("emit_log_event"):
		battle.emit_log_event(event)

func is_unlocked(player):
	return true


func unlocked(player):
	return (path_name in CharacterDatabase.starter_squads()) or (path_name + "_unlock" in player.unlocks) or "all_unlock" in player.unlocks

func call_unique(user_path, function_name, args):
	if path_name == user_path:
		return get(function_name).call(args)
	else:
		return null

func get_custom_interface_panel():
	return false

func has_color(color):
	for skill in moveset.abilities:
		if skill._cost[color] > 0:
			return true

func manually_advance_mission(mission_num, progress):
	pass

func sleepy_frieren():
	return path_name == "frieren" and not marked_by("Mana Release")

func enemy_team():
	if team == battle.player.team:
		return battle.enemy.team
	else:
		return battle.player.team

func ally_team():
	if team == battle.player.team:
		return battle.player.team
	else:
		return battle.enemy.team

## Called before a stun is applied to this character. Return true to block the stun.
## Override in character scripts (e.g., gunha.gd) for character-specific stun interactions.
func on_stun_received(effect) -> bool:
	return false

## Called when a control effect (stun, blind, silence) is applied to this character.
## Override in character scripts (e.g., tokoyami.gd) for character-specific reactions.
func on_control_effect_received(effect):
	pass

## Called from add_hostile_effect the moment a hostile effect WOULD land (after the immunity/invuln
## gates pass), passing the full effect node so an override can read its type/duration/source. Return
## true to negate (drop) it. Override in character scripts (e.g., ainz.gd — The Goal of all Life is Death).
func negate_harmful_effect(effect, context) -> bool:
	return false

## Called by silphymon_check to delegate actual Silphymon logic to hawkmon.gd.
## Override only in hawkmon.gd.
func notify_silphymon(effect):
	pass

func silphymon_check(effect):
	if path_name == "hawkmon":
		return
	for character in team.characters:
		if character.path_name != "hawkmon":
			continue
		character.notify_silphymon(effect)

func apply_effect(effect, target, prepend=false):
	effect.set_user(self)
	effect.set_target(target)
	if effect.invisible and marked_by("Crush Card Virus") and has_effect("Crush Card Virus", EffectType.Type.MARK).user != self:
		effect.invisible = false
	if effect.effect_type == EffectType.Type.ABILITY_SWAP:
		if effect.source not in moveset.base_abilities:
			_free_unapplied_effect(effect)
			return
	if effect.effect_type == EffectType.Type.STUN:
		# A non-ignorable stun (Mahapadma / Swords of Revealing Light) bypasses Gunha's Guts veto — and
		# must NOT make him burn a Guts stack failing to resist a stun he was never allowed to shrug.
		if effect.ignorable and target.on_stun_received(effect):
			_free_unapplied_effect(effect)
			return
	if effect.effect_type == EffectType.Type.INVULN:
		check_invuln_mission_triggers(effect, target)
		# Fire hostile INVULN watchers (Igris) BEFORE the invuln is added, while the target is still
		# damageable — otherwise the punish (Piercing, which does not bypass invuln) would be blocked
		# by the very invuln it reacts to. "any enemy that BECOMES Invulnerable" = punish on gain.
		if not target.shrug_off_type(EffectType.Type.INVULN):
			target.check_invuln_received_triggers(effect)

	target.effects.add_effect(effect, prepend)

	if effect.effect_type == EffectType.Type.STUN:
		for eff in target.effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
			eff.user.wrath_check('stun')
		# ignores_effect, not shrug_off_type: a non-ignorable stun still fires its stun reactions on a
		# target that would otherwise shrug the type (it landed, so the reactions have to land too).
		if not target.ignores_effect(effect):
			check_stun_triggers(effect, target)
			target.on_control_effect_received(effect)
			silphymon_check(effect)
			# STUN_RECEIVED_TRIGGERs are the target's stun-ESCAPE reactions (Horohoro erases the stun and
			# heals; Shokuhou cleanses it off herself and counter-stuns). A non-ignorable stun must not be
			# escapable that way — "cannot be ignored" — so it does NOT fire them, exactly as the old
			# skill_seal (a MARK) never did. Ordinary stuns still trigger these normally.
			if effect.ignorable:
				target.check_stun_received_triggers(effect)
		target.check_cancels()
	elif effect.effect_type == EffectType.Type.DEF_NEGATE:
		check_shatter_mission_triggers(effect, target)
		if not target.shrug_off_type(EffectType.Type.DEF_NEGATE):
			silphymon_check(effect)
		for eff in target.effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
			eff.user.wrath_check('shatter')
	elif effect.effect_type == EffectType.Type.ISOLATE:
		if not target.shrug_off_type(EffectType.Type.ISOLATE):
			silphymon_check(effect)
		for eff in target.effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
			eff.user.wrath_check('isolate')
	elif effect.effect_type == EffectType.Type.SHIELD:
		check_shield_mission_triggers(effect, target)
	elif effect.effect_type == EffectType.Type.BLIND:
		if not target.shrug_off_type(EffectType.Type.BLIND):
			target.on_control_effect_received(effect)
			silphymon_check(effect)
			check_blind_mission_triggers(effect, target)
	elif effect.effect_type == EffectType.Type.TAUNT:
		if not target.shrug_off_type(EffectType.Type.TAUNT):
			silphymon_check(effect)
			check_taunt_mission_triggers(effect, target)
	elif effect.effect_type == EffectType.Type.BARRIER:
		check_nullify_mission_triggers(effect, target)
	elif effect.effect_type == EffectType.Type.SILENCE:
		if not target.shrug_off_type(EffectType.Type.SILENCE):
			silphymon_check(effect)
			target.on_control_effect_received(effect)
		check_silence_mission_triggers(effect, target)
	elif effect.effect_type == EffectType.Type.MARK and effect.skill_seal:
		# The ONLY stun side effect a skill seal re-emits (see check_cancels). Every other one the
		# STUN branch above fires — wrath_check, the stun mission/received triggers, Tokoyami's
		# control watcher, silphymon_check — stays dropped by owner ruling: a seal is not a stun and
		# must not feed anything that pays out for landing one.
		target.check_cancels()
	if effect.damage_type == DamageType.Type.BLEED:
		print("Applying bleed effect! Checking special code")
		var rakko = null
		for character in team.characters:
			if character.path_name == "rakko" and not character.dead and not character.banished:
				rakko = character
		if rakko:
			var duration = effect.duration
			if has_effect("Wave Tracking", EffectType.Type.DEF_NEGATE):
				if has_effect("Wave Tracking", EffectType.Type.DEF_NEGATE).duration > duration:
					duration = has_effect("Wave Tracking", EffectType.Type.DEF_NEGATE).duration
			var shatter = Effect.def_negate(duration)
			shatter.set_source(rakko.moveset.base_abilities[4])
			Character.add_hostile_effect(QueryContext.from_game_state(rakko, rakko.battle), rakko, target, shatter)

			

# RETURNS the BANISH Effect that actually landed, or null when nothing did (shrugged off, or the
# application refused). Every caller before this ignored the return and still may — it is additive.
# The one caller that needs it is BlockRunner._op_banish on a CHANNELLED skill: a channel holder
# guards the effects the cast applied, and the banish is applied inside here rather than by
# _op_apply, so without a handle on it the accumulator saw nothing and the holder was never planted
# at all. "Channeled — everything this skill applies ends if the user is stunned" then promised
# something no code could deliver.
func banish_character(context, banish_target, source, dur, wrapup = null):
	if banish_target.shrug_off_type(EffectType.Type.BANISH):
		return null
	var banish_effect = Effect.banish_effect(dur)
	banish_effect.unique_render_id = 1
	banish_effect.set_source(source)
	if wrapup != null:
		banish_effect.wrapup_func = wrapup
	if banish_target in team.characters:
		Character.add_allied_effect(context, self, banish_target, banish_effect)
	else:
		Character.add_hostile_effect(context, self, banish_target, banish_effect)
	# The application above CAN BE REFUSED — add_hostile_effect drops the effect on an
	# Invulnerable / skill-ignoring / shrugging target, and add_allied_effect drops it on an
	# Isolated one. The flag used to be set unconditionally right here, which left a character
	# flagged `banished` with no BANISH effect on them. That is not cosmetic: check_win_condition
	# counts `banished` as eliminated, so a mid-turn check_match_over could read a refused banish
	# on the last living enemy as a victory, several lines before tick_durations self-heals the
	# flag. Same defect family as _free_unapplied_effect — when the application is refused, the
	# downstream state has to agree.
	#
	# Only ever SET on success; never cleared on refusal, because a target who was ALREADY
	# banished must stay banished when a second banish bounces off them.
	if not banish_target.is_banished():
		return null                 # refused: the effect was already freed by _free_unapplied_effect
	banish_target.banished = true
	if battle:
		battle.character_banished.emit(banish_target)
	banish_target.check_cancels()
	return banish_effect

# End every effect a CONTROL_CANCEL / CHANNEL_CANCEL is holding, tolerating entries whose Node is
# already gone.
#
# WHY THE VALIDITY CHECK IS LOAD-BEARING: the ~17 channel/control abilities all build their cancel
# list by appending an Effect and THEN applying it (kitara1, genos3, gogeta1, gray6, korra8, maka3,
# madoka2, nonon3, sakura2, shiro4, tanjiro2, ...). Two ordinary outcomes free that very node:
#   * the application is REJECTED (target Invulnerable / dead / ignoring the skill) ->
#     Character._free_unapplied_effect queue_free()s it;
#   * it MERGES into an existing identical stack -> effect_storage_component queue_free()s it.
# Either way cancel_effects keeps a dangling reference, and reading `.removed` off it raises
# "Invalid access to property or key 'removed' on a base object of type 'previously freed'".
# is_queued_for_deletion covers the same-frame case, where the node is still valid but already doomed.
func _end_cancel_effects(cancel) -> void:
	for eff in cancel.cancel_effects:
		if not is_instance_valid(eff) or eff.is_queued_for_deletion():
			continue   # never stored (rejected or merged) — there is nothing live to end
		if eff.removed:
			continue
		eff.end_effect()


# A channel/control ends when its source ability can no longer be used. Two disabling families, both
# asked against that cancel's OWN source ability (so a class-filtered lockout only breaks the channels it
# actually covers): a STUN (is_stunned — this now includes the non-ignorable stuns Mahapadma / Swords of
# Revealing Light, which used to be seals), or a skill seal (is_sealed_out — Itachi's Totsuka Blade),
# which is deliberately NOT a stun so is_stunned is blind to it and it must be checked separately.
func _cancel_source_disabled(cancel) -> bool:
	if cancel.source == null:
		return false
	return is_stunned(cancel.source) or cancel.source.is_sealed_out(self)

func check_cancels(force = false):
	var cancel_controls = get_effects_by_type(EffectType.Type.CONTROL_CANCEL)
	var cancel_channels = get_effects_by_type(EffectType.Type.CHANNEL_CANCEL)
	for cancel in cancel_controls:
		if _cancel_source_disabled(cancel) or dead or banished or force:
			_end_cancel_effects(cancel)
			cancel.end_effect()
	for cancel in cancel_channels:
		if _cancel_source_disabled(cancel) or dead or banished or force:
			_end_cancel_effects(cancel)
			cancel.end_effect()

func startup_passives(battle):
	for ability in moveset.abilities:
		if ability.classes["Passive"]:
			ability.execute(self, battle)

func is_banished():
	if shrug_off_type(EffectType.Type.BANISH):
		return false
	
	if len(effects.get_effects_by_type(EffectType.Type.BANISH)) > 0:
		return true
	
	return false



func active_portrait():
	if dead:
		return load("res://assets/images/dead.png")
	if banished:
		return load("res://assets/images/banished.png")
	var final_path = -1
	var disguise_path := ""

	# Prefer the server-resolved portrait choice when we're on a passive client
	# (no runtime _effects to walk). Local/bot battles never toggle
	# server_portrait_set, so they still resolve from effects directly.
	if server_portrait_set:
		final_path = server_portrait_alt
		disguise_path = server_portrait_disguise
	else:
		for swap in effects.get_effects_by_type(EffectType.Type.PORTRAIT_CHANGE):
			if not swap.source in moveset.base_abilities:
				continue
			final_path = swap.mag
		for disguise in effects.get_effects_by_type(EffectType.Type.DISGUISE):
			disguise_path = str(disguise.mag)

	if disguise_path != "":
		var character = Character.from_character_name(disguise_path)
		var tex = character.portrait_texture   # Texture2D is refcounted — safe to free the node
		character.queue_free()
		return tex

	if mastery_portrait_on or mastery_skin_on:
		return mastery_portrait

	# Bounds guard, NOT just the -1 sentinel: an AUTHORED character transforms via a PORTRAIT_CHANGE
	# whose index the client resolves over the wire (authoredArtUrl), so its server-side alt_portraits[]
	# is EMPTY — yet server_portrait_set sets final_path = server_portrait_alt >= 0 in a live match, which
	# would make alt_portraits[final_path] a guaranteed out-of-bounds CRASH. The same guard also protects
	# shipped characters from a stray index past their alt list. Out of range => the default portrait.
	if final_path < 0 or final_path >= alt_portraits.size():
		return portrait_texture
	else:
		return alt_portraits[final_path]

func reflect_check(battle, ability):
	if stealthed():
		return false
	for ignore_counter in effects.get_effects_by_type(EffectType.Type.IGNORE_COUNTER):
		if ignore_counter.ability_targets == []:
			return false
		else:
			if ability.ability_name in ignore_counter.ability_targets:
				return false
			
	if ability.classes["Uncounterable"]:
		return false
	if path_name == "erza":
		if call_unique("erza", "wearing_armor", ["Clear Heart Clothing"]):
			return false
	for effect in effects.get_effects_by_type(EffectType.Type.REFLECT_USE):
		var context = QueryContext.from_counter_check(self, self, effect, battle)
		if Condition.action_countered(ability, effect).satisfied(context):
			effect.trigger.check(context)
			battle.log_reflect(self)
			effect.user.check_counter_triggers(effect, self)
			return true
	var original_targets = []
	for target in targeter.targets:
		original_targets.append(target)
	for target in original_targets:
		for effect in target.effects.get_effects_by_type(EffectType.Type.REFLECT_RECEIVE):
			var context = QueryContext.from_counter_check(self, target, effect, battle)
			if Condition.action_countered(ability, effect).satisfied(context):
				effect.trigger.check(context)
				effect.user.check_counter_triggers(effect, self)
				return true
	return false

func countered(battle, ability):
	if stealthed():
		return false
	for ignore_counter in effects.get_effects_by_type(EffectType.Type.IGNORE_COUNTER):
		if ignore_counter.ability_targets == []:
			return false
		else:
			if ability.ability_name in ignore_counter.ability_targets:
				return false
	if ability.classes["Uncounterable"]:
		return false
	if path_name == "erza":
		if call_unique("erza", "wearing_armor", ["Clear Heart Clothing"]):
			return false
	for effect in effects.get_effects_by_type(EffectType.Type.COUNTER_USE):
		var context = QueryContext.from_counter_check(self, self, effect, battle)
		if Condition.action_countered(ability, effect).satisfied(context):
			effect.trigger.check(context)
			if not dead:
				ability.counter_response_trigger.call(self)
			battle.log_counter(self)
			effect.user.check_counter_triggers(effect, self)
			return true
	for target in targeter.targets:
		for effect in target.effects.get_effects_by_type(EffectType.Type.COUNTER_RECEIVE):
			var context = QueryContext.from_counter_check(self, target, effect, battle)
			if Condition.action_countered(ability, effect).satisfied(context):
				effect.trigger.check(context)
				ability.counter_response_trigger.call(target)
				battle.log_counter(self)
				effect.user.check_counter_triggers(effect, self)
				return true
	return false


func generate_energy(enhanced := false):
	var turn_energy = []
	if enhanced:
		# Ultra Bot enhanced energy (P6): 75% chance to roll a colour THIS character actually uses, else a
		# fully random colour. SEEDED rolls only (battle.roll) so the shadow/replay RNG stream stays
		# bit-identical. RANDOM(4) is excluded from character_colors — generation never emits it, and an
		# all-Random / empty kit falls through to the normal uniform roll.
		var own := []
		for col in character_colors:
			if int(col) >= 0 and int(col) <= 3:
				own.append(int(col))
		if not own.is_empty() and battle.roll(0, 99, "Ultra energy 75/25") < 75:
			var pick = own[battle.roll(0, own.size() - 1, "Ultra energy colour")]
			turn_energy.append(Energy.Type[Energy.Type.keys()[pick]])
			return turn_energy
	var roll = battle.roll(0, 3, "Energy Gen Type")
	turn_energy.append(Energy.Type[Energy.Type.keys()[roll]])
	return turn_energy


func receive_ability_damage(ability, damage, dealer, damage_type = -1):
	if (dealer.path_name == "muichiro" or marked_by("Fourth Form: Shifting Flow Slash")): #TODO: add muichiro counter-state attribution
		if blind_check():
			receive_beheading(damage)
			return


	receive_damage(damage, dealer, ability)
	if damage > 0:
		check_damage_taken_triggers(ability, damage, damage_type)


func receive_beheading(value):
	var muichiro = battle.find_enemy_by_path(self, "muichiro")
	if muichiro:
		var passive = false
		for skill in muichiro.moveset.abilities:
			if skill.classes["Passive"]:
				passive = skill
		if passive:
			var mark = Effect.mark(-1, "If this effect's magnitude is greater than this character's current HP, they will be executed.")
			mark.stackable = true
			mark.display_mag = true
			mark.stack_mag = true
			mark.invisible = true
			mark.mag = value
			mark.set_source(passive)
			Character.add_hostile_effect(QueryContext.from_game_state(muichiro, battle), muichiro, self, mark)
			check_beheading()

func check_beheading():
	if marked_by("Unexpected Beheading"):
		var beheading = has_effect("Unexpected Beheading", EffectType.Type.MARK)
		var stacks = beheading.mag
		if stacks >= health.hp:
			instant_kill(beheading.user, beheading.source)

func receive_effect_damage(effect, damage, dealer, damage_type = -1):
	if (dealer.path_name == "muichiro" or marked_by("Fourth Form: Shifting Flow Slash")): #TODO: add muichiro counter-state attribution
		if blind_check():
			receive_beheading(damage)
			return

	receive_damage(damage, dealer, effect)
	if damage > 0:
		# Use the runtime damage_type threaded from deal_effect_damage — effect.damage_type is null on
		# redirect/mark sources (Saturn Crystal, Silence Wall, Heavenly Intervention), which would
		# mis-type redirected Bleed for receive-triggers like Power's Blood Fiend.
		check_damage_taken_triggers(effect, damage, damage_type if damage_type != -1 else effect.damage_type)

func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	moveset.set_base_abilities(Movesets._moveset(), self)

func execute_attempt(threshold, executioner, source):
	if health.hp <= threshold:
		instant_kill(executioner, source)

func receive_damage(damage, dealer, source):
	if hp_hidden():
		var freeze = has_effect("Texture Surprise", EffectType.Type.HISOKA_HEALTH_FREEZE)
		freeze.user.manually_advance_mission(8, damage)
	health.modify_hp(-damage, dealer, source)
	if battle and damage > 0:
		battle.damage_dealt.emit(self, damage, source, dealer)
		var dtype := -1
		if source != null and "damage_type" in source and source.damage_type != null:
			dtype = int(source.damage_type)
		damage_received.emit(damage, source, dealer, source is Effect, dtype)
	check_health_change_triggers()

func damage_reversed():
	var reversals = get_effects_by_type(EffectType.Type.DAMAGE_REVERSE)
	if len(reversals) > 0:
		return true
	return false

func get_damage_cap():
	var damage_cap = 100
	if not shrug_off_type(EffectType.Type.DAMAGE_CAP):
		for effect in effects.get_effects_by_type(EffectType.Type.DAMAGE_CAP):
			if effect.mag < damage_cap:
				if effect.source.ability_name == "Kuriboh":
					effect.user.manually_advance_mission(8, 1)
				damage_cap = effect.mag
	return damage_cap

func get_damage_cap_receive():
	var cap = 100
	if not shrug_off_type(EffectType.Type.DAMAGE_CAP_RECEIVE):
		for effect in effects.get_effects_by_type(EffectType.Type.DAMAGE_CAP_RECEIVE):
			if effect.mag < cap:
				cap = effect.mag
	return cap

func get_random_saturn_crystal_target(enemy_target = false):
	var targets = []
	
	if enemy_target:
		for character in battle.all_characters():
			if not character in team.characters and not (character.dead or character.banished):
				targets.append(character)
		if len(targets) == 0:
			return null
		var random_target = targets[battle.roll(0, len(targets) - 1)]
		return random_target
	else:
		for character in battle.all_characters():
			if character in team.characters and not (character.dead or character.banished) and not (character == self):
				targets.append(character)
		for target in targets:
			if target.marked_by("Silence Glaive Surprise"):
				return target
		if len(targets) == 0:
			return null
		var random_target = targets[battle.roll(0, len(targets) - 1)]
		return random_target


func deal_ability_damage(ability, damage, target, damage_type, redirected=false):
	var mod_damage = damage
	
	if not shrug_off_type(EffectType.Type.CHAIN_NULLIFY):
		for effect in effects.get_effects_by_type(EffectType.Type.CHAIN_NULLIFY):
			mod_damage = 0
	
	#TODO: Damage Reduction and Destructible Defense
	
	mod_damage = check_damage_nullification(ability, mod_damage, self)

	# Arthur Boyle — Nirvana: a Nirvana-marked dealer (self) converts the damage it would deal
	# into an equal amount of Nullify on itself, and deals none.
	if mod_damage > 0 and marked_by("Nirvana"):
		var nirvana_mark = marked_by("Nirvana")
		var nirvana_context = QueryContext.from_game_state(self, battle)
		var nullify = Effect.barrier_effect(mod_damage, 2)
		nullify.set_source(nirvana_mark.source)
		Character.add_allied_effect(nirvana_context, self, self, nullify)
		return

	# Arthur Boyle — Plasmantle: a Plasmantle-marked defender (target) converts incoming Harmful
	# damage into an equal amount of (Invisible) Shield on itself, and takes none.
	if mod_damage > 0 and ability.classes["Harmful"] and target.marked_by("Plasmantle"):
		var plasmantle_mark = target.marked_by("Plasmantle")
		var plasmantle_context = QueryContext.from_game_state(target, target.battle)
		var plasma_shield = Effect.shield_effect(mod_damage, 4)
		plasma_shield.set_source(plasmantle_mark.source)
		Character.add_allied_effect(plasmantle_context, target, target, plasma_shield)
		return

	# Power — Blood Spear: a Blood-Spear-marked target converts ALL incoming non-Bleed damage into an
	# equal amount of Bleed dealt to it next turn (the full raw pre-defense amount, per design), taking
	# none now. Bleed is excluded so the payload's own next-turn tick isn't re-intercepted here.
	if mod_damage > 0 and damage_type != DamageType.Type.BLEED and target.marked_by("Blood Spear"):
		var spear_payload = target.has_effect("Blood Spear", EffectType.Type.DAMAGE)
		if spear_payload:
			spear_payload.mag += mod_damage
			return   # only prevent when a payload exists to convert into; if it was staunched (healed away), take damage normally

	if marked_by("Uranus Lip Rod") and target.marked_by("World Shaking"):
		mod_damage += 5

	if get_damage_cap() != 100:
		var damage_cap = get_damage_cap()
		if damage_cap == 15 and has_effect("Crush Card Virus", EffectType.Type.DAMAGE_CAP):
			# Only the amount ACTUALLY capped counts as absorbed excess. A hit already <= 15 has
			# mod_damage - damage_cap <= 0; without max(0, ...) those negatives were added to Kaiba's
			# stored excess (and mission 7), so a run of small hits drove the "damage absorbed" total
			# negative and under-counted the eventual payout. Clamp so only real reductions accumulate.
			var reduced = max(0, mod_damage - damage_cap)

			var kaiba = has_effect("Crush Card Virus", EffectType.Type.DAMAGE_CAP).user
			kaiba.manually_advance_mission(7, reduced)
			if kaiba.has_effect("Crush Card Virus", EffectType.Type.MARK, kaiba):
				kaiba.has_effect("Crush Card Virus", EffectType.Type.MARK, kaiba).mag += reduced
		if mod_damage > damage_cap:
			mod_damage = damage_cap

	var receive_cap = target.get_damage_cap_receive()
	# ignore_damage_cap skips ONLY the default 100 cap (a stack-scaled payoff like Piccolo's shouldn't be
	# arbitrarily clipped); an explicit lower receive cap (e.g. Yoh's damage_cap_receive) still applies.
	if mod_damage > receive_cap and not (ability != null and ability.ignore_damage_cap and receive_cap == 100):
		mod_damage = receive_cap

	if damage_reversed():
		var reversals = get_effects_by_type(EffectType.Type.DAMAGE_REVERSE)
		Character.resolve_effect_healing(QueryContext.from_game_state(reversals[0].user, battle), reversals[0], target, mod_damage)
		return
	
	if damage_type == DamageType.Type.AFFLICTION:
		if target.path_name == "erza":
			if target.call_unique("erza", "wearing_armor", ["Heaven's Wheel Armor"]):
				return
	
	if target.path_name == "esdeath":
		if marked_by("Empire's Strongest"):
			mod_damage -= 10
		elif marked_by("Weiss Schnabel"):
			mod_damage -= 5

	# Escape Diary (Minene Uryuu): a 20+ hit is softened 20% per stack, then ALL stacks are consumed; the
	# character-side hook resets Escape Route's cooldown if 4 or more stacks were consumed. Grouped with the
	# other mark-keyed inline reductions, before shields/DR, so it applies to every damage type she can be hit by.
	if target.path_name == "minene" and mod_damage >= 20:
		var diary_mark = target.marked_by("Escape Diary")
		if diary_mark and diary_mark.stack_count() > 0:
			var diary_consumed = diary_mark.stack_count()
			mod_damage = mod_damage * max(0, 100 - 20 * diary_consumed) / 100   # 20% off per stack, exact int math (no float truncation)
			target.effects.erase_effect(diary_mark)
			target.call_unique("minene", "on_escape_diary_consumed", [diary_consumed])
	
	
	if (target.marked_by("Saturn Crystal") or target.marked_by("Silence Wall")) and not redirected:
		var walled = false
		if target.marked_by("Silence Wall"):
			var mark = target.has_effect("Silence Wall", EffectType.Type.MARK)
			var saturn = mark.user
			
			var redirect_target = saturn.get_random_saturn_crystal_target(true)
			if redirect_target == null:
				redirect_target = saturn
			mod_damage = int(mod_damage / 2)
			if redirect_target:
				saturn.deal_effect_damage(mark, mod_damage, redirect_target, damage_type, true)
			walled = true
		if target.marked_by("Saturn Crystal") and not walled:
			var mark = target.has_effect("Saturn Crystal", EffectType.Type.MARK)
			var redirect_target = target.get_random_saturn_crystal_target()
			if redirect_target:
				mod_damage = int(mod_damage / 2)
				if target.marked_by("Ruinous Scythe"):
					target.give_effect_healing(mark, mod_damage, redirect_target)
				else:
					target.deal_effect_damage(mark, mod_damage, redirect_target, damage_type, true)
	
	if not (damage_type == DamageType.Type.AFFLICTION or damage_type == DamageType.Type.BLEED):
		mod_damage = check_damage_against_barriers(ability, mod_damage, self)
		mod_damage = check_damage_against_shielding(ability, mod_damage, target)
	
		if not damage_type == DamageType.Type.PIERCING and not target.def_broken() and not damage_type == DamageType.Type.TRUE:
			mod_damage = check_damage_against_damage_reduction(ability, mod_damage, target)
			mod_damage = check_damage_against_percent_damage_reduction(ability, mod_damage, target)
	if not redirected:
		mod_damage = check_damage_redirect(ability.user, mod_damage, target, damage_type, ability)
	
	if target.has_effect("Natural Assassin", EffectType.Type.NAGISA_DR) and is_silenced():
		mod_damage -= 5
	
	if mod_damage >= target.health.hp and target.marked_by("Heavenly Intervention"):
		mod_damage = 0
		var mark = target.has_effect("Heavenly Intervention", EffectType.Type.MARK)
		var lyserg = mark.user
		var timeout_mark = Effect.empty(2, "Heavenly Intervention has been triggered.")
		timeout_mark.set_source(mark.source)
		Character.add_allied_effect(QueryContext.from_game_state(lyserg, lyserg.battle), lyserg, lyserg, timeout_mark)
		target.effects.erase_effect(mark)
		lyserg.deal_effect_damage(mark, 35, self, DamageType.Type.NORMAL)
		
	target.receive_ability_damage(ability, mod_damage, self, damage_type)

	if mod_damage > 0:

		if ability.health_drain:
			var context = QueryContext.from_game_state(self, battle)
			receive_healing(mod_damage, self, ability)

		# Generic self-lifesteal marker: a character marked "Lord of Gluttony" (Impmon's
		# passive) heals mark.mag% of ALL damage it deals. Also hooked in deal_effect_damage.
		var gluttony = marked_by("Lord of Gluttony")
		if gluttony:
			receive_healing(int(mod_damage * gluttony.mag / 100.0), self, ability)

		if path_name == "inuyasha":
			if has_effect("Hanyo Cycle", EffectType.Type.MARK):
				match has_effect("Hanyo Cycle", EffectType.Type.MARK).mag:
					0:
						pass
					1:
						manually_advance_mission(7, mod_damage)
					2:
						manually_advance_mission(6, mod_damage)
		check_damage_dealt_triggers(ability, target, mod_damage, damage_type)

func deal_effect_damage(effect, damage, target, damage_type, redirected =false):
	var mod_damage = damage
		
	if not shrug_off_type(EffectType.Type.CHAIN_NULLIFY):
		for eff in effects.get_effects_by_type(EffectType.Type.CHAIN_NULLIFY):
			mod_damage = 0
	#TODO: Damage Reduction and Destructible Defense
	
	mod_damage = check_damage_nullification(effect, mod_damage, self)

	# Power — Blood Spear (mirror of the deal_ability_damage hook): non-Bleed DoT/effect damage on a
	# Blood-Spear-marked target is also captured raw and re-dealt as Bleed next turn.
	if mod_damage > 0 and damage_type != DamageType.Type.BLEED and target.marked_by("Blood Spear"):
		var spear_payload = target.has_effect("Blood Spear", EffectType.Type.DAMAGE)
		if spear_payload:
			spear_payload.mag += mod_damage
			return   # only prevent when a payload exists to convert into; if it was staunched (healed away), take damage normally

	if marked_by("Uranus Lip Rod") and target.marked_by("World Shaking"):
		mod_damage += 5

	if get_damage_cap() != 100:
		var damage_cap = get_damage_cap()
		if damage_cap == 15 and has_effect("Crush Card Virus", EffectType.Type.DAMAGE_CAP):
			# Only the amount ACTUALLY capped counts as absorbed excess. A hit already <= 15 has
			# mod_damage - damage_cap <= 0; without max(0, ...) those negatives were added to Kaiba's
			# stored excess (and mission 7), so a run of small hits drove the "damage absorbed" total
			# negative and under-counted the eventual payout. Clamp so only real reductions accumulate.
			var reduced = max(0, mod_damage - damage_cap)

			var kaiba = has_effect("Crush Card Virus", EffectType.Type.DAMAGE_CAP).user
			kaiba.manually_advance_mission(7, reduced)
			if kaiba.has_effect("Crush Card Virus", EffectType.Type.MARK, kaiba):
				kaiba.has_effect("Crush Card Virus", EffectType.Type.MARK, kaiba).mag += reduced
		if mod_damage > get_damage_cap():
			mod_damage = get_damage_cap()

	var receive_cap = target.get_damage_cap_receive()
	if mod_damage > receive_cap:
		mod_damage = receive_cap

	if damage_type == DamageType.Type.AFFLICTION:
		if target.path_name == "erza":
			if target.call_unique("erza", "wearing_armor", ["Heaven's Wheel Armor"]):
				return
	
	if target.path_name == "esdeath":
		if marked_by("Empire's Strongest"):
			mod_damage -= 10
		elif marked_by("Weiss Schnabel"):
			mod_damage -= 5

	# Escape Diary (Minene Uryuu): a 20+ hit is softened 20% per stack, then ALL stacks are consumed; the
	# character-side hook resets Escape Route's cooldown if 4 or more stacks were consumed. Grouped with the
	# other mark-keyed inline reductions, before shields/DR, so it applies to every damage type she can be hit by.
	if target.path_name == "minene" and mod_damage >= 20:
		var diary_mark = target.marked_by("Escape Diary")
		if diary_mark and diary_mark.stack_count() > 0:
			var diary_consumed = diary_mark.stack_count()
			mod_damage = mod_damage * max(0, 100 - 20 * diary_consumed) / 100   # 20% off per stack, exact int math (no float truncation)
			target.effects.erase_effect(diary_mark)
			target.call_unique("minene", "on_escape_diary_consumed", [diary_consumed])
	
	if (target.marked_by("Saturn Crystal") or target.marked_by("Silence Wall")) and not redirected:
		var walled = false
		if target.marked_by("Silence Wall"):
			var mark = target.has_effect("Silence Wall", EffectType.Type.MARK)
			var saturn = mark.user
			
			var redirect_target = saturn.get_random_saturn_crystal_target(true)
			if redirect_target == null:
				redirect_target = saturn
			mod_damage = int(mod_damage / 2)
			if redirect_target:
				saturn.deal_effect_damage(mark, mod_damage, redirect_target, damage_type, true)
			walled = true
		if target.marked_by("Saturn Crystal") and not walled:
			var mark = target.has_effect("Saturn Crystal", EffectType.Type.MARK)
			var redirect_target = target.get_random_saturn_crystal_target()
			if redirect_target:
				mod_damage = int(mod_damage / 2)
				if target.marked_by("Ruinous Scythe"):
					target.give_effect_healing(mark, mod_damage, redirect_target)
				else:
					target.deal_effect_damage(mark, mod_damage, redirect_target, damage_type, true)
	
	
	if not (damage_type == DamageType.Type.AFFLICTION or damage_type == DamageType.Type.BLEED):
		mod_damage = check_damage_against_barriers(effect, mod_damage, self)
		mod_damage = check_damage_against_shielding(effect, mod_damage, target)
		
		if not damage_type == DamageType.Type.PIERCING and not target.def_broken() and not damage_type == DamageType.Type.TRUE:
			mod_damage = check_damage_against_damage_reduction(effect, mod_damage, target)
			mod_damage = check_damage_against_percent_damage_reduction(effect, mod_damage, target)
			
	if not redirected:
		mod_damage = check_damage_redirect(effect.user, mod_damage, target, damage_type, effect)
	
	if target.has_effect("Natural Assassin", EffectType.Type.NAGISA_DR) and is_silenced():
		mod_damage -= 5
	
	target.receive_effect_damage(effect, mod_damage, self, damage_type)
	
	if mod_damage > 0:
		
		if effect.health_drain:
			var context = QueryContext.from_game_state(self, battle)
			Character.resolve_effect_healing(context, effect, self, mod_damage)

		# Generic self-lifesteal marker (see deal_ability_damage). Heals the dealer for
		# mark.mag% of any DoT / trigger / counter damage it inflicts.
		var gluttony = marked_by("Lord of Gluttony")
		if gluttony:
			receive_healing(int(mod_damage * gluttony.mag / 100.0), self, effect)

		check_damage_dealt_triggers(effect, target, mod_damage, damage_type)

func check_damage_nullification(source, damage, attacker):
	if shrug_off_type(EffectType.Type.DAMAGE_NULLIFICATION):
		return int(damage)
	var nulls = attacker.get_damage_nullification_effects()
	for null_eff in nulls:
		damage *= 1.0 - null_eff.mag
	return int(damage)

func check_damage_against_barriers(source, damage, attacker):
	var barriers = attacker.get_barrier_effects()
	for barrier in barriers:
		var context = QueryContext.from_effect_end(barrier)
		if damage > 0:
			barrier.barrier_func.call(context)
			attacker.check_damage_absorb_triggers(source)
			if source is Ability and source.ability_name == "Blade of the Dragon King":
				var damage_mod = Effect.damage_mod_effect(5, -1, ["Blade of the Dragon King"])
				damage_mod.set_source(source)
				damage_mod.display_mag = true
				damage_mod.stackable = true
				damage_mod.stack_mag = true
				add_allied_effect(QueryContext.from_game_state(attacker, attacker.battle), attacker, attacker, damage_mod)
			
		if damage >= barrier.mag:
			barrier.breaker = self
			check_effect_breaking(barrier)
			damage -= barrier.mag
			barrier.mag = 0
			attacker.effects.consume_effect(barrier)
		else:
			barrier.change_mag(-damage)
			return 0
	return damage

func check_damage_against_shielding(source, damage, target):
	if target.ignoring_effect_type(EffectType.Type.SHIELD):
		return damage
	var shields = target.get_shield_effects()
	for shield in shields:
		var context = QueryContext.from_effect_end(shield)
		if damage > 0:
			shield.shield_func.call(context)
			target.check_damage_absorb_triggers(source)
			if source is Ability and source.ability_name == "Blade of the Dragon King":
				var damage_mod = Effect.damage_mod_effect(5, -1, ["Blade of the Dragon King"])
				damage_mod.set_source(source)
				damage_mod.display_mag = true
				damage_mod.stackable = true
				damage_mod.stack_mag = true
				add_allied_effect(QueryContext.from_game_state(self, battle), self, self, damage_mod)
			
		if damage >= shield.mag:
			shield.breaker = self
			check_effect_breaking(shield)
			damage -= shield.mag
			shield.mag = 0
			target.effects.consume_effect(shield)
		else:
			shield.change_mag(-damage)
			return 0
	return damage

func check_effect_breaking(eff):
	var context = QueryContext.from_effect_end(eff)
	eff.wrapup_func.call(context)
	if eff.user.effects.has_effect("Soul Gem: Madoka", EffectType.Type.MARK):
		eff.user.gain_corruption()
	if eff.source.ability_name == "Metal Armor":
		if eff.target.has_effect("Metal Armor", EffectType.Type.BLIND):
			eff.target.effects.erase_effect(eff.target.has_effect("Metal Armor", EffectType.Type.BLIND))
	if eff.source.ability_name == "Sparkling Wide Pressure":
		eff.user.call_unique("jupiter", "gain_shield_break", [context])
	if eff.source.ability_name == "A Knight That Protects":
		eff.user.call_unique("mash", "break_vow", [context])
	if eff.source.ability_name in HERO_SHIELD_BOUND:
		eff.user.call_unique("jaden", "break_hero", [context])


func has_effect(eff_name, eff_type, user=null):
	return effects.has_effect(eff_name, eff_type, user)

func has_any_effect(effect_name):
	return effects.has_any_effect(effect_name)

func has_display_effect(effect_name, effect_type):
	return effects.has_display_effect(effect_name, effect_type)

# True iff at least one ally (excluding self) is alive, on-board, AND not
# rendered untargetable by another team-wide untargetable system. Today the
# discounting effects are Jeanne's "Iron Maiden" mark (self-sourced) and
# Sukuna's "Sealed King" mark (self-sourced); an ally with either is treated
# as if they weren't there for this check. Used by characters whose own
# untargetable state must collapse when no targetable teammate remains.
func has_targetable_living_ally():
	for ally in team.characters:
		if ally == self:
			continue
		if ally.dead or ally.banished:
			continue
		if ally.effects.has_effect("Iron Maiden", EffectType.Type.MARK, ally):
			continue
		if ally.effects.has_effect("Sealed King", EffectType.Type.MARK, ally):
			continue
		if ally.effects.has_effect("Sealed Nightmare", EffectType.Type.IGNORE_DAMAGE, ally):
			continue
		return true
	return false

func check_damage_against_damage_reduction(source, damage, target):
	var dr_effects = target.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION)
	
	for dr in dr_effects:
		var dr_used = 0
		if source is Ability and source.ability_name == "Blade of the Dragon King":
			var damage_mod = Effect.damage_mod_effect(5, -1, ["Blade of the Dragon King"])
			damage_mod.set_source(source)
			damage_mod.display_mag = true
			damage_mod.stackable = true
			damage_mod.stack_mag = true
			add_allied_effect(QueryContext.from_game_state(self, battle), self, self, damage_mod)
			
		if dr.mag >= damage:
			dr_used = damage
		else:
			dr_used = dr.mag
		damage -= dr.mag
		if dr_used > 0:
			dr.user.check_ally_damage_reducing_mission_triggers(dr, target, dr_used)
		if damage <= 0:
			return 0
	return damage
	
func check_damage_against_percent_damage_reduction(source, damage, target):
	var dr_effects = target.get_effects_by_type(EffectType.Type.PERCENT_DR)
	for dr in dr_effects:
		damage *= ( (100.0 - dr.mag) / 100.0)
		if source is Ability and source.ability_name == "Blade of the Dragon King":
			var damage_mod = Effect.damage_mod_effect(5, -1, ["Blade of the Dragon King"])
			damage_mod.set_source(source)
			damage_mod.display_mag = true
			damage_mod.stackable = true
			damage_mod.stack_mag = true
			add_allied_effect(QueryContext.from_game_state(self, battle), self, self, damage_mod)
			
		
	
	return int(damage)

# `origin` is the Ability or Effect this damage came from. Only the ability-metered branch below
# uses it, and only to tell one skill's hits apart from another's (Stark's budget is shared across
# everyone hit by the SAME skill). Defaulted so the signature stays backward-compatible.
func check_damage_redirect(source, damage, target, damage_type, origin = null):
	var redirect_effects = target.get_effects_by_type(EffectType.Type.DAMAGE_REDIRECT)
	for redirect in redirect_effects:
		# ABILITY-METERED redirect (Stark's Superhuman Resilience / Cowardice). The default model
		# below moves a FIXED FRACTION of every hit to one character, which cannot express "up to N
		# damage per turn, shared across several protected allies" — each ally would need its own
		# effect, and each effect would carry its own budget. When the source ability opts in by
		# exposing take_redirect_budget(), it owns the decision instead: how much of this hit to
		# move, and to whom. That keeps one shared per-turn pool for any number of per-ally effects,
		# and keeps all of the character-specific logic in the ability where it belongs.
		if redirect.source != null and redirect.source.has_method("take_redirect_budget"):
			damage = redirect.source.take_redirect_budget(source, damage, target, damage_type, redirect, origin)
			continue
		# WHO ABSORBS. A hand-written redirect (halibel3, minene3, Stark's stark5) stores a live
		# character_target; an AUTHORED redirect (the Creator's `redirect` kind) stores a selector
		# RESOLVER in `storage` — a Callable the block layer built — run HERE, at redirect time, so a
		# "random living ally" re-picks every hit rather than being frozen at cast. Either way the
		# destination is chosen fresh for this hit.
		var absorber = redirect.character_target
		if redirect.storage is Dictionary and redirect.storage.has("redirect_resolver"):
			var resolver = redirect.storage["redirect_resolver"]
			absorber = resolver.call(redirect) if resolver is Callable else null
		# DEAD-ABSORBER GUARD (redirect ruling): a destination that is dead, banished, freed or simply
		# absent must NOT swallow the hit. Skip the redirect entirely — no subtraction, no deal — and
		# let the damage land on the original target normally. Without this, `damage -= redirected` still
		# spares the holder while the slice is dealt to a corpse (or a null), black-holing it.
		if absorber == null or not is_instance_valid(absorber) or absorber.dead or absorber.banished:
			continue
		var context = QueryContext.from_effect_end(redirect)
		var redirected_damage = damage * redirect.mag
		damage -= redirected_damage
		if not target.is_ignoring_damage(true, source):
			source.deal_effect_damage(redirect, redirected_damage, absorber, damage_type, true)
	return damage
		

func give_ability_healing(ability, healing, target):
	
	var mod_healing = healing
	#TODO check for healing mitigation
	if target.heal_blocked():
		return
	if not shrug_off_type(EffectType.Type.CHAIN_NULLIFY):
		for eff in effects.get_effects_by_type(EffectType.Type.CHAIN_NULLIFY):
			mod_healing = 0
	if target.dead or target.banished:
		return
	
	target.receive_ability_healing(ability, mod_healing, self)
	
func give_effect_healing(effect, healing, target):
	
	var mod_healing = healing
	#TODO check for healing mitigation
	if target.heal_blocked():
		return
	if not shrug_off_type(EffectType.Type.CHAIN_NULLIFY):
		for eff in effects.get_effects_by_type(EffectType.Type.CHAIN_NULLIFY):
			mod_healing = 0
	if target.dead or target.banished:
		return
	
	target.receive_effect_healing(effect, mod_healing, self)
	
func receive_ability_healing(ability, healing, healer):
	var mod_healing = healing
	if not shrug_off_type(EffectType.Type.HEAL_CUT):
		var heal_cuts = effects.get_effects_by_type(EffectType.Type.HEAL_CUT)
		for heal_cut in heal_cuts:
			mod_healing = int(mod_healing * (heal_cut.mag / 100.0))
	
	receive_healing(mod_healing, healer, ability)

func receive_effect_healing(effect, healing, healer):
	
	var mod_healing = healing
	if not shrug_off_type(EffectType.Type.HEAL_CUT):
		var heal_cuts = effects.get_effects_by_type(EffectType.Type.HEAL_CUT)
		for heal_cut in heal_cuts:
			mod_healing = int(mod_healing * (heal_cut.mag / 100.0))
	
	receive_healing(mod_healing, healer, effect)


func receive_healing(healing, healer, source):
	var attempted = healing   # the incoming heal BEFORE any reduction/clamp — "would receive / affected by a heal"
	for heal_receive_mod in effects.get_effects_by_type(EffectType.Type.HEALING_RECEIVED_MOD):
		var fail = false
		if heal_receive_mod.ability_targets != []:
			if source is Effect:
				if not source.source.ability_name in heal_receive_mod.ability_targets:
					fail = true
			elif source is Ability:
				if not source.ability_name in heal_receive_mod.ability_targets:
					fail = true
		if not fail:
			healing += heal_receive_mod.mag
	# Multiplicative heal modifier: a "Warp Digivolve - Beelzemon" mark (Impmon's transform)
	# carries mag as a percent (200 = double healing). Applied after the flat mods, before the clamp.
	var heal_mult = marked_by("Warp Digivolve - Beelzemon")
	if heal_mult:
		healing = int(healing * heal_mult.mag / 100.0)
	# A heal reduced below zero (e.g. Destructive Corrosion's flat -10 HEALING_RECEIVED_MOD) is simply no
	# healing — it must never invert into raw HP loss (which would skip the heal triggers and mis-credit the
	# healer with a kill). Floor at 0 after all incoming-heal modifiers.
	if healing < 0:
		healing = 0
	if healing > (get_modified_max_hp()) - health.hp:
		healing = (get_modified_max_hp()) - health.hp
	if dead or banished:
		return
	if hp_hidden():
		var freeze = has_effect("Texture Surprise", EffectType.Type.HISOKA_HEALTH_FREEZE)
		freeze.user.manually_advance_mission(8, healing)
	health.modify_hp(healing, healer, source)
	if battle and healing > 0:
		battle.healing_done.emit(self, healing, source, healer)
		healing_received.emit(healing, source, healer, source is Effect)
	if healing > 0:
		staunch_bleeding()
		healer.check_healing_given_triggers(source, self, healing)
	# HEALING_RECEIVED_TRIGGER fires whenever a heal is ATTEMPTED on this character — even if a HEALING_RECEIVED_MOD
	# (Destructive Corrosion's -10) or the full-HP clamp reduces the NET healing to 0. Being targeted by a healing
	# effect is what triggers it, not the amount received. `healing` (the net) is still passed as the value.
	if attempted > 0:
		check_healing_received_triggers(source, healer, healing)
	check_health_change_triggers()

func staunch_bleeding():
	var output = []
	for damage_eff in effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if damage_eff.damage_type == DamageType.Type.BLEED:
			output.append(damage_eff)
	
	for bleed in output:
		effects.erase_effect(bleed)

func get_effects_by_type(effect_type):
	return effects.get_effects_by_type(effect_type)

func is_taunted():
	var taunt_effects = effects.get_effects_by_type(EffectType.Type.TAUNT)
	if shrug_off_type(EffectType.Type.TAUNT):
		return false
	if len(taunt_effects) > 0:
		return true
	return false

func get_damage_effects():
	return effects.get_effects_by_type(EffectType.Type.DAMAGE)

func get_healing_effects():
	return effects.get_effects_by_type(EffectType.Type.HEALING)

func get_ticking_triggers():
	return effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER)

func get_shield_effects():
	return effects.get_effects_by_type(EffectType.Type.SHIELD)
	
func get_barrier_effects():
	return effects.get_effects_by_type(EffectType.Type.BARRIER)
	
func get_cooldown_mods():
	return effects.get_effects_by_type(EffectType.Type.COOLDOWN_MOD)

func get_damage_nullification_effects():
	return effects.get_effects_by_type(EffectType.Type.DAMAGE_NULLIFICATION)

func get_ability_swap_effects():
	return effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP)

func get_delay_effects():
	return effects.get_effects_by_type(EffectType.Type.DELAY)
	
func get_delayed_skills():
	return effects.get_effects_by_type(EffectType.Type.DELAYED_SKILL)

func is_skill_currently_delayed(skill):
	for delayed_skill in get_delayed_skills():
		if delayed_skill.delay_skill == skill:
			return true
	return false

func def_broken():
	var def_negates = get_effects_by_type(EffectType.Type.DEF_NEGATE)
	if shrug_off_type(EffectType.Type.DEF_NEGATE):
		return false
	if len(def_negates) > 0:
		return true
	return false

func true_ignoring():
	return len(get_effects_by_type(EffectType.Type.IGNORE_NON_DAMAGE)) > 0

# ============================================================================
# RESERVED EFFECT / ABILITY NAMES — the engine's hardcoded-name blocklist.
#
# READ THIS BEFORE ADDING A HARDCODED NAME COMPARISON ANYWHERE IN THE ENGINE.
#
# marked_by() below is `has_effect(name, MARK, null)` — it asks ONLY for a MARK with a
# given NAME, from ANY source. Effect.effect_name() is `name_override` or the SOURCE
# ABILITY'S NAME (scripts/effect_component.gd:1282-1287). Player-authored characters
# choose both of those strings, and the `mark` kind is in the shipped block palette. So
# every `marked_by("X")` / `has_effect("X", <authorable type>)` / `ability_name == "X"`
# branch in the engine is a switch an author can flip just by picking the right name.
#
# AuthoredRegistry.validate_character rejects any authored ability `name` or effect
# `name_override` in this dict. The value is WHAT THE COLLISION BUYS AN ABUSER — it is
# the justification for the entry, and it is what the rejection message quotes.
#
# The list is deliberately NOT every hardcoded name in the engine. ~25 more were read
# branch-by-branch and left out because an authored collision gains nothing:
#   * the branch is gated on `path_name` or dispatched through call_unique(), which no
#     authored character's path_name can satisfy — "Mana Release", "Hanyo Cycle",
#     "Escape Diary", "Dark Shadow Rampage"/"Black Abyss", "Sparkling Wide Pressure",
#     "A Knight That Protects", HERO_SHIELD_BOUND's four, "Fifth Form: Sea of Clouds
#     and Haze";
#   * the branch keys on an effect TYPE no authored `kind` can produce — "Natural
#     Assassin" (NAGISA_DR), "Texture Surprise" (HISOKA_HEALTH_FREEZE), "Kuriboh" and
#     "Crush Card Virus" (DAMAGE_CAP), "Metal Armor" (BLIND), "Seventh Form: Obscuring
#     Clouds" (DODGE_CHANCE);
#   * the branch only reads a field the palette deliberately withholds — "Relinquished"
#     needs `ability_targets`, which is excluded from UNIVERSAL_EFFECT_FIELDS;
#   * the collision is a pure SELF-NERF — "Empire's Strongest", "Weiss Schnabel",
#     "To the Extreme!!", "Bluff Kamehameha"/"Big Bang Kamehameha", "Silence Glaive
#     Surprise", "Wave Tracking";
#   * the branch only calls manually_advance_mission on its own user, which is a base
#     no-op for an authored character — "Tortured Resonance", "Immortal Thistle",
#     "Wood Clone", "Zanni di Squalo".
# If you make any of those reachable — a new effect kind, a new universal field, a new
# palette row — the exclusion that kept it off this list is gone and it belongs here.
const RESERVED_EFFECT_NAMES := {
	# --- damage is never taken / never dealt ---------------------------------
	"Nirvana":                        "converts all damage the marked character DEALS into an equal Nullify on itself",
	"Plasmantle":                     "converts all Harmful damage the marked character TAKES into an equal Shield",
	"Blood Spear":                    "absorbs every non-Bleed hit into a same-named DAMAGE effect instead of dealing it",
	"Saturn Crystal":                 "halves all incoming damage and redirects the rest to an ally",
	"Silence Wall":                   "halves all incoming damage and redirects the rest to a random ENEMY",
	"Ruinous Scythe":                 "turns the Saturn Crystal redirect into HEALING for the ally",
	"Heavenly Intervention":          "reduces a lethal hit to 0 and deals 35 back to the attacker",
	"Fourth Form: Shifting Flow Slash": "while the holder is Blinded, incoming damage is discarded entirely",
	# --- death is never taken ------------------------------------------------
	"Embrace Pain":                   "instant_kill returns early — immune to every execute",
	"Sealed Nightmare":               "an IGNORE_DAMAGE effect of this name also makes instant_kill return early",
	"Post-Mortem Nen":                "converts the holder's death into a free 3-turn immortality",
	"Unexpected Beheading":           "check_beheading runs on EVERY hp change and executes when mag >= hp; `mag` is authorable",
	# --- targeting and invulnerability ---------------------------------------
	"Iron Maiden":                    "a self-applied mark makes the holder untargetable by everyone",
	"Sealed King":                    "a self-applied mark makes the holder untargetable by everyone",
	"Gibbet":                         "restricts who may target the marked character to the mark's own user",
	"Tsubaki Mode: Kusarigama":       "is_invuln() returns false for every skill the marked character uses — free invuln-piercing",
	# --- economy -------------------------------------------------------------
	"Fairy Star Blessing":            "cost() returns all zeros — every skill on the marked character is free",
	"Named Reconstitution":           "the marked character generates NO energy at turn start",
	# --- free value on every hit ---------------------------------------------
	"Terror Incarnate":               "reflects every harmful hit received back at the attacker in full",
	"Ultimate Nightmare":             "reflects every harmful hit received at the WHOLE enemy team",
	"Lord of Gluttony":               "heals the marked dealer mag% of ALL damage it deals; `mag` is authorable",
	"Blade of the Dragon King":       "an ability of this name gains a permanent stacking +5 every time it meets a shield/barrier/DR",
	"Rankyaku Gaicho":                "an ability of this name erases every counter and reflect from its targets before executing",
	"Uranus Lip Rod":                 "pairs with World Shaking for +5 damage on every hit",
	"World Shaking":                  "pairs with Uranus Lip Rod for +5 damage on every hit",
	"Snake Fire":                     "lets a trigger planted on an ENEMY fire on the author's own team's attacks",
	"Data Collection":                "on a Kurotsuchi ally, permanently reveals every invisible enemy effect",
	# Both added after the Phase A judge caught them: the sweep that built this list matched the
	# DAMAGE_CAP branches for Crush Card Virus and stopped, and missed Beelzemon entirely.
	"Crush Card Virus":               "a MARK branch separate from its DAMAGE_CAP one (:179) — forces every invisible effect the holder applies to become VISIBLE, and needs no particular teammate",
	"Warp Digivolve - Beelzemon":     "marked_by() heal multiplier (:1095) reading `mag` as a percent — a plain authored mark leaves mag at 0, so `healing * 0 / 100` means the marked ENEMY can never be healed again",
	# --- not an advantage, an engine fault ------------------------------------
	# The one entry here that does not buy power: check_effect_breaking calls
	# gain_corruption() on the mark's holder, and only Madoka defines that method, so any
	# other holder raises a runtime error in the middle of damage resolution.
	"Soul Gem: Madoka":               "calls gain_corruption() on the holder — a method only Madoka has",
}

func marked_by(effect_name, user = null):
	return has_effect(effect_name, EffectType.Type.MARK, user)

func ignoring_effect_type(effect_type):
	var ignore_effects = get_effects_by_type(EffectType.Type.IGNORE_EFFECT)
	for effect in ignore_effects:
		if effect.mag == effect_type:
			return true
	return false

func check_stun_triggers(stun, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_STUN)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(stun, eff, target)
		eff.trigger.check(context)


func stealthed():
	for effect in effects.get_effects_by_type(EffectType.Type.STEALTH):
		return true
	return false

func stealth_check(effect):
	if effect.stealthable() and stealthed() and is_hostile(effect.user):
		return true
	return false

func check_stun_received_triggers(stun):
	if stun is Effect:
		stun = stun.source
	if shrug_off_type(EffectType.Type.STUN):
		return false
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.STUN_RECEIVED_TRIGGER)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		var context=QueryContext.from_trigger_source(stun, eff, self)
		eff.trigger.check(context)

func check_invuln_mission_triggers(invuln, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_INVULN)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(invuln, eff, target)
		eff.trigger.check(context)

# `self` just became Invulnerable. Fire the INVULN_RECEIVED_TRIGGER of every HOSTILE watcher (a
# character on the opposing side), letting them react to an enemy going Invulnerable — e.g. Sung
# Jin-woo's Summon - Igris punishing them with Piercing damage. Mirrors check_stun_received_triggers,
# but reactor-side (the watcher holds the trigger) rather than bearer-side.
func check_invuln_received_triggers(invuln):
	if battle == null:
		return
	for watcher in battle.all_characters():
		if watcher == self or watcher.dead or watcher.banished:
			continue
		if not watcher.is_hostile(self):
			continue
		for eff in watcher.effects.get_effects_by_type(EffectType.Type.INVULN_RECEIVED_TRIGGER):
			var context = QueryContext.from_trigger_source(invuln, eff, self)
			eff.trigger.check(context)

func check_blind_mission_triggers(blind, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_BLIND)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(blind, eff, target)
		eff.trigger.check(context)

func check_taunt_mission_triggers(taunt, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_TAUNT)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(taunt, eff, target)
		eff.trigger.check(context)

func check_shield_mission_triggers(shield, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_SHIELD)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(shield, eff, target)
		eff.trigger.check(context)
	
func check_nullify_mission_triggers(nullify, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_NULLIFY)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(nullify, eff, target)
		eff.trigger.check(context)
		
func check_silence_mission_triggers(silence, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_SILENCE)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(silence, eff, target)
		eff.trigger.check(context)

func check_shatter_mission_triggers(shatter, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_SHATTER)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(shatter, eff, target)
		eff.trigger.check(context)
	
func check_hostile_damage_reducing_mission_triggers(reduction, target, amount):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_WEAKNESS_ABSORB)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(reduction, eff, target, amount)
		eff.trigger.check(context)

func check_ally_damage_reducing_mission_triggers(reduction, target, amount):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_DR_ABSORB)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(reduction, eff, target, amount)
		eff.trigger.check(context)

func check_counter_triggers(counter, target):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_COUNTER)
	for eff in trigger_effects:
		var context = QueryContext.from_trigger_source(counter, eff, target)
		eff.trigger.check(context)

func check_game_end_triggers(won, battle):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_GAME_END)
	for eff in trigger_effects:
		var context = QueryContext.from_game_state(self, battle)
		context.won = won
		eff.trigger.check(context)

func check_damage_dealt_triggers(damage_source, target, damage, damage_type):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.DAMAGE_DEALT_TRIGGER)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		if eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(damage_source, eff, target, damage)
		context.damage_type = damage_type
		eff.trigger.check(context)
	var mission_trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_DAMAGE)
	for mission_eff in mission_trigger_effects:
		if mission_eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(damage_source, mission_eff, target, damage)
		context.damage_type = damage_type
		mission_eff.trigger.check(context)
	for eff in target.effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
		if stealth_check(eff):
			continue
		if damage_type == DamageType.Type.NORMAL:
			eff.user.wrath_check("normal")
		elif damage_type == DamageType.Type.PIERCING:
			eff.user.wrath_check("piercing")
		elif damage_type == DamageType.Type.AFFLICTION:
			eff.user.wrath_check("affliction")

func check_health_change_triggers():
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HEALTH_CHANGE_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)
	for effect in effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
		if health.hp < 50:
			effect.target.wrath_check("half")
	check_beheading()
		
func check_damage_taken_triggers(damage_source, damage, damage_type = -1):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.DAMAGE_RECEIVE_TRIGGER)
	for eff in trigger_effects:
		if damage_source.user.stealth_check(eff):
			continue
		#if eff.triggered:
			#continue
		if damage_source is Effect and eff.ability_only:
			continue
		var context = QueryContext.from_trigger_source(damage_source, eff, self, damage)
		context.damage_type = damage_type   # runtime type of the received hit (mirrors check_damage_dealt_triggers) — lets a receive-trigger filter by damage type (e.g. Power's Blood Fiend on Bleed)
		eff.trigger.check(context)
	

func check_healing_given_triggers(healing_source, target, healing):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HEALING_GIVEN_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(healing_source, eff, target, healing)
		eff.trigger.check(context)
	var mission_trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_HEAL)
	for mission_eff in mission_trigger_effects:
		if mission_eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(healing_source, mission_eff, target, healing)
		mission_eff.trigger.check(context)

# Mirror of check_healing_given_triggers, fired on the character that RECEIVED the healing (self). The
# HEALING_RECEIVED_TRIGGER enum existed but was never wired; this completes it. Used by Sesshomaru's
# Destructive Corrosion ("whenever an affected enemy is healed, they take 10 Affliction damage").
func check_healing_received_triggers(healing_source, healer, healing):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HEALING_RECEIVED_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(healing_source, eff, self, healing)
		eff.trigger.check(context)
		
func check_damage_absorb_triggers(damage_source):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.ABSORB_TRIGGER)
	for eff in trigger_effects:
		if damage_source.user.stealth_check(eff):
			continue
		if eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(damage_source, eff, self)
		eff.trigger.check(context)

func cancel_channels():
	# Record which channels this cast is cancelling (by source ability name) so a skill that interacts
	# with its own channel on interrupt — Arima's Narukami Sword / Ixa Parry — can detect it in execute()
	# WITHOUT carrying "Preserves Channel". cancel_channels runs from execute_ability just before execute,
	# and only from there, so the list is fresh for the acting ability to read.
	last_cancelled_channels = []
	var cancel_channels = get_effects_by_type(EffectType.Type.CHANNEL_CANCEL)
	for cancel in cancel_channels:
		if cancel.source != null:
			last_cancelled_channels.append(cancel.source.ability_name)
		_end_cancel_effects(cancel)
		cancel.end_effect()


func check_ability_use_triggers(battle, ability, force=false, acting_targets=null):
	
	if has_effect("Tortured Resonance", EffectType.Type.COST_MOD):
		if has_effect("Tortured Resonance", EffectType.Type.COST_MOD).user in team.characters:
			has_effect("Tortured Resonance", EffectType.Type.COST_MOD).user.manually_advance_mission(7, 1)
	
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.ACTION_USE_TRIGGER)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		if eff.triggered and not force:
			continue
		if eff.waiting and ability == eff.source:
			eff.waiting = false
			continue
			
		var context = QueryContext.from_trigger_source(ability, eff, self)
		eff.trigger.check(context)
	if dead:
		return
	used_ability = ability
	# Only fire the harmful/helpful USE triggers if the skill is actually acting on that faction — a
	# dual-classed skill used helpfully must not trip a HARMFUL_USE_TRIGGER, and vice versa. Uses the
	# ORIGINAL (pre-reflect) targets when supplied, since reflect_check may have repointed the targeter.
	if Character.ability_acts_harmful(ability, acting_targets):
		check_harmful_use_triggers(battle, ability, force)
	if Character.ability_acts_helpful(ability, acting_targets):
		check_helpful_use_triggers(battle, ability)

	for target in targeter.targets:
		target.check_ability_receive_triggers(battle, ability, force)

func check_ability_receive_triggers(battle, received_ability, force=false):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.ACTION_RECEIVE_TRIGGER)
	
	for eff in trigger_effects:
		if received_ability.user.stealth_check(eff):
			continue
		if eff.triggered and not force:
			continue
		if eff.waiting and received_ability == eff.source:
			eff.waiting = false
			continue
		var context = QueryContext.from_trigger_source(received_ability, eff, self)
		eff.trigger.check(context)
	if dead:
		return
	# RECEIVE triggers keep their existing applier-team faction handling (check_harmful/helpful_receive_triggers
	# already gate on whether the trigger's user is on the caster's team). A per-target is_hostile gate here
	# was reverted: it duplicated that handling for the common case and misfired on reflected skills (a skill
	# reflected onto the caster's own team would wrongly read as "helpful" to them).
	if received_ability.classes["Harmful"]:
		check_harmful_receive_triggers(battle, received_ability, force)
	if received_ability.classes["Helpful"]:
		check_helpful_receive_triggers(battle, received_ability)

func check_harmful_use_triggers(battle, ability, force=false):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HARMFUL_USE_TRIGGER)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		if eff.triggered and not force:
			continue
		if ability.classes["Harmful"] and eff.waiting and ability == eff.source:
			eff.waiting = false
			continue
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)
	
func check_helpful_use_triggers(battle, ability):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HELPFUL_USE_TRIGGER)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		if eff.triggered:
			continue
		if ability.classes["Helpful"] and eff.waiting and ability == eff.source:
			eff.waiting = false
			continue
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)

func check_harmful_receive_triggers(battle, received_ability, force=false):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HARMFUL_RECEIVE_TRIGGER)
	for eff in trigger_effects:
		if received_ability.user.stealth_check(eff):
			continue
		if eff.user in received_ability.user.team.characters and not eff.source.ability_name == "Snake Fire":
			continue
		if eff.triggered and not force:
			continue
		if received_ability.classes["Harmful"] and received_ability == eff.source and eff.waiting:
			eff.waiting = false
			continue
		var context = QueryContext.from_trigger_source(received_ability, eff, self)
		eff.trigger.check(context)
	
func check_helpful_receive_triggers(battle, received_ability):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.HELPFUL_RECEIVE_TRIGGER)
	for eff in trigger_effects:
		if received_ability.user.stealth_check(eff):
			continue
		if eff.user not in received_ability.user.team.characters:
			continue
		if eff.triggered:
			continue
		if received_ability.classes["Helpful"] and received_ability == eff.source and eff.waiting:
			eff.waiting = false
			continue
		var context = QueryContext.from_trigger_source(received_ability, eff, self)
		eff.trigger.check(context)
		
func check_end_of_turn_triggers(battle):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.END_OF_TURN_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)

func check_start_of_turn_triggers(battle):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.START_OF_TURN_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context) 

func check_death_triggers(killer):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.ON_DEATH_TRIGGER)
	for eff in trigger_effects:
		if eff.triggered:
			continue
		var context = QueryContext.from_effect_end(eff)
		context['owner'] = killer
		eff.trigger.check(context)

func check_kill_triggers(source, killed):
	var trigger_effects = effects.get_effects_by_type(EffectType.Type.MISSION_TRIGGER_ON_KILL)
	for eff in trigger_effects:
		if stealth_check(eff):
			continue
		if eff.triggered:
			continue
		var context = QueryContext.from_trigger_source(source, eff, killed)
		context['source'] = source
		eff.trigger.check(context)

func check_counter_use_effects(interacter, battle):
	var counters = effects.get_effects_by_type(EffectType.Type.COUNTER_USE)
	for eff in counters:
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)

func check_counter_receive_effects(interacter, battle):
	var counters = effects.get_effects_by_type(EffectType.Type.COUNTER_RECEIVE)
	for eff in counters:
		var context = QueryContext.from_effect_end(eff)
		eff.trigger.check(context)

func get_mod_stat(stat):
	return stats.get_mod_stat(self, stat)

func get_base_stat(stat):
	return stats.get_base_stat(stat)

func ability_clicked(ability):
	#TODO: Maybe some of that "can I can I" stuff goes here?
	ability_selected.emit(self, ability)

func character_clicked():
	character_selected.emit(self)

func acted_clicked():
	if used_ability != null:
		refund_chosen_ability()
		refresh()
		
		update.emit()
		cancel_action.emit(self)

func refund_chosen_ability():
	team.refund_ability(used_ability)

func gain_random_energy():
	var energy_type = battle.roll(0, 3)
	team.change_energy(energy_type, 1)

func gain_bonus_energy(element):
	team.change_energy(element, 1)

func lose_energy(drainer, val=1):
	#TODO: on-drain triggers go here
	# Muscle Magic (Mash Burnedead): a character carrying the mark cannot have energy drained or stolen
	# by an ENEMY. A friendly source (an ally's exchange, self-spend) still works.
	if drainer != null and is_instance_valid(drainer) and not (drainer in team.characters) and has_effect("Muscle Magic", EffectType.Type.MARK, self) != null:
		return
	team.lose_energy(val, battle)

func can_be_affected(user, effect):
	return true

func cap_health(context, capper, duration, source):
	
	var cap_amount = health.hp
	var health_cap = Effect.health_cap_effect(cap_amount, duration)
	health_cap.set_source(source)
	Character.add_hostile_effect(context, capper, self, health_cap)

func get_modified_max_hp():
	var health_caps = effects.get_effects_by_type(EffectType.Type.HEALTH_CAP)
	var smallest_cap = health.max_hp
	for cap in health_caps:
		if cap.mag < smallest_cap:
			smallest_cap = cap.mag
	return smallest_cap

func set_health_capped(value):
	# Directly set HP, but never above the character's current effective cap (a HEALTH_CAP effect can
	# lower it below max_hp). Used by fixed-value returns/revives (e.g. Ban's / Mayuri's banish return
	# at 20 / 30 HP) so a capped character can't come back above their maximum. health.set_health is a
	# RAW setter with no clamp, so the clamp must live here.
	health.set_health(min(value, get_modified_max_hp()))
	
func heal_blocked():
	var heal_negates = effects.get_effects_by_type(EffectType.Type.IGNORE_HEALING)
	if shrug_off_type(EffectType.Type.IGNORE_HEALING):
		return false
	if len(heal_negates) > 0:
		return true
	return false

func has_stuns():
	var stun_effects = effects.get_effects_by_type(EffectType.Type.STUN)
	var stun_immunities = effects.get_effects_by_type(EffectType.Type.STUN_IMMUNITY)
	var false_stun_effects = effects.get_effects_by_type(EffectType.Type.FALSE_STUN)
	if len(false_stun_effects) > 0:
		return true
	# A non-ignorable stun (Mahapadma / Swords) can't be shrugged, so it counts as a stun even when the
	# character would otherwise ignore STUN (Erza's Clear Heart, ignore-all-non-damage). Keeps has_stuns()
	# in agreement with is_stunned(), which the two are meant to be — they drive the same "is stunned"
	# state (portrait indicator, bot model, ~8 abilities). Checked before those escape short-circuits.
	for e in stun_effects:
		if not e.ignorable:
			return true
	if path_name == "erza":
		if call_unique("erza", "wearing_armor", ["Clear Heart Clothing"]):
			return false
	if shrug_off_type(EffectType.Type.STUN):
		return false
	if len(stun_effects) < 1:
		return false
	else:
		return true

func has_silences():
	var stun_effects = effects.get_effects_by_type(EffectType.Type.SILENCE)
	if shrug_off_type(EffectType.Type.SILENCE):
		return false
	if len(stun_effects) < 1:
		return false
	else:
		return true
		
func has_taunts():
	var stun_effects = effects.get_effects_by_type(EffectType.Type.TAUNT)
	if shrug_off_type(EffectType.Type.TAUNT):
		return false
	if len(stun_effects) < 1:
		return false
	else:
		return true

func shrug_off_type(effect_type):
	# "Ignore all non-damage effects" (true_ignoring) shrugs off every type EXCEPT DAMAGE, MARK, and
	# COUNTER_TRIGGER_NOTIFICATION. Marks are exempt so they still land on the ignoring character —
	# they're widely used as passive tags that OTHER effects read, and silently dropping them disrupts
	# those interactions too much. COUNTER_TRIGGER_NOTIFICATION is exempt because it's a purely
	# informational marker ("this character was countered / had a skill ignored by X"): the counter
	# still lands regardless of this ignore, so dropping only its notification just hides feedback the
	# player needs. A SPECIFIC ignore of any of these types (ignoring_effect_type) still applies.
	return ignoring_effect_type(effect_type) or (true_ignoring() and effect_type != EffectType.Type.DAMAGE and effect_type != EffectType.Type.MARK and effect_type != EffectType.Type.COUNTER_TRIGGER_NOTIFICATION)

# A TICKING_TRIGGER that carries a damage_type is "effectively a damage effect (plus a rider)" — a DoT
# delivered as a trigger rather than a DAMAGE effect (Toga's Bleed syringe, Baki's delayed hits). The
# "ignore all non-damage effects" shrug and negate-harmful-non-damage passives (Ainz) must NOT drop it,
# exactly as they never drop a DAMAGE effect / DoT. Opt in by setting effect.damage_type on the trigger.
static func trigger_delivers_damage(effect) -> bool:
	return effect != null and effect.effect_type == EffectType.Type.TICKING_TRIGGER and effect.damage_type != null

func ignores_effect(effect) -> bool:
	# An effect is only shrugged / ignored when it PERMITS being ignored. ignorable == false (Mahapadma,
	# Swords of Revealing Light) makes it land regardless of "ignore all non-damage effects"
	# (true_ignoring) or a specific type-ignore.
	if Character.trigger_delivers_damage(effect):
		return false
	return effect.ignorable and shrug_off_type(effect.effect_type)

# Does this ONE stun effect stun `ability` by its own scope? Name exemption (exclusion_names) wins first
# (Swords keeps Dark Magician / Dark Magician Girl usable under its own Harmful stun), then class
# exclusions, then the class target list (empty == every skill).
func _stun_applies_to(effect, ability) -> bool:
	if ability.ability_name in effect.exclusion_names:
		return false
	for ability_class in effect.exclusion_targets:
		if ability.classes[ability_class]:
			return false
	if len(effect.ability_targets) == 0:
		return true
	for ability_class in effect.ability_targets:
		if ability.classes[ability_class]:
			return true
	return false

func is_stunned(ability):
	var stun_effects = effects.get_effects_by_type(EffectType.Type.STUN)
	# Un-ignorable stuns (ignorable == false) bypass every escape hatch below — Erza's Clear Heart, the
	# Unstunnable class, a stun-shrug / "ignore all non-damage effects", and Gunha's Guts (already vetoed
	# at application). That is exactly what "cannot be ignored" means for Mahapadma / Swords of Revealing
	# Light; they still honour their own class/name scope via _stun_applies_to.
	for effect in stun_effects:
		if not effect.ignorable and _stun_applies_to(effect, ability):
			return true
	if path_name == "erza":
		if call_unique("erza", "wearing_armor", ["Clear Heart Clothing"]):
			return false
	if not ability.stunnable:
		return false
	if shrug_off_type(EffectType.Type.STUN):
		return false
	# Cost-gated stun (Fushiguro Toji's Split Soul Katana): the skill counts as stunned
	# if its resolved cost pays a colour named by a COST_STUN effect on this character.
	# Placed after the stunnable/shrug guards (so those still bypass it) and before the
	# no-STUN early-out. cost() respects COST_MOD, so Playful Cloud's +1 Green feeds in.
	for cost_stun in effects.get_effects_by_type(EffectType.Type.COST_STUN):
		if ability.cost()[cost_stun.cost_change_element] > 0:
			return true
	if len(stun_effects) < 1:
		return false
	# Ignorable stuns: original semantics preserved (a class-excluding stun grants that class immunity
	# globally). Non-ignorable stuns were already resolved by the pre-pass, so skip them here.
	for effect in stun_effects:
		if not effect.ignorable:
			continue
		if ability.ability_name in effect.exclusion_names:
			return false
		for ability_class in effect.exclusion_targets:
			if ability.classes[ability_class]:
				return false
		if len(effect.ability_targets) == 0:
			return true
		for ability_class in effect.ability_targets:
			if ability.classes[ability_class]:
				return true

	return false

func is_hostile(character):
	return not character in team.characters

# Faction-aware Harmful/Helpful for counter / reflect / trigger checks. This is a DUAL-CLASS-ONLY
# refinement: a skill classed BOTH Harmful and Helpful (usable on either faction) counts as Harmful only
# while actually aimed at an enemy, and as Helpful only while aimed at an ally — so a helpful use of a
# dual-class skill no longer trips a "next Harmful skill" counter/reflect/trigger (and vice versa).
# PURELY-classed skills are unchanged: a purely-Harmful skill always acts Harmful (even self-targeted,
# e.g. Eren Rampage / Gohan Dodge), and a purely-Helpful skill always acts Helpful.
# `targets` lets a caller pass the ORIGINAL cast targets (snapshotted before reflect_check repoints the
# targeter); it defaults to the actor's live targets, which are correct for the pre-execute counter/reflect.
static func ability_acts_harmful(ability, targets = null) -> bool:
	if not ability.classes["Harmful"]:
		return false
	if not ability.classes["Helpful"]:
		return true
	return _ability_has_faction_target(ability, true, targets)

static func ability_acts_helpful(ability, targets = null) -> bool:
	if not ability.classes["Helpful"]:
		return false
	if not ability.classes["Harmful"]:
		return true
	return _ability_has_faction_target(ability, false, targets)

static func _ability_has_faction_target(ability, want_hostile, targets = null) -> bool:
	var actor = ability.user
	if actor == null:
		return false
	var tlist = targets
	if tlist == null:
		tlist = actor.targeter.targets if actor.targeter != null else []
	for t in tlist:
		if actor.is_hostile(t) == want_hostile:
			return true
	return false

# True while THIS character's skills should pierce Invulnerability. Consulted by is_invuln, so it applies
# uniformly to TARGETING (can_hostile_target) AND EFFECT APPLICATION (can_apply_hostile_effect) — instead
# of every skill remembering to thread a bypassing flag by hand. The effect-application calls were NOT
# passing it (e.g. Midoriya's stun/vulnerability never landed on an Invuln target even though the skill
# could target it and its damage still connected). Consolidates the temporary-bypass sources: wielding
# Tsubaki (Kusarigama mark) and Midoriya's Faux 100% — add future sources here and both paths honour them.
func grants_skill_bypass() -> bool:
	if marked_by("Tsubaki Mode: Kusarigama"):
		return true
	if has_effect("Faux 100%", EffectType.Type.ACTION_USE_TRIGGER, self):
		return true
	return false

func is_invuln(ability = null):
	var invuln_effects = effects.get_effects_by_type(EffectType.Type.INVULN)
	var def_negate = effects.get_effects_by_type(EffectType.Type.DEF_NEGATE)
	if ability and ability.user:
		if ability.user.grants_skill_bypass():
			return false
	if len(def_negate) > 0:
		return false
	if len(invuln_effects) > 0:
		if ability == null:
			return true
	for eff in invuln_effects:
		# Cost-gated invuln (Fushiguro Toji's Chain of a Thousand Miles): the character is
		# invulnerable to every skill EXCEPT those whose resolved cost pays the required
		# colour. Bypassing skills already skip is_invuln at the call site, so they pierce
		# this the same way they pierce a normal invuln (per design).
		if eff.cost_color_required != -1:
			if ability == null:
				return true
			if ability.cost()[eff.cost_color_required] > 0:
				continue
			else:
				return true
		if eff.exclusion_targets != []:
			for target in eff.exclusion_targets:
				if ability.classes[target]:
					return false
		if eff.class_targets == []:
			return true
		else:
			for target in eff.class_targets:
				if ability.classes[target]:
					return true
	return false

func is_ignoring_damage(ability_source, attacker = null):
	var dmg_negate_effects = effects.get_effects_by_type(EffectType.Type.IGNORE_DAMAGE)
	#TODO: Add helpful negate check?
	if len(dmg_negate_effects) > 0:
		for eff in dmg_negate_effects:
			# DIRECTIONAL immunity (Arima's Ixa Shield): an IGNORE_DAMAGE that names a `character_target`
			# ignores damage ONLY from that specific attacker. A null character_target (every other
			# IGNORE_DAMAGE) ignores all sources, unchanged.
			if eff.character_target != null and eff.character_target != attacker:
				continue
			if not eff.ability_only or ability_source:
				if eff.remove_once_triggered:
					eff.target.effects.consume_effect(eff)
				elif eff.full_remove_once_triggered:
					eff.target.effects.consume_effect(eff, true)
				return true
		
	return false

func can_boost():
	# False while a NO_BOOST effect (Trap of Argalia) is present: this character cannot INCREASE the
	# damage it deals with any effect. get_true_damage checks this before applying positive DAMAGE_MOD
	# boosts. New general-case filter — in-skill script damage bumps must opt in as they arise.
	return effects.get_effects_by_type(EffectType.Type.NO_BOOST).is_empty()

# The QueryContext of the incoming skill currently being fully ignored by Casseur de Logistille.
# We hold the context by reference (not its instance-id): every part of one skill — its damage and
# each hostile effect — shares one context object, so once we begin ignoring a skill we ignore all of
# it. Keying on the live object (rather than get_instance_id(), which Godot can reuse for a later
# freed RefCounted) removes any stale false-positive; it is cleared each turn in start_new_turn().
var _casseur_ctx = null

func is_ignoring_skill(ability, context):
	# Casseur de Logistille (Astolfo): fully negate the NEXT Harmful skill received whose class isn't in
	# an IGNORE_SKILL effect's exclusion list (Physical). `ability` is the source ability of the incoming
	# hit/effect — keyed the same way invuln keys on effect.source, so DoT/trigger applications test their
	# own source rather than a stale used_ability. Consumes the charge exactly once per skill.
	if context != null and context == _casseur_ctx:
		return true
	if not ability or not ability.classes["Harmful"]:
		return false
	for eff in effects.get_effects_by_type(EffectType.Type.IGNORE_SKILL):
		var excluded = false
		for cls in eff.exclusion_targets:
			if ability.classes[cls]:
				excluded = true
				break
		if excluded:
			continue
		_casseur_ctx = context
		var casseur_src = eff.source
		effects.consume_effect(eff)
		_announce_casseur_ignore(casseur_src, context)
		return true
	return false

# Casseur is invisible, so its consumption is silent by default. Mirror the counter feedback path, but
# Casseur IGNORES a skill (it doesn't counter it): label the attacker with a "had a skill ignored by
# <ability>" notification and announce the invisible effect's end on the holder.
func _announce_casseur_ignore(src, context):
	if src == null or battle == null:
		return
	var attacker = context.owner if context != null else null
	if attacker != null and not (attacker.dead or attacker.banished):
		var note = Effect.skill_ignored_notification_effect(src)
		note.set_source(src)
		Character.add_hostile_effect(context, src.user, attacker, note, true)
	var expiry = Effect.invisible_expiration_effect(src)
	expiry.set_source(src)
	Character.add_allied_effect(QueryContext.from_game_state(self, battle), src.user, self, expiry)

func is_silenced():
	var silence_effects = effects.get_effects_by_type(EffectType.Type.SILENCE)
	if shrug_off_type(EffectType.Type.SILENCE):
		return false
	if len(silence_effects) > 0:
		return true
	return false

func is_isolated():
	var isolate_effects = effects.get_effects_by_type(EffectType.Type.ISOLATE)
	# A self-inflicted isolate (e.g. BlackWarGreymon's Dark Creation) always counts. Otherwise the same
	# character's "ignore all non-damage effects" makes shrug_off_type(ISOLATE) true and cancels the very
	# isolation it deliberately applied to itself — leaving it wrongly targetable by Helpful skills.
	# Enemy isolates never reach here (add_hostile_effect drops shrugged effects at application), so this
	# only rescues the deliberate self-case and changes nothing for anyone else.
	for eff in isolate_effects:
		if eff.user == self:
			return true
	if shrug_off_type(EffectType.Type.ISOLATE):
		return false
	if len(isolate_effects) > 0:
		return true
	return false

func get_stun_immunities():
	var output = []
	var eff_ignores = effects.get_effects_by_type(EffectType.Type.IGNORE_EFFECT)
	for eff in eff_ignores:
		if eff.mag == EffectType.Type.STUN:
			output.append(eff)
	return output

func is_immortal():
	var immortality_effects = effects.get_effects_by_type(EffectType.Type.IMMORTALITY)
	if len(immortality_effects) > 0:
		return true
	return false

func dodge_check(_targeter):
	var dodge_effects = effects.get_effects_by_type(EffectType.Type.DODGE_CHANCE)
	var sharpshooter_effects = _targeter.effects.get_effects_by_type(EffectType.Type.SHARPSHOOTER)
	if len(sharpshooter_effects) > 0:
		return false
	var greatest_dodge_chance = 0
	if len(dodge_effects) < 1:
		return false
	for effect in dodge_effects:
		var mag = effect.mag
		if effect.source.ability_name == "Seventh Form: Obscuring Clouds":
			if _targeter.blind_check():
				mag = mag * 2
			if path_name == "muichiro" and has_effect("Fifth Form: Sea of Clouds and Haze", EffectType.Type.MARK):
				mag = mag * 2
		
		if mag > greatest_dodge_chance:
			greatest_dodge_chance = mag
	var dodge_roll = battle.roll(1, 100)
	if dodge_roll <= greatest_dodge_chance:
		return true
	return false
	
func miss_check():
	if shrug_off_type(EffectType.Type.MISS_CHANCE):
		return
	var miss_effects = effects.get_effects_by_type(EffectType.Type.MISS_CHANCE)
	var sharpshooter_effects = effects.get_effects_by_type(EffectType.Type.SHARPSHOOTER)
	if len(sharpshooter_effects) > 0:
		return
	var greatest_miss_chance = 0
	for effect in miss_effects:
		if effect.mag > greatest_miss_chance:
			greatest_miss_chance = effect.mag
	var miss_roll = battle.roll(1, 100)
	if miss_roll <= greatest_miss_chance:
		targeter.clear_targets()

func accuracy_check(ability):
	if ability.accurate:
		return
	miss_check()
	var potentials = []
	for target in targeter.targets:
		potentials.append(target)
	for target in potentials:
		var hostile = Condition.is_hostile(self, target)
		if hostile.satisfied(QueryContext.from_game_state(self, battle)):
			if target.dodge_check(self):
				targeter.remove_target(target)

func paralyzed():
	if shrug_off_type(EffectType.Type.PARALYZE):
		return false
	var paralysis = effects.get_effects_by_type(EffectType.Type.PARALYZE)
	
	if len(paralysis) > 0:
		return true
	return false

func shatter_barrier(breaker):
	var total_broken = 0
	var nullify_effects = get_barrier_effects()
	for nullify in nullify_effects:
		nullify.breaker = breaker
		check_effect_breaking(nullify)
		total_broken += nullify.mag
		nullify.mag = 0
		effects.consume_effect(nullify)
	return total_broken

func shatter_shields(breaker):
	var total_broken = 0
	var shield_effects = get_shield_effects()
	for shield in shield_effects:
		shield.breaker = breaker
		check_effect_breaking(shield)
		total_broken += shield.mag
		shield.mag = 0
		effects.consume_effect(shield)
	return total_broken

func instant_kill(killer, source):
	
	if marked_by("Embrace Pain"):
		return
	if has_effect("Sealed Nightmare", EffectType.Type.IGNORE_DAMAGE):
		return
	
	die(killer, source)
	

func die(killer=null, source=null):
	# Passive multiplayer clients hold no runtime _effects (only DisplayEffects
	# rebuilt from wire payloads), so is_immortal() — which walks _effects —
	# returns false even when the server saved the character via immortality.
	# That false negative would drive die() into the death branch, set
	# dead=true, and call refresh(true) — which latches waiting=true and
	# leaves the survivor un-actionable on the next turn even after the
	# snapshot reconciles dead back to false.
	#
	# The server is authoritative for death: DAMAGE events update HP, and
	# the DIED wire event sets dead=true via the event-replay handler in
	# battle_manager.gd. Running die() locally on the passive client would
	# also double-emit character_died and double-fire death/kill triggers
	# that the server already evaluated. Short-circuit here.
	if battle != null and "passive" in battle and battle.passive:
		return
	if not dead:
		if marked_by("Post-Mortem Nen"):
			effects.full_remove_effect_by_name("Post-Mortem Nen")
			# Immortal only until the END of the turn this fired on, no matter whose turn it is. duration 1
			# is decremented by tick_durations() — which runs for EVERY character at the end of every turn,
			# AFTER that turn's ticking effects have all resolved — so the save reliably outlasts the rest
			# of this turn's damage and then lifts, rather than lasting into a later turn.
			var immortality = Effect.immortality_effect(1)
			immortality.set_source(moveset.base_abilities[4])
			Character.add_allied_effect(QueryContext.from_game_state(self, battle), self, self, immortality)
		if is_immortal():
			health.set_health(1)
			update.emit()
		else:
			if health.hp > 0:
				health.set_health(0)
			if killer != null:
				if source is Ability:
					source.on_kill(self)
				killer.check_kill_triggers(source, self)
			dead = true
			check_death_triggers(killer)
			cleanse_death_effects()
			update.emit()
			if battle:
				battle.character_died.emit(self)
				if battle.has_method("log_death"):
					battle.log_death(self)
		refresh(dead)

func cleanse_death_effects():
	# 1) Strip effects this dying character CAST onto anyone (user == self) — the existing behavior.
	for character in battle.all_characters():
		for effect in character.effects.get_all_death_cleansable_effects(self):
			character.effects.erase_effect(effect)
	# 2) The dying character also loses every CLEANSEABLE effect currently ON THEM, whoever applied it
	# (an enemy's HEALTH_CAP, debuffs, buffs, DoTs, etc.). Only cleansable=false identity/machinery
	# survives, so a later revive comes back clean — e.g. free of an enemy's health cap rather than
	# stuck under a maximum below its revive HP.
	for effect in effects._effects.duplicate():
		if effect.cleansable:
			effects.erase_effect(effect)

func pretty_print():
	print(_name.show())
	stats.pretty_print(self)
	effects.pretty_print()
	moveset.pretty_print()
	
func refresh(death = false):
	waiting = dead
	targeter.reset()
	check_cancels()
	bot_acted = false
	if not death:
		acted = false
	used_ability=null
	update.emit()

func team_update():
	for character in team.characters:
		character.update.emit()

func set_targeted():
	targeted = true
	update.emit()


func set_untargeted():
	targeted = false
	update.emit()


func blind_check():
	if shrug_off_type(EffectType.Type.BLIND):
		return false
	var blind_effects = effects.get_effects_by_type(EffectType.Type.BLIND)
	#TODO: Add ignore check
	for blind_effect in blind_effects:
		for exclusion_target in blind_effect.exclusion_targets:
			if used_ability != null and used_ability.classes[exclusion_target]:
				continue
		if len(blind_effect.ability_targets) < 1:
			return true
		for class_target in blind_effect.ability_targets:
			if used_ability != null and used_ability.classes[class_target]:
				return true
		
		
	return false

func resolve_taunt():
	if shrug_off_type(EffectType.Type.TAUNT):
		return false
	var taunt_effects = effects.get_effects_by_type(EffectType.Type.TAUNT)
	var relevant_taunt = taunt_effects[0]
	var targets = []
	for target in targeter.targets:
		targets.append(target)
	for target in targets:
		if not target in team.characters:
			targeter.remove_target(target)
	targeter.targets.append(relevant_taunt.user)
	if not targeter.main_target in team.characters:
		targeter.main_target = relevant_taunt.user

func other_character_clicked(character):
	update.emit()
	if not targeter.targeting:
		return
	
	targeter.add_target(character)
	targeter.main_target = character
	used_ability = targeter.targeting_ability
	var ttype = targeter.targeting_ability.target_type()
	if blind_check():
		if ttype == TargetType.Type.ALL or ttype == TargetType.Type.ALL_FACTION or ttype == TargetType.Type.SELF:
			pass
		else:
			targeter.targeting_ability.ability_blinded = true
			ttype = TargetType.Type.ALL
	if ttype == TargetType.Type.ALL:
		request_aoe_targets.emit(self, character, false, used_ability.and_targeter)
	elif ttype == TargetType.Type.ALL_FACTION:
		request_aoe_targets.emit(self, character, true, used_ability.and_targeter)
	elif used_ability.and_targeter:
		request_aoe_targets.emit(self, character, false, true)
	team.pay_for_ability(used_ability)
	waiting = true
	targeter.end_targeting()
	finished_targeting.emit()

func gain_mark(user, source, duration, desc, stackable=false):
	var context = QueryContext.from_game_state(user, user.battle)
	var mark = Effect.mark(duration, desc)
	mark.set_source(source)
	mark.stackable = stackable
	if stackable:
		mark.display_stacks = true
	if user in team.characters:
		Character.add_allied_effect(context, user, self, mark)
	else:
		Character.add_hostile_effect(context, user, self, mark)

func get_mark_stacks(eff_name):
	if has_effect(eff_name, EffectType.Type.MARK):
		return has_effect(eff_name, EffectType.Type.MARK).stacks
	else:
		return 0

func request_hover_panel(panel, tooltip):
	
	request_panel.emit(panel, tooltip)
	
func request_hide_panel():
	hide_panel.emit()

func hp_hidden():
	var freeze = has_effect("Texture Surprise", EffectType.Type.HISOKA_HEALTH_FREEZE)
	if freeze:
		if freeze.user.enemy:
			return true
	return false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func get_action(bot_difficulty):
	var context = QueryContext.from_game_state(self, battle)
	var abilities = moveset.get_active_abilities(self)
	var priority_sets = []
	for ability in abilities:
		priority_sets.append(ability.get_target_variation_priorities(context, bot_difficulty))
	for priority_set in priority_sets:
		priority_set[0] += randi_range(-bot_difficulty, bot_difficulty)
	var sort_func = func (a, b):
		return a[0] > b[0]
	priority_sets.sort_custom(sort_func)
	return priority_sets[0]

static func from_character_name(char_name):
	# Player-authored characters have no character/<name>.tscn — they are built
	# from a validated spec by AuthoredRegistry, using the same 7-component
	# template (and the load-bearing died->die wiring) as shipped characters.
	if AuthoredRegistry.is_authored(char_name):
		return AuthoredRegistry.build_character(char_name)
	var character = load("res://character/" + char_name + ".tscn").instantiate()
	character.initialize()
	return character

static func add_allied_effect(context, user, target, effect, bypassing = false):
	# (Silence no longer blocks effect application here. Silence is now purely a usability gate -
	# "non-damaging skills cannot be used", enforced in Ability.is_silenced_out(). A Damaging skill
	# that a silenced character CAN still use applies its effects normally.)
	if Condition.can_apply_allied_effect(user, target, effect, bypassing).satisfied(context):
		effect.id = context.id
		user.apply_effect(effect, target)
		if context.battle and context.battle.has_method("log_effect_applied"):
			context.battle.log_effect_applied(user, target, effect)
	else:
		_free_unapplied_effect(effect)

static func add_hostile_effect(context, user, target, effect, bypassing = false):
	if target.is_ignoring_skill(effect.source, context):   # Casseur de Logistille (keyed on effect.source, like invuln)
		_free_unapplied_effect(effect)
		return
	# (Silence no longer blocks effect application here. Silence is now purely a usability gate -
	# "non-damaging skills cannot be used", enforced in Ability.is_silenced_out(). A Damaging skill
	# that a silenced character CAN still use applies its effects normally.)
	# ignores_effect, not shrug_off_type: a non-ignorable effect (Mahapadma / Swords) lands even against
	# "ignore all non-damage effects" / a specific type-ignore — that is what ignorable=false buys.
	if target.ignores_effect(effect):
		_free_unapplied_effect(effect)
		return
	if Condition.can_apply_hostile_effect(user, target, effect, bypassing).satisfied(context):
		if target.negate_harmful_effect(effect, context):   # Ainz — The Goal of all Life is Death
			_free_unapplied_effect(effect)
			return
		effect.id = context.id
		user.apply_effect(effect, target)
		if context.battle and context.battle.has_method("log_effect_applied"):
			context.battle.log_effect_applied(user, target, effect)
	else:
		_free_unapplied_effect(effect)

# A rejected effect Node is stored nowhere — nothing else will ever free it.
# Deferred free (never free()): the creating ability may still read/write
# fields on it later in the same frame. Skip effects that are already owned
# (a re-application of a stored effect must not free the live node).
static func _free_unapplied_effect(effect):
	if effect != null and is_instance_valid(effect) and effect.get_parent() == null:
		effect.queue_free()

static func resolve_damage(context, target, pre_mod_damage, damage_type):
	var owner = context['owner']
	if not owner.used_ability:
		return
	if target.is_ignoring_skill(owner.used_ability, context):   # Casseur de Logistille
		return
	var mod_damage = owner.used_ability.get_true_damage(owner, target, pre_mod_damage, null, damage_type)
	if mod_damage < owner.used_ability.minimum_damage:
		mod_damage = owner.used_ability.minimum_damage
	if not target.is_ignoring_damage(true, owner):
		# Snapshot Yubel's reflect BEFORE the hit — a lethal hit erases the markers
		# mid-call (see _capture_reflect), so looking them up afterwards finds nothing.
		var reflect_state = Character._capture_reflect(target)
		context.battle.log_damage(owner, target, mod_damage, damage_type, owner.used_ability)
		owner.deal_ability_damage(owner.used_ability, mod_damage, target, damage_type)
		Character._fire_reflect(reflect_state, target, owner, mod_damage)
	else:
		context.battle.log_invuln_block(owner, target, owner.used_ability)

static func resolve_effect_damage(context, eff, target, pre_mod_damage, damage_type):
	var mod_damage = eff.source.get_true_damage(eff.user, target, pre_mod_damage, eff, damage_type)
	if not target.is_ignoring_damage(false, eff.user):
		var reflect_state = Character._capture_reflect(target)   # see resolve_damage
		context.battle.log_damage(eff.user, target, mod_damage, damage_type, eff.source, eff)
		eff.user.deal_effect_damage(eff, mod_damage, target, damage_type)
		Character._fire_reflect(reflect_state, target, eff.user, mod_damage)
	else:
		context.battle.log_invuln_block(eff.user, target, eff.source)


# Yubel's Terror Incarnate (S3) / Ultimate Nightmare (S5): the damage Yubel takes
# from an enemy skill is reflected back — to the attacker (S3) or the whole enemy
# team (S5).
#
# Split into capture/fire because the reflect must survive its own lethal hit. The
# damage call can kill Yubel, and die() -> cleanse_death_effects() erases every
# effect she cast (user == self), which is exactly these two markers — so a
# post-damage lookup finds nothing and the killing blow alone went unreflected.
# We therefore resolve the markers up front and hold the Effect references; erase
# only unlinks them from the storage list, so the objects stay valid to act as the
# reflected damage's source.
#
# Returns null (no reflect) for everyone else and for an already-dead target.
static func _capture_reflect(target):
	if target.dead or target.banished:
		return null
	if target.has_effect("Terror Incarnate", EffectType.Type.HARMFUL_RECEIVE_TRIGGER):
		var marks = target.has_effect("Terror Incarnate", EffectType.Type.MARK)
		if marks:
			return {"team_wide": false, "eff": marks}
	elif target.has_effect("Ultimate Nightmare", EffectType.Type.HARMFUL_RECEIVE_TRIGGER):
		var un = target.has_effect("Ultimate Nightmare", EffectType.Type.HARMFUL_RECEIVE_TRIGGER)
		if un:
			return {"team_wide": true, "eff": un}
	return null


# Deal the captured reflect. Uses deal_effect_damage directly (not resolve_*), so
# the reflected hit doesn't re-enter the capture above — no reflect ping-pong.
# Fires even when `target` died to the hit: dying to a blow still returns it.
static func _fire_reflect(reflect_state, target, dealer, amount):
	if reflect_state == null:
		return
	if not reflect_state["team_wide"]:
		target.deal_effect_damage(reflect_state["eff"], amount, dealer, DamageType.Type.NORMAL)
		return
	for character in dealer.team.characters:
		if not (character.dead or character.banished):
			target.deal_effect_damage(reflect_state["eff"], amount, character, DamageType.Type.NORMAL)

static func resolve_healing(context, target, pre_mod_healing):
	var owner = context['owner']
	var mod_healing = owner.used_ability.get_true_healing(owner, target, pre_mod_healing)
	if not target.is_isolated():
		context.battle.log_healing(owner, target, mod_healing, owner.used_ability)
		owner.give_ability_healing(owner.used_ability, mod_healing, target)

static func resolve_effect_healing(context, eff, target, pre_mod_healing):
	var mod_healing = eff.source.get_true_healing(context['owner'], target, pre_mod_healing)
	if not target.is_isolated():
		context.battle.log_healing(eff.user, target, mod_healing, eff.source, eff)
		eff.user.give_effect_healing(eff, mod_healing, target)
