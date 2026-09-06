"""Non-Godot port of scripts/bounty.gd generate_from_details (lines 224-328).

Reads ONLY backend_port/bounty/reference_data.json (the static tables, dumped from the engine once)
plus the four inputs the live server passes: player_name, path_name, rerolls, bounty_type.
Produces the identical 25-square mission list.

Run `python compare.py` to diff this against the engine-captured fixture.

The three details a naive port gets wrong (each verified against the fixture):
  * `categories` INSERTION order is the index space of every category draw. It is NOT alphabetical,
    and webclient/app/bounty_data.json IS alphabetical — do not generate from that file.
  * every randi_range consumes a draw, including randi_range(0, 0) for a 1-element list.
  * the `specific_odds == 1` universe branch is SKIPPED (no draw) when the character is the only
    one in its universe, falling through to the plain-category else. Eight roster characters are
    in that situation today.
"""

import json
import os

from godot_primitives import GodotRNG, godot_hash

HERE = os.path.dirname(os.path.abspath(__file__))
MASTERY_SUFFIX = "_mastery"


class BountyData:
    """The static tables, loaded once."""

    def __init__(self, path=None):
        with open(path or os.path.join(HERE, "reference_data.json"), encoding="utf-8") as fh:
            raw = json.load(fh)
        self.category_order = list(raw["category_order"])
        self.categories = {k: list(raw["categories"][k]) for k in self.category_order}
        self.mission_types = list(raw["mission_types"])
        self.mastery_suffix = raw["mastery_suffix"]
        # char_name_list order == the order CharacterDatabase.by_universe appends in.
        self.char_name_list = list(raw["char_name_list"])
        self.universe_of = {r["path_name"]: r["universe"] for r in raw["roster"]}
        # Every enum value gets a bucket, including universes with no characters — matching
        # by_universe()'s pre-seeded dict (an unknown universe would KeyError in GDScript too).
        self.all_universes = sorted(set(raw["universe_enum"].values()))

    def get_archetypes(self, path_name):
        """bounty.gd get_archetypes: iterate `categories` in insertion order."""
        return [k for k in self.category_order if path_name in self.categories[k]]

    def by_universe(self, exclude_path=""):
        """CharacterDatabase.by_universe: universe ordinal -> [path_name], minus exclude_path."""
        out = {u: [] for u in self.all_universes}
        for name in self.char_name_list:
            if name != exclude_path:
                out[self.universe_of[name]].append(name)
        return out


def generate(data: BountyData, player_name: str, path_name: str, rerolls, bounty_type="unlock"):
    """Port of Bounty.generate_from_details. Returns (missions, seed_input, seed_hash)."""
    requires_bounty_target = bounty_type == "mastery"
    seed_input = "%s%s%s" % (player_name, path_name, rerolls)
    if requires_bounty_target:
        seed_input += MASTERY_SUFFIX
    seed_hash = godot_hash(seed_input)
    rng = GodotRNG(seed_hash)

    categories = data.categories
    bounty_types = data.get_archetypes(path_name)
    if not bounty_types:
        # bounty.gd's guard: a character in no category would index bounty_types[-1].
        bounty_types = list(data.category_order)

    universe_dict = data.by_universe(path_name)
    same_universe = universe_dict[data.universe_of[path_name]]

    missions = []
    for _ in range(25):
        mission_type = data.mission_types[rng.randi_range(0, 5)]
        details = [mission_type]

        if mission_type == "with":
            specific_odds = rng.randi_range(0, 4)
            bounty_category = bounty_types[rng.randi_range(0, len(bounty_types) - 1)]
            if not specific_odds:
                members = categories[bounty_category]
                specific_target = members[rng.randi_range(0, len(members) - 1)]
                if specific_target == path_name:
                    details.append([bounty_category])
                    details.append(6)
                else:
                    details.append([specific_target])
                    details.append(4)
            elif specific_odds == 1 and len(same_universe) != 0:
                specific_target = same_universe[rng.randi_range(0, len(same_universe) - 1)]
                details.append([specific_target])
                details.append(4)
            else:
                details.append([bounty_category])
                details.append(6)

        elif mission_type == "against":
            specific_odds = rng.randi_range(0, 8)
            bounty_category = bounty_types[rng.randi_range(0, len(bounty_types) - 1)]
            if not specific_odds:
                members = categories[bounty_category]
                specific_target = members[rng.randi_range(0, len(members) - 1)]
                if specific_target == path_name:
                    details.append([bounty_category])
                    details.append(4)
                else:
                    details.append([specific_target])
                    details.append(3)
            elif specific_odds == 1 and len(same_universe) != 0:
                specific_target = same_universe[rng.randi_range(0, len(same_universe) - 1)]
                details.append([specific_target])
                details.append(3)
            else:
                details.append([bounty_category])
                details.append(4)

        else:  # "versus"
            with_specific_odds = rng.randi_range(0, 4)
            target_specific_odds = rng.randi_range(0, 8)
            with_bounty_category = bounty_types[rng.randi_range(0, len(bounty_types) - 1)]
            target_bounty_category = bounty_types[rng.randi_range(0, len(bounty_types) - 1)]
            versus_details = []

            if not with_specific_odds:
                members = categories[with_bounty_category]
                specific_target = members[rng.randi_range(0, len(members) - 1)]
                if specific_target == path_name:
                    versus_details.append(with_bounty_category)
                    # NOTE: the GDScript rewrites the odds variable here, and win_count is
                    # computed from it AFTERWARDS — so this self-target collision is scored as
                    # if it had been a specific pick (2 points), not as a category (1).
                    with_specific_odds = 1
                else:
                    versus_details.append(specific_target)
            elif with_specific_odds == 1 and len(same_universe) != 0:
                specific_target = same_universe[rng.randi_range(0, len(same_universe) - 1)]
                versus_details.append(specific_target)
            else:
                versus_details.append(with_bounty_category)

            if not target_specific_odds:
                members = categories[target_bounty_category]
                specific_target = members[rng.randi_range(0, len(members) - 1)]
                if specific_target == path_name:
                    versus_details.append(target_bounty_category)
                    target_specific_odds = 1
                else:
                    versus_details.append(specific_target)
            elif target_specific_odds == 1 and len(same_universe) != 0:
                specific_target = same_universe[rng.randi_range(0, len(same_universe) - 1)]
                versus_details.append(specific_target)
            else:
                versus_details.append(target_bounty_category)

            details.append(versus_details)
            win_count = 2 if with_specific_odds else 1
            win_count += 1 if target_specific_odds else 0
            details.append(win_count)

        missions.append(details)

    return missions, seed_input, seed_hash
