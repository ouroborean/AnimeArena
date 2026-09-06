extends Node
# Clan Officer rank (2026-08-14): a role between Leader and Member. Officers can invite / accept /
# remove regular members; only the Leader can promote to / remove Officer or change the picture.
# Verifies the pure permission predicates + the promote/demote mechanic on a bare ServerConnection.

var pass_n := 0
var fail_n := 0
func ck(label: String, cond: bool) -> void:
	if cond: pass_n += 1; print("  PASS  " + label)
	else: fail_n += 1; printerr("  FAIL  " + label)

func _make_clan(leaders, officers, members):
	var c = load("res://components/clan.tscn").instantiate()
	c.members = {Clan.Rank.LEADER: leaders, Clan.Rank.OFFICER: officers, Clan.Rank.MEMBER: members}
	return c

func _ready() -> void:
	print("=== clan officer probe ===")
	var sc = load("res://components/server_connection.gd").new()
	var clan = _make_clan(["Lead"], ["Off"], ["Mem"])

	# --- permission predicates ---
	ck("leader is leader", sc._clan_is_leader(clan, "Lead"))
	ck("officer is NOT leader", not sc._clan_is_leader(clan, "Off"))
	ck("officer is officer", sc._clan_is_officer(clan, "Off"))
	ck("leader can manage (invite/accept/kick)", sc._clan_can_manage(clan, "Lead"))
	ck("officer can manage", sc._clan_can_manage(clan, "Off"))
	ck("member can NOT manage", not sc._clan_can_manage(clan, "Mem"))

	# --- promote: Member -> Officer (leader-only action; here the state change itself) ---
	clan.change_rank("Mem", Clan.Rank.OFFICER)
	ck("promoted Mem is now an Officer", sc._clan_is_officer(clan, "Mem"))
	ck("promoted Mem left the Member list", not ("Mem" in clan.members[Clan.Rank.MEMBER]))
	ck("promoted Mem can now manage", sc._clan_can_manage(clan, "Mem"))

	# --- demote: Officer -> Member ---
	clan.change_rank("Off", Clan.Rank.MEMBER)
	ck("demoted Off is now a Member", ("Off" in clan.members[Clan.Rank.MEMBER]) and not sc._clan_is_officer(clan, "Off"))
	ck("demoted Off can NO LONGER manage", not sc._clan_can_manage(clan, "Off"))

	# --- kick guard: an officer may NOT remove another officer; the leader may ---
	var clan2 = _make_clan(["Lead"], ["OffA", "OffB"], ["Mem"])
	# _json_clan_kick blocks when: actor is NOT leader AND target is an officer
	var officer_blocked = (not sc._clan_is_leader(clan2, "OffA")) and ("OffB" in clan2.members.get(Clan.Rank.OFFICER, []))
	ck("an officer is blocked from removing another officer", officer_blocked)
	ck("the leader is NOT blocked from removing an officer", sc._clan_is_leader(clan2, "Lead"))
	# officers CAN remove regular members
	ck("an officer may remove a regular member (can_manage + target is Member)",
		sc._clan_can_manage(clan2, "OffA") and ("Mem" in clan2.members.get(Clan.Rank.MEMBER, [])))

	print("=== DONE — %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
