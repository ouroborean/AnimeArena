// aa-tests.js - non-battle web-client test suite (runs in tests.html via aa-test-harness.js).
// AUTO-ASSEMBLED from per-area modules. Each module is a self-contained IIFE registering
// cases via window.AATest. Covers correctness, idempotency, and resilience.

// ============================================================================
// AREA: mastery/XP math + cosmetics
// ============================================================================
(function () {
  "use strict";
  var H = window.AATest, fns = H.fns, C = H.consts, S = H.S, render = H.render;
  var test = H.test, assert = H.assert, eq = H.eq, deepEq = H.deepEq, near = H.near, noThrow = H.noThrow, throws = H.throws;

  var TH = C.XP_THRESHOLDS, MAXL = C.MAX_LEVEL;

  // ---------------------------------------------------------------- xpToLevel
  test("mastery: xpToLevel boundary at thresholds", function () {
    eq(fns.xpToLevel(0), 0, "xp 0 -> level 0");
    eq(fns.xpToLevel(TH[1] - 1), 0, "just below L1 stays L0");
    eq(fns.xpToLevel(TH[1]), 1, "exactly L1 threshold -> L1");
    eq(fns.xpToLevel(TH[2]), 2, "exactly L2 threshold -> L2");
    eq(fns.xpToLevel(TH[3] - 1), 2, "just below L3 stays L2");
    eq(fns.xpToLevel(TH[3]), 3, "exactly L3 threshold -> L3");
  });

  test("mastery: xpToLevel clamps at MAX_LEVEL", function () {
    eq(fns.xpToLevel(TH[MAXL]), MAXL, "max threshold -> MAX_LEVEL");
    eq(fns.xpToLevel(TH[MAXL] + 1), MAXL, "above max stays MAX_LEVEL");
    eq(fns.xpToLevel(TH[MAXL] * 10), MAXL, "way above stays MAX_LEVEL");
  });

  test("mastery: xpToLevel handles negative/zero gracefully", function () {
    eq(fns.xpToLevel(-1), 0, "negative xp -> level 0");
    eq(fns.xpToLevel(-100000), 0, "very negative -> level 0");
    eq(fns.xpToLevel(0), 0, "zero -> 0");
  });

  test("mastery: xpToLevel is monotonic non-decreasing across thresholds", function () {
    var prev = -1;
    for (var i = 0; i < TH.length; i++) {
      var lv = fns.xpToLevel(TH[i]);
      assert(lv >= prev, "level should not decrease at threshold idx " + i);
      eq(lv, i, "threshold idx " + i + " maps to level " + i);
      prev = lv;
    }
  });

  // -------------------------------------------------- levelProgressFraction
  test("mastery: levelProgressFraction is in [0,1] across a sweep", function () {
    var samples = [0, 1, 50, TH[1], TH[1] + 1, TH[2] - 1, TH[5], TH[5] + 12345, TH[50], TH[99] + 1];
    samples.forEach(function (xp) {
      var f = fns.levelProgressFraction(xp);
      assert(f >= 0 && f <= 1, "fraction in [0,1] for xp " + xp + " got " + f);
    });
  });

  test("mastery: levelProgressFraction = 0 exactly at a level threshold", function () {
    near(fns.levelProgressFraction(TH[1]), 0, 1e-9, "at L1 boundary fraction is 0");
    near(fns.levelProgressFraction(TH[5]), 0, 1e-9, "at L5 boundary fraction is 0");
  });

  test("mastery: levelProgressFraction = 1 at and beyond MAX_LEVEL", function () {
    eq(fns.levelProgressFraction(TH[MAXL]), 1, "at max -> 1");
    eq(fns.levelProgressFraction(TH[MAXL] + 999999), 1, "beyond max -> 1");
  });

  test("mastery: levelProgressFraction midpoint of a level is between 0 and 1", function () {
    var mid = TH[1] + (TH[2] - TH[1]) / 2;
    var f = fns.levelProgressFraction(mid);
    near(f, 0.5, 1e-9, "mid of L1->L2 is ~0.5");
  });

  // --------------------------------------- xpIntoLevel / xpNeededForLevel
  test("mastery: xpIntoLevel is xp minus current level threshold", function () {
    eq(fns.xpIntoLevel(TH[3]), 0, "at threshold, into-level is 0");
    eq(fns.xpIntoLevel(TH[3] + 7), 7, "7 past L3 threshold -> 7");
    eq(fns.xpIntoLevel(0), 0, "0 xp into level is 0");
  });

  test("mastery: xpNeededForLevel equals threshold span, 0 at MAX", function () {
    eq(fns.xpNeededForLevel(TH[1]), TH[2] - TH[1], "L1 span");
    eq(fns.xpNeededForLevel(TH[1] + 5), TH[2] - TH[1], "mid-L1 still full L1 span");
    eq(fns.xpNeededForLevel(TH[MAXL]), 0, "at MAX needed is 0");
    eq(fns.xpNeededForLevel(TH[MAXL] + 100), 0, "beyond MAX needed is 0");
  });

  test("mastery: xpIntoLevel/xpNeededForLevel consistent with fraction", function () {
    var samples = [TH[1] + 1, TH[2] + 50, TH[5] + 9999, TH[10] + 1];
    samples.forEach(function (xp) {
      var into = fns.xpIntoLevel(xp), need = fns.xpNeededForLevel(xp);
      assert(into >= 0 && into < need, "0 <= into(" + into + ") < need(" + need + ") for xp " + xp);
      near(into / need, fns.levelProgressFraction(xp), 1e-9, "into/need == fraction for xp " + xp);
    });
  });

  // ------------------------------------------------------------ masteryLevel
  test("mastery: masteryLevel reads player.mastery_xp[path]", function () {
    H.resetState({ player: { mastery_xp: { naruto: TH[3], luffy: 0 } } });
    eq(fns.masteryLevel("naruto"), 3, "naruto at L3 xp -> 3");
    eq(fns.masteryLevel("luffy"), 0, "luffy at 0 xp -> 0");
  });

  test("mastery: masteryLevel handles missing player / field / key", function () {
    H.resetState({ player: null });
    eq(fns.masteryLevel("naruto"), 0, "null player -> 0");
    H.resetState({ player: {} });
    eq(fns.masteryLevel("naruto"), 0, "no mastery_xp field -> 0");
    H.resetState({ player: { mastery_xp: {} } });
    eq(fns.masteryLevel("naruto"), 0, "missing key -> 0");
  });

  // --------------------------------------------------------- masteryCosmeticId
  test("mastery: masteryCosmeticId id-format per type", function () {
    eq(fns.masteryCosmeticId("playercard", "naruto"), "playercard_mastery_naruto", "playercard id");
    eq(fns.masteryCosmeticId("action_frame", "naruto"), "gamepanel_mastery_naruto", "action_frame id");
    eq(fns.masteryCosmeticId("hat", "naruto"), "hat_mastery_naruto", "hat id");
    eq(fns.masteryCosmeticId("elite_action_frame", "naruto"), "mastery_panel_elite_naruto", "elite id");
  });

  test("mastery: masteryCosmeticId unknown type -> empty string", function () {
    eq(fns.masteryCosmeticId("bogus", "naruto"), "", "unknown type -> ''");
  });

  test("mastery: masteryCosmeticId round-trips path component", function () {
    ["playercard", "action_frame", "hat", "elite_action_frame"].forEach(function (t) {
      var id = fns.masteryCosmeticId(t, "luffy");
      assert(id.indexOf("luffy") === id.length - "luffy".length, t + " id ends with path");
    });
  });

  // ----------------------------------------------- equipCosmetic + isEquipped
  test("cosmetics: equipCosmetic playercard sets player_card and reflects in isCosmeticEquipped", function () {
    H.resetState({ player: { mastery_xp: {}, player_card: "" } });
    fns.equipCosmetic("playercard", "playercard_mastery_naruto", 0);
    eq(S.player.player_card, "playercard_mastery_naruto", "player_card set");
    assert(fns.isCosmeticEquipped("playercard", "playercard_mastery_naruto"), "isCosmeticEquipped true after equip");
    assert(fns.isCosmeticEquippedSlot("playercard", "playercard_mastery_naruto", 0), "slot reflects");
  });

  test("cosmetics: equipCosmetic playercard is idempotent (one logical value)", function () {
    H.resetState({ player: { mastery_xp: {}, player_card: "" } });
    fns.equipCosmetic("playercard", "playercard_mastery_naruto", 0);
    fns.equipCosmetic("playercard", "playercard_mastery_naruto", 0);
    eq(S.player.player_card, "playercard_mastery_naruto", "still single value after double equip");
    assert(fns.isCosmeticEquipped("playercard", "playercard_mastery_naruto"), "still equipped");
  });

  test("cosmetics: equipCosmetic hat targets the requested slot, others untouched", function () {
    H.resetState({ player: { mastery_xp: {} } });
    fns.equipCosmetic("hat", "hat_mastery_luffy", 1);
    assert(Array.isArray(S.player.hats), "hats is array");
    eq(S.player.hats.length, 3, "hats length 3");
    eq(S.player.hats[1], "hat_mastery_luffy", "slot 1 set");
    eq(S.player.hats[0], "None", "slot 0 default untouched");
    assert(fns.isCosmeticEquippedSlot("hat", "hat_mastery_luffy", 1), "slot-specific equipped check");
    assert(!fns.isCosmeticEquippedSlot("hat", "hat_mastery_luffy", 0), "not in slot 0");
    assert(fns.isCosmeticEquipped("hat", "hat_mastery_luffy"), "isCosmeticEquipped any-slot true");
  });

  test("cosmetics: equipCosmetic action_frame targets slot, defaults the rest", function () {
    H.resetState({ player: { mastery_xp: {} } });
    fns.equipCosmetic("action_frame", "gamepanel_mastery_naruto", 2);
    eq(S.player.action_frames.length, 3, "action_frames length 3");
    eq(S.player.action_frames[2], "gamepanel_mastery_naruto", "slot 2 set");
    eq(S.player.action_frames[0], "gamepanel_color_default", "slot 0 default");
    assert(fns.isCosmeticEquipped("action_frame", "gamepanel_mastery_naruto"), "any-slot equipped");
    assert(!fns.isCosmeticEquippedSlot("action_frame", "gamepanel_mastery_naruto", 0), "not slot 0");
  });

  test("cosmetics: elite_action_frame shares the action_frames array with action_frame", function () {
    H.resetState({ player: { mastery_xp: {} } });
    fns.equipCosmetic("elite_action_frame", "mastery_panel_elite_naruto", 0);
    eq(S.player.action_frames[0], "mastery_panel_elite_naruto", "elite writes action_frames slot");
    assert(fns.isCosmeticEquipped("elite_action_frame", "mastery_panel_elite_naruto"), "elite equipped via action_frames");
  });

  test("cosmetics: equipCosmetic re-equipping a different id replaces in slot", function () {
    H.resetState({ player: { mastery_xp: {} } });
    fns.equipCosmetic("hat", "hat_mastery_a", 0);
    fns.equipCosmetic("hat", "hat_mastery_b", 0);
    eq(S.player.hats[0], "hat_mastery_b", "slot replaced");
    assert(!fns.isCosmeticEquipped("hat", "hat_mastery_a"), "old id no longer equipped");
    eq(S.player.hats.length, 3, "still length 3");
  });

  test("cosmetics: equipCosmetic with null player is a no-op (no send)", function () {
    H.resetState({ player: null });
    noThrow(function () { fns.equipCosmetic("playercard", "playercard_mastery_naruto", 0); }, "no-op on null player");
    eq(S.player, null, "player stays null");
    eq(H.sentOfType("save_cosmetics").length, 0, "no save frame sent");
  });

  // ---------------------------------------------------------- saveCosmetics
  test("cosmetics: saveCosmetics sends a save_cosmetics frame reflecting equips", function () {
    H.resetState({ player: { mastery_xp: {}, player_card: "", ap: 42 } });
    fns.equipCosmetic("playercard", "playercard_mastery_naruto", 0);
    var f = H.lastSent("save_cosmetics");
    assert(f, "a save_cosmetics frame was sent");
    eq(f.type, "save_cosmetics", "frame type");
    assert(f.payload && f.payload.update, "payload has update");
    eq(f.payload.update.player_card, "playercard_mastery_naruto", "update reflects equipped player_card");
  });

  test("cosmetics: saveCosmetics payload OMITS mastery_xp (known gotcha)", function () {
    H.resetState({ player: { mastery_xp: { naruto: 99999 }, player_card: "", ap: 10 } });
    fns.saveCosmetics();
    var f = H.lastSent("save_cosmetics");
    assert(f, "frame sent");
    assert(!("mastery_xp" in f.payload.update), "update must NOT contain mastery_xp");
  });

  test("cosmetics: makeCosmeticUpdate omits mastery_xp and echoes known fields with defaults", function () {
    var upd = fns.makeCosmeticUpdate({ ap: 7, player_card: "pc1" });
    assert(!("mastery_xp" in upd), "no mastery_xp key");
    eq(upd.ap, 7, "ap echoed");
    eq(upd.player_card, "pc1", "player_card echoed");
    eq(upd.clan, "Clanless", "clan default applied when absent");
    deepEq(upd.hats, [], "hats default []");
    eq(upd.cosmetics_on, false, "cosmetics_on default false");
  });

  test("cosmetics: makeCosmeticUpdate resilient to empty object", function () {
    var upd = noThrow(function () { return fns.makeCosmeticUpdate({}); }, "empty object input");
    eq(upd.ap, 0, "ap default 0");
    eq(upd.title, "", "title default ''");
    assert(!("mastery_xp" in upd), "still omits mastery_xp");
  });

  test("cosmetics: saveCosmetics no-op when player is null", function () {
    H.resetState({ player: null });
    noThrow(function () { fns.saveCosmetics(); }, "saveCosmetics on null player");
    eq(H.sentOfType("save_cosmetics").length, 0, "no frame sent");
  });

  // ------------------------------------------------- defaultPreviewPath + url
  test("cosmetics: defaultPreviewPath returns a valid roster path or null, no throw", function () {
    H.resetState({ player: { mastery_xp: {} } });
    ["playercard", "action_frame", "hat", "elite_action_frame"].forEach(function (tab) {
      var p = noThrow(function () { return fns.defaultPreviewPath(tab); }, "defaultPreviewPath(" + tab + ")");
      if (p !== null) {
        assert((S.roster || []).some(function (r) { return r.path_name === p; }), "returned path is in roster: " + p);
      }
    });
  });

  test("cosmetics: defaultPreviewPath resilient to null player and empty roster", function () {
    H.resetState({ player: null });
    noThrow(function () { fns.defaultPreviewPath("playercard"); }, "null player");
    H.resetState({ player: { mastery_xp: {} }, roster: [] });
    eq(fns.defaultPreviewPath("playercard"), null, "empty roster -> null");
  });

  test("cosmetics: cosmeticUrl builds a servable url from dir + id", function () {
    var u = fns.cosmeticUrl("playercards", "playercard_mastery_naruto");
    assert(typeof u === "string" && u.length > 0, "url is a non-empty string");
    assert(u.indexOf("playercard_mastery_naruto.png") !== -1, "url contains id.png");
    assert(u.indexOf("playercards") !== -1, "url contains dir");
  });

  // ------------------------------------------------------- renderer resilience
  test("cosmetics: cosmeticsMenu renders for each tab without throwing on minimal player", function () {
    ["playercard", "action_frame", "hat", "elite_action_frame", "background"].forEach(function (tab) {
      H.resetState({ player: { mastery_xp: {} }, cosmeticTab: tab });
      var node = noThrow(function () { return fns.cosmeticsMenu(); }, "cosmeticsMenu(" + tab + ")");
      assert(node && node.querySelectorAll, "returns a DOM node for " + tab);
      assert(node.querySelectorAll(".cos-tab").length >= 5, "renders the tab buttons");
    });
  });

  // ------------------------------------------------------------- backgrounds
  test("cosmetics: equipBackground sets the targeted field and saves (no other field touched)", function () {
    H.resetState({ player: { unlocks: ["background_ingame_shiro"], ingame_background: "", charselect_background: "" } });
    fns.equipBackground("ingame_background", "background_ingame_shiro");
    eq(S.player.ingame_background, "background_ingame_shiro", "ingame set");
    eq(S.player.charselect_background, "", "charselect untouched");
    assert(H.sentOfType("save_cosmetics").length === 1, "saved once");
    fns.equipBackground("ingame_background", "");   // clear
    eq(S.player.ingame_background, "", "cleared");
  });

  test("cosmetics: equipBackground with null player is a no-op (no send)", function () {
    H.resetState({ player: null });
    noThrow(function () { fns.equipBackground("ingame_background", "background_ingame_shiro"); }, "no-op on null player");
    assert(H.sentOfType("save_cosmetics").length === 0, "no save sent");
  });

  test("cosmetics: bgStyle returns an image rule for an id, empty string for none", function () {
    assert(fns.bgStyle("background_ingame_shiro").indexOf("background-image") !== -1, "id -> background-image");
    assert(fns.bgStyle("background_ingame_shiro").indexOf("background_ingame_shiro") !== -1, "id appears in url");
    eq(fns.bgStyle(""), "", "empty id -> no rule");
    eq(fns.bgStyle(null), "", "null id -> no rule");
  });

  test("cosmetics: background tab lists owned backgrounds + a None option, marks the equipped one", function () {
    H.resetState({ player: { unlocks: ["background_ingame_shiro"], ingame_background: "background_ingame_shiro", charselect_background: "" }, cosmeticTab: "background", bgTarget: "ingame" });
    var node = fns.cosmeticsMenu();
    var cells = node.querySelectorAll(".bg-cell");
    assert(cells.length === 2, "None + 1 owned");
    assert(node.querySelectorAll(".bg-cell.equipped").length === 1, "equipped one is marked");
    // switching the target to char-select (which has none equipped) marks only None
    H.resetState({ player: { unlocks: ["background_ingame_shiro"], ingame_background: "background_ingame_shiro", charselect_background: "" }, cosmeticTab: "background", bgTarget: "charselect" });
    var node2 = fns.cosmeticsMenu();
    var eqCells = node2.querySelectorAll(".bg-cell.equipped");
    assert(eqCells.length === 1 && eqCells[0].textContent.indexOf("None") !== -1, "None marked for the empty charselect target");
  });

  test("cosmetics: background tab populates for an all_unlock account (owns everything implicitly)", function () {
    var bgCount = ((S.shopCatalog && S.shopCatalog.items && S.shopCatalog.items.background) || []).length;
    assert(bgCount > 0, "catalog has backgrounds");
    H.resetState({ player: { unlocks: ["all_unlock"], ingame_background: "", charselect_background: "" }, cosmeticTab: "background", bgTarget: "ingame" });
    var cells = fns.cosmeticsMenu().querySelectorAll(".bg-cell");
    eq(cells.length, bgCount + 1, "None + every catalog background");
  });

  // ------------------------------------------------ ability source_basename -> key aliasing
  test("abilities: resolveAbilityKey maps divergent script basenames via the alias map, else passes through", function () {
    // Post-fix, Saitama's script basenames == their keys, so they pass through untouched.
    eq(fns.resolveAbilityKey("saitama2"), "saitama2", "saitama2 (key == script) passes through");
    eq(fns.resolveAbilityKey("saitama5"), "saitama5", "saitama5 passes through");
    eq(fns.resolveAbilityKey("naruto1"), "naruto1", "unrelated ability passes through");
    // every entry in the loaded alias map resolves to its key (only genuine divergences remain)
    var aliases = S.abilityAliases || {};
    Object.keys(aliases).forEach(function (sb) { eq(fns.resolveAbilityKey(sb), aliases[sb], sb + " -> " + aliases[sb]); });
    // the mechanism still maps a genuine divergence (synthetic)
    H.resetState({ abilityAliases: { foo5: "foo2" } });
    eq(fns.resolveAbilityKey("foo5"), "foo2", "alias entry resolves");
    eq(fns.resolveAbilityKey("foo1"), "foo1", "non-entry passes through");
  });

  test("abilities: ingestSnapshot rewrites ability source_basename via the alias map in place", function () {
    // Saitama (post-fix) needs no aliasing: source_basename == key, so ingest is identity and
    // each key looks up the matching ability.
    var snap = { sides: [ { role: "p1", team: [ { path_name: "saitama", abilities: [
      { source_basename: "saitama1", ability_name: "Normal Punch" },
      { source_basename: "saitama2", ability_name: "Consecutive Normal Punches" },
    ] } ] } ] };
    var out = fns.ingestSnapshot(snap);
    eq(out.sides[0].team[0].abilities[0].source_basename, "saitama1", "identity");
    eq(out.sides[0].team[0].abilities[1].source_basename, "saitama2", "identity");
    eq((S.abilityInfo["saitama2"] || {}).name, "Consecutive Normal Punches", "key looks up correct ability info");
    // with a genuine divergence in the map, ingest rewrites the source_basename
    H.resetState({ abilityAliases: { foo5: "foo2" } });
    var snap2 = { sides: [ { role: "p1", team: [ { path_name: "x", abilities: [ { source_basename: "foo5" }, { source_basename: "bar1" } ] } ] } ] };
    fns.ingestSnapshot(snap2);
    eq(snap2.sides[0].team[0].abilities[0].source_basename, "foo2", "foo5 -> foo2");
    eq(snap2.sides[0].team[0].abilities[1].source_basename, "bar1", "bar1 unchanged");
  });

  test("mastery: masteryMenu and masteryDetail render without throwing on null/empty player", function () {
    H.resetState({ player: null });
    noThrow(function () { fns.masteryMenu(); }, "masteryMenu null player");
    H.resetState({ player: { mastery_xp: {} } });
    var menu = noThrow(function () { return fns.masteryMenu(); }, "masteryMenu empty mastery");
    assert(menu.querySelectorAll(".mastery-badge").length > 0, "renders mastery badges");
    var detail = noThrow(function () { return fns.masteryDetail("naruto"); }, "masteryDetail naruto");
    assert(detail && detail.className.indexOf("mastery-detail") !== -1, "detail node class");
  });

  // Per-character list menus (mastery/cosmetics/bounties) sort by DISPLAY NAME via the shared
  // rosterByName() helper, so a character appended to roster.json (e.g. impmon, added last) slots
  // into alphabetical place instead of being stranded at the end.
  test("menus: per-character lists sort by display name and never mutate S.roster", function () {
    var roster = [
      { path_name: "mid", name: "Mid" },
      { path_name: "zed", name: "Zeta" },
      { path_name: "alp", name: "alpha" },   // lowercase -> exercises casefold vs "Mid"/"Zeta"
      { path_name: "imp", name: "Impmon" },  // "appended" last but must sort into the middle
      { path_name: "aa2", name: "alpha" },   // duplicate name -> deterministic path_name tiebreak (aa2 < alp)
    ];
    H.resetState({ roster: roster, player: { username: "T", unlocks: ["all_unlock"], mastery_xp: {} }, masteryChar: null });
    eq(fns.rosterByName().map(function (r) { return r.name + ":" + r.path_name; }).join(","),
       "alpha:aa2,alpha:alp,Impmon:imp,Mid:mid,Zeta:zed", "rosterByName: casefold-alpha by name, path_name tiebreak");
    // must return a COPY — gridArea's CHAR_SELECT_RANK sort depends on S.roster staying in file order
    eq(S.roster.map(function (r) { return r.path_name; }).join(","), "mid,zed,alp,imp,aa2", "S.roster left in original order");
    // the mastery grid (tile title == c.name) renders in sorted order; the appended "Impmon" is not last
    var titles = Array.prototype.map.call(fns.masteryMenu().querySelectorAll(".mastery-cell"), function (n) { return n.getAttribute("title"); });
    eq(titles.join(","), "alpha,alpha,Impmon,Mid,Zeta", "mastery grid sorted by display name; appended char slots into place");
  });

  test("mastery: masteryDetail at MAX level renders MAX label without throwing", function () {
    H.resetState({ player: { mastery_xp: { naruto: TH[MAXL] } } });
    var detail = noThrow(function () { return fns.masteryDetail("naruto"); }, "masteryDetail at MAX");
    assert(detail.textContent.indexOf("MAX") !== -1, "shows MAX label at level 100");
  });
})();

// ============================================================================
// AREA: bounty core logic + lifecycle
// ============================================================================
(function () {
  "use strict";
  var H = window.AATest, fns = H.fns, C = H.consts, S = H.S, render = H.render;
  var test = H.test, assert = H.assert, eq = H.eq, deepEq = H.deepEq, near = H.near, noThrow = H.noThrow, throws = H.throws;

  // Build a full 25-mission card. Each mission is ["with", ["naruto"], goal].
  function mkMissions(goal) {
    goal = goal == null ? 1 : goal;
    var out = [];
    for (var i = 0; i < 25; i++) out.push(["with", ["naruto"], goal]);
    return out;
  }
  function zeros() { return new Array(25).fill(0); }

  // ---- bountyOwned ----------------------------------------------------------
  test("bounty: bountyOwned true for a starter character", function () {
    H.resetState({ player: { unlocks: [] } });
    // naruto is a starter in bounty_data.json
    assert(fns.bountyOwned("naruto"), "naruto is a starter, should be owned");
  });

  test("bounty: bountyOwned true via path_unlock", function () {
    H.resetState({ player: { unlocks: ["gray_unlock"] } });
    assert(fns.bountyOwned("gray"), "gray owned via gray_unlock");
    assert(!fns.bountyOwned("itachi"), "itachi not owned (no unlock, not starter)");
  });

  test("bounty: bountyOwned true via all_unlock", function () {
    H.resetState({ player: { unlocks: ["all_unlock"] } });
    assert(fns.bountyOwned("itachi"), "all_unlock grants every character");
    assert(fns.bountyOwned("some_random_path"), "all_unlock is universal");
  });

  test("bounty: bountyOwned resilient to null player", function () {
    H.resetState({ player: null });
    noThrow(function () { fns.bountyOwned("naruto"); }, "no player should not throw");
    // naruto is still a starter even without a player
    eq(fns.bountyOwned("naruto"), true, "starter owned regardless of player");
    eq(fns.bountyOwned("itachi"), false, "non-starter not owned with null player");
  });

  // ---- bountyKeyFor ---------------------------------------------------------
  test("bounty: bountyKeyFor mastery appends suffix, unlock leaves raw", function () {
    H.resetState({});
    eq(fns.bountyKeyFor("naruto", "mastery"), "naruto" + C.MASTERY_SUFFIX, "mastery key");
    eq(fns.bountyKeyFor("naruto", "unlock"), "naruto", "unlock key is raw");
    eq(fns.bountyKeyFor("naruto", undefined), "naruto", "non-mastery tab -> raw");
    eq(C.MASTERY_SUFFIX, "_mastery", "suffix const value");
  });

  // ---- bountyIsArchetype ----------------------------------------------------
  test("bounty: bountyIsArchetype true for real category, false for character", function () {
    H.resetState({});
    assert(fns.bountyIsArchetype("ninja"), "ninja is a real category");
    assert(fns.bountyIsArchetype("pirate"), "pirate is a real category");
    assert(!fns.bountyIsArchetype("naruto"), "naruto is a character, not a category");
    assert(!fns.bountyIsArchetype("not_a_thing"), "unknown token is not a category");
  });

  test("bounty: bountyIsArchetype resilient to missing bountyData", function () {
    // bountyData is loaded reference data that resetState does NOT restore, so stash + restore it.
    var saved = S.bountyData;
    try {
      H.resetState({ bountyData: null });
      noThrow(function () { fns.bountyIsArchetype("ninja"); }, "no bountyData no throw");
      eq(fns.bountyIsArchetype("ninja"), false, "without data, nothing is an archetype");
    } finally { S.bountyData = saved; }
  });

  // ---- bountyTargetText -----------------------------------------------------
  test("bounty: bountyTargetText 'a Title' for archetype, name for character", function () {
    H.resetState({});
    eq(fns.bountyTargetText("ninja"), "a Ninja", "archetype -> 'a ' + titleCase");
    // 'fairy tail' titlecases per-word
    eq(fns.bountyTargetText("fairy tail"), "a Fairy Tail", "multi-word archetype titlecased");
    // naruto resolves to its roster display name
    eq(fns.bountyTargetText("naruto"), fns.nameFor("naruto"), "character -> display name");
  });

  // ---- bountyTargetImg ------------------------------------------------------
  test("bounty: bountyTargetImg category icon vs portrait", function () {
    H.resetState({});
    var catUrl = fns.bountyTargetImg("ninja");
    assert(typeof catUrl === "string" && catUrl.indexOf("assets/bounty/ninja.png") >= 0,
      "archetype -> bounty category png, got " + catUrl);
    eq(fns.bountyTargetImg("naruto"), fns.portraitUrlFor("naruto"), "character -> portrait url");
  });

  // ---- missionText ----------------------------------------------------------
  test("bounty: missionText with/against/versus phrasing", function () {
    H.resetState({});
    eq(fns.missionText(["with", ["ninja"], 3]), "Win with a Ninja", "with archetype");
    eq(fns.missionText(["against", ["ninja"], 2]), "Win against a Ninja", "against archetype");
    eq(fns.missionText(["versus", ["ninja", "pirate"], 1]), "Win with a Ninja vs a Pirate", "versus two archetypes");
    eq(fns.missionText(["with", ["naruto"], 1]), "Win with " + fns.nameFor("naruto"), "with character");
  });

  test("bounty: missionText resilient to missing target array", function () {
    H.resetState({});
    // unknown type falls through to returning the type string
    eq(fns.missionText(["mystery", null, 1]), "mystery", "unknown type returns type");
    noThrow(function () { fns.missionText(["with", null, 1]); }, "null targets should not throw");
  });

  // ---- bountyCompleted ------------------------------------------------------
  test("bounty: bountyCompleted true when a full winning row meets thresholds", function () {
    H.resetState({});
    var missions = mkMissions(1);          // every goal = 1
    var progress = zeros();
    // satisfy the top row [0,1,2,3,4]
    [0, 1, 2, 3, 4].forEach(function (i) { progress[i] = 1; });
    eq(fns.bountyCompleted(progress, missions), true, "top row complete -> done");
  });

  test("bounty: bountyCompleted false when no full pattern met", function () {
    H.resetState({});
    var missions = mkMissions(2);
    var progress = zeros();
    // partial - 4 of 5 in the top row, and one short on the 5th
    progress[0] = 2; progress[1] = 2; progress[2] = 2; progress[3] = 2; progress[4] = 1;
    eq(fns.bountyCompleted(progress, missions), false, "incomplete row -> not done");
  });

  test("bounty: bountyCompleted true for a diagonal pattern", function () {
    H.resetState({});
    var missions = mkMissions(1);
    var progress = zeros();
    // diagonal [0,6,12,18,24]
    [0, 6, 12, 18, 24].forEach(function (i) { progress[i] = 1; });
    eq(fns.bountyCompleted(progress, missions), true, "diagonal complete -> done");
  });

  test("bounty: bountyCompleted resilient to null progress / null missions / no data", function () {
    H.resetState({});
    eq(fns.bountyCompleted(null, mkMissions(1)), false, "null progress -> false");
    eq(fns.bountyCompleted(zeros(), null), false, "null missions -> false");
    // bountyData is loaded reference data that resetState does NOT restore, so stash + restore it.
    var saved = S.bountyData;
    try {
      H.resetState({ bountyData: null });
      eq(fns.bountyCompleted(zeros(), mkMissions(1)), false, "no bountyData -> false");
    } finally { S.bountyData = saved; }
  });

  test("bounty: bountyCompleted treats sparse progress as 0 (no throw)", function () {
    H.resetState({});
    var missions = mkMissions(1);
    var progress = {};                     // object with no indices -> all 0
    noThrow(function () { fns.bountyCompleted(progress, missions); }, "sparse progress no throw");
    eq(fns.bountyCompleted(progress, missions), false, "all-zero progress -> not done");
  });

  // ---- acceptBounty ---------------------------------------------------------
  test("bounty: acceptBounty adds a 25-zero array and sends save_cosmetics", function () {
    H.resetState({ player: { ap: 0, unlocks: [], active_bounties: {} } });
    fns.acceptBounty("naruto");
    assert("naruto" in S.player.active_bounties, "naruto bounty added");
    deepEq(S.player.active_bounties["naruto"], zeros(), "fresh 25-zero progress");
    eq(S.player.active_bounties["naruto"].length, 25, "exactly 25 cells");
    assert(H.lastSent("save_cosmetics"), "save_cosmetics frame sent");
    eq(S.msgKind, "ok", "ok message kind");
  });

  test("bounty: acceptBounty re-accept (below cap) is idempotent on key count and resets progress", function () {
    H.resetState({ player: { ap: 0, unlocks: [], active_bounties: {} } });
    fns.acceptBounty("naruto");
    // mutate progress, then re-accept - should reset to zeros and not duplicate the key
    S.player.active_bounties["naruto"][3] = 9;
    fns.acceptBounty("naruto");
    eq(Object.keys(S.player.active_bounties).length, 1, "still exactly one active bounty");
    deepEq(S.player.active_bounties["naruto"], zeros(), "progress reset to zeros on re-accept");
  });

  test("bounty: acceptBounty capped at BOUNTY_MAX_ACTIVE", function () {
    eq(C.BOUNTY_MAX_ACTIVE, 5, "cap const is 5");
    var ab = {};
    for (var i = 0; i < C.BOUNTY_MAX_ACTIVE; i++) ab["c" + i] = new Array(25).fill(0);
    H.resetState({ player: { ap: 0, unlocks: [], active_bounties: ab } });
    window.__sent = [];                    // clear so we can assert no save frame
    fns.acceptBounty("naruto");
    assert(!("naruto" in S.player.active_bounties), "cap blocks new bounty");
    eq(Object.keys(S.player.active_bounties).length, C.BOUNTY_MAX_ACTIVE, "still at cap");
    eq(S.msgKind, "bad", "cap warning is a bad message");
    eq(H.sentOfType("save_cosmetics").length, 0, "no save_cosmetics when capped");
  });

  test("bounty: acceptBounty initializes active_bounties when missing", function () {
    H.resetState({ player: { ap: 0, unlocks: [] } });  // no active_bounties key
    noThrow(function () { fns.acceptBounty("naruto"); }, "accept with no active_bounties no throw");
    assert(S.player.active_bounties && ("naruto" in S.player.active_bounties), "created and added");
  });

  // ---- cancelBounty ---------------------------------------------------------
  test("bounty: cancelBounty removes the key and sends save_cosmetics", function () {
    H.resetState({ player: { ap: 0, unlocks: [], active_bounties: { naruto: zeros() } } });
    fns.cancelBounty("naruto");
    assert(!("naruto" in S.player.active_bounties), "naruto removed");
    assert(H.lastSent("save_cosmetics"), "save_cosmetics frame sent on cancel");
  });

  test("bounty: cancelBounty of a missing key is a no-op (no throw)", function () {
    H.resetState({ player: { ap: 0, unlocks: [], active_bounties: { other: zeros() } } });
    noThrow(function () { fns.cancelBounty("naruto"); }, "cancel missing key no throw");
    eq(Object.keys(S.player.active_bounties).length, 1, "other bounty untouched");
    assert("other" in S.player.active_bounties, "unrelated bounty preserved");
  });

  test("bounty: cancelBounty resilient when active_bounties undefined", function () {
    H.resetState({ player: { ap: 0, unlocks: [] } });  // no active_bounties
    noThrow(function () { fns.cancelBounty("naruto"); }, "cancel with no active_bounties no throw");
  });

  // ---- rerollBounty ---------------------------------------------------------
  test("bounty: rerollBounty deducts cost once, resets progress, refetches missions", function () {
    eq(C.BOUNTY_REROLL_COST, 1500, "reroll cost const");
    var prog = zeros(); prog[0] = 4;
    H.resetState({
      player: { ap: 5000, unlocks: [], active_bounties: { naruto: prog } },
      bountyTab: "unlock",
      bountyMissions: { naruto: mkMissions(1) },
    });
    fns.rerollBounty("naruto", "naruto");
    eq(S.player.ap, 5000 - C.BOUNTY_REROLL_COST, "AP debited exactly once");
    deepEq(S.player.active_bounties["naruto"], zeros(), "progress reset to zeros");
    eq(S.player.bounty_rerolls["naruto"], 1, "reroll count incremented");
    assert(!("naruto" in S.bountyMissions), "cached missions cleared for refetch");
    assert(H.sentOfType("save_cosmetics").length >= 1, "save_cosmetics sent");
    var bm = H.lastSent("bounty_missions");
    assert(bm, "bounty_missions refetch sent");
    eq(bm.payload.path, "naruto", "refetch path");
    eq(bm.payload.btype, "unlock", "refetch btype matches tab");
  });

  test("bounty: rerollBounty is a no-op when AP < cost", function () {
    var prog = zeros(); prog[5] = 7;
    H.resetState({
      player: { ap: C.BOUNTY_REROLL_COST - 1, unlocks: [], active_bounties: { naruto: prog }, bounty_rerolls: {} },
      bountyMissions: { naruto: mkMissions(1) },
    });
    window.__sent = [];
    fns.rerollBounty("naruto", "naruto");
    eq(S.player.ap, C.BOUNTY_REROLL_COST - 1, "AP unchanged");
    eq(S.player.active_bounties["naruto"][5], 7, "progress untouched");
    deepEq(S.player.bounty_rerolls, {}, "no reroll recorded");
    assert("naruto" in S.bountyMissions, "missions cache untouched");
    eq(H.sentOfType("save_cosmetics").length, 0, "no save when too poor");
    eq(H.sentOfType("bounty_missions").length, 0, "no refetch when too poor");
    eq(S.msgKind, "bad", "bad message when too poor");
  });

  test("bounty: rerollBounty initializes bounty_rerolls map when missing", function () {
    H.resetState({
      player: { ap: 5000, unlocks: [], active_bounties: { naruto: zeros() } },  // no bounty_rerolls
      bountyTab: "mastery",
      bountyMissions: {},
    });
    noThrow(function () { fns.rerollBounty("naruto", "naruto"); }, "reroll without bounty_rerolls no throw");
    eq(S.player.bounty_rerolls["naruto"], 1, "reroll map created and set");
    var bm = H.lastSent("bounty_missions");
    eq(bm.payload.btype, "mastery", "btype reflects active tab not the key");
  });

  // ---- completeBounty -------------------------------------------------------
  test("bounty: completeBounty sends complete_bounty with the key", function () {
    H.resetState({ player: { ap: 0, unlocks: [], active_bounties: { naruto_mastery: zeros() } } });
    fns.completeBounty("naruto_mastery");
    var f = H.lastSent("complete_bounty");
    assert(f, "complete_bounty frame sent");
    eq(f.payload.bounty_path, "naruto_mastery", "sends the bounty key as bounty_path");
    eq(S.msgKind, "ok", "claiming message ok");
  });

  test("bounty: completeBounty does not mutate active_bounties (server authoritative)", function () {
    H.resetState({ player: { ap: 0, unlocks: [], active_bounties: { naruto: zeros() } } });
    fns.completeBounty("naruto");
    assert("naruto" in S.player.active_bounties, "key still present until server echoes");
    eq(H.sentOfType("save_cosmetics").length, 0, "complete does not save_cosmetics");
  });

  // ---- selectBounty ---------------------------------------------------------
  test("bounty: selectBounty sets selection + tab and fetches missions when uncached", function () {
    H.resetState({ player: { ap: 0, unlocks: [] }, bountyMissions: {} });
    fns.selectBounty("naruto", "mastery");
    eq(S.bountySel, "naruto", "selection set");
    eq(S.bountyTab, "mastery", "tab set");
    var bm = H.lastSent("bounty_missions");
    assert(bm, "bounty_missions requested for uncached key");
    eq(bm.payload.path, "naruto", "request path");
    eq(bm.payload.btype, "mastery", "request btype");
  });

  test("bounty: selectBounty does NOT refetch when missions already cached", function () {
    H.resetState({
      player: { ap: 0, unlocks: [] },
      bountyTab: "unlock",
      bountyMissions: { naruto: mkMissions(1) },
    });
    window.__sent = [];
    fns.selectBounty("naruto", "unlock");
    eq(H.sentOfType("bounty_missions").length, 0, "cached -> no refetch");
    eq(S.bountySel, "naruto", "still selects");
  });

  test("bounty: selectBounty mastery uses the _mastery cache key", function () {
    var bm = {};
    bm["naruto" + C.MASTERY_SUFFIX] = mkMissions(1);  // mastery key already cached
    H.resetState({
      player: { ap: 0, unlocks: [] },
      bountyTab: "mastery",
      bountyMissions: bm,
    });
    window.__sent = [];
    fns.selectBounty("naruto", "mastery");
    eq(H.sentOfType("bounty_missions").length, 0, "mastery cache key hit -> no refetch");
  });

  // ---- emit round-trip ------------------------------------------------------
  test("bounty: incoming bounty_missions populates the cache by key", function () {
    H.resetState({ player: { ap: 0, unlocks: [] }, bountyMissions: {} });
    var missions = mkMissions(2);
    noThrow(function () { H.emit("bounty_missions", { key: "naruto", missions: missions }); }, "emit no throw");
    deepEq(S.bountyMissions["naruto"], missions, "cache populated from server frame");
    // idempotent: emitting again with same data keeps it stable
    H.emit("bounty_missions", { key: "naruto", missions: missions });
    deepEq(S.bountyMissions["naruto"], missions, "re-emit stable");
  });

  test("bounty: incoming bounty_missions without key is ignored (no throw)", function () {
    H.resetState({ player: { ap: 0, unlocks: [] }, bountyMissions: {} });
    noThrow(function () { H.emit("bounty_missions", { missions: mkMissions(1) }); }, "keyless frame no throw");
    deepEq(S.bountyMissions, {}, "no key -> cache unchanged");
  });

  // ---- bountyCard renderer resilience --------------------------------------
  test("bounty: bountyCard renders (loading) when missions not cached, no throw", function () {
    H.resetState({ player: { ap: 0, unlocks: [], active_bounties: {} }, bountySel: "naruto", bountyTab: "unlock", bountyMissions: {} });
    var node = noThrow(function () { return fns.bountyCard("naruto"); }, "card no throw without missions");
    assert(node && node.querySelector(".bty-loading"), "shows loading state");
  });

  test("bounty: bountyCard renders a 25-cell grid and an Accept button when inactive", function () {
    H.resetState({
      player: { ap: 0, unlocks: [], active_bounties: {} },
      bountySel: "naruto", bountyTab: "unlock",
      bountyMissions: { naruto: mkMissions(1) },
    });
    var node = noThrow(function () { return fns.bountyCard("naruto"); }, "card render no throw");
    eq(node.querySelectorAll(".bty-cell").length, 25, "25 mission cells");
    assert(node.querySelector(".bty-btn.accept"), "Accept button present when inactive");
    assert(!node.querySelector(".bty-btn.cancel"), "no Cancel when inactive");
  });

  test("bounty: bountyCard shows Complete button only when a pattern is satisfied", function () {
    var prog = zeros();
    [0, 1, 2, 3, 4].forEach(function (i) { prog[i] = 1; });  // top row done
    H.resetState({
      player: { ap: 0, unlocks: [], active_bounties: { naruto: prog } },
      bountySel: "naruto", bountyTab: "unlock",
      bountyMissions: { naruto: mkMissions(1) },
    });
    var node = noThrow(function () { return fns.bountyCard("naruto"); }, "completed card render no throw");
    assert(node.querySelector(".bty-btn.complete"), "Complete button shown when a row is done");
    assert(node.querySelector(".bty-btn.cancel"), "Cancel shown for active bounty");
  });

  // ---- bountiesMenu renderer resilience ------------------------------------
  test("bounty: bountiesMenu renders with empty player (no throw)", function () {
    H.resetState({ player: null, bountySel: null, bountyTab: "unlock" });
    var node = noThrow(function () { return fns.bountiesMenu(); }, "menu with null player no throw");
    assert(node && node.classList.contains("bounties-menu"), "renders bounties menu root");
    assert(node.querySelector(".bty-empty"), "empty hint when nothing selected");
  });

  test("bounty: bountiesMenu mastery tab lists owned chars, unlock tab lists unowned", function () {
    H.resetState({ player: { ap: 0, unlocks: [], active_bounties: {} }, bountySel: null, bountyTab: "mastery" });
    var masteryNode = noThrow(function () { return fns.bountiesMenu(); }, "mastery menu no throw");
    var masteryItems = masteryNode.querySelectorAll(".bty-list-item").length;
    H.resetState({ player: { ap: 0, unlocks: [], active_bounties: {} }, bountySel: null, bountyTab: "unlock" });
    var unlockNode = noThrow(function () { return fns.bountiesMenu(); }, "unlock menu no throw");
    var unlockItems = unlockNode.querySelectorAll(".bty-list-item").length;
    // owned (starters) + unowned should both be non-empty and partition the roster
    assert(masteryItems > 0, "mastery lists owned characters");
    assert(unlockItems > 0, "unlock lists unowned characters");
  });
})();

// ============================================================================
// AREA: bounty card display + category browser (categoriesFor / bountyCard / categoryModal / bountiesMenu)
// ============================================================================
(function () {
  "use strict";
  var H = window.AATest, fns = H.fns, C = H.consts, S = H.S, render = H.render;
  var test = H.test, assert = H.assert, eq = H.eq, deepEq = H.deepEq, near = H.near, noThrow = H.noThrow, throws = H.throws;

  // --- helpers ---------------------------------------------------------------
  // Run fn with S.bountyData temporarily set to `val`, always restoring after.
  // (The harness's resetState does NOT restore DATA fields like bountyData, so
  //  resilience tests that null it out must restore it themselves.)
  function withBountyData(val, fn) {
    var saved = S.bountyData;
    S.bountyData = val;
    try { fn(); } finally { S.bountyData = saved; }
  }
  // Known-good category membership read straight from the loaded bounty_data.json.
  function realCategories() { return (S.bountyData && S.bountyData.categories) || {}; }

  // ---------------------------------------------------------------------------
  // categoriesFor — correctness
  // ---------------------------------------------------------------------------
  test("bounty: categoriesFor returns sorted real categories for a known char", function () {
    H.resetState();
    var cats = realCategories();
    // Derive the expected set independently from the data file.
    var expected = Object.keys(cats).filter(function (c) {
      return (cats[c] || []).indexOf("naruto") >= 0;
    }).sort();
    assert(expected.length > 0, "naruto should belong to at least one category in the data");
    deepEq(fns.categoriesFor("naruto"), expected, "categoriesFor(naruto)");
    // naruto is a ninja in the dataset — sanity anchor.
    assert(fns.categoriesFor("naruto").indexOf("ninja") >= 0, "naruto is a ninja");
  });

  test("bounty: categoriesFor cross-checks every membership for a multi-category char", function () {
    H.resetState();
    var cats = realCategories();
    var got = fns.categoriesFor("sasuke");
    // Every returned category must actually list sasuke, and none omitted.
    got.forEach(function (c) {
      assert((cats[c] || []).indexOf("sasuke") >= 0, c + " should contain sasuke");
    });
    Object.keys(cats).forEach(function (c) {
      if ((cats[c] || []).indexOf("sasuke") >= 0) {
        assert(got.indexOf(c) >= 0, "categoriesFor must include " + c);
      }
    });
  });

  test("bounty: categoriesFor returns [] for unknown/missing path", function () {
    H.resetState();
    deepEq(fns.categoriesFor("not_a_real_character_xyz"), [], "unknown char -> []");
    deepEq(fns.categoriesFor(""), [], "empty string -> []");
    deepEq(fns.categoriesFor(undefined), [], "undefined -> []");
    deepEq(fns.categoriesFor(null), [], "null -> []");
  });

  test("bounty: categoriesFor returns [] when bountyData is null (resilience)", function () {
    H.resetState();
    withBountyData(null, function () {
      deepEq(fns.categoriesFor("naruto"), [], "no data -> []");
    });
    // restored — should be non-empty again
    assert(fns.categoriesFor("naruto").length > 0, "bountyData restored");
  });

  test("bounty: categoriesFor is idempotent (stable across repeated calls)", function () {
    H.resetState();
    var a = fns.categoriesFor("luffy");
    var b = fns.categoriesFor("luffy");
    deepEq(a, b, "two calls equal");
    // returns a fresh array each time (mutating one must not affect the data)
    a.push("ZZZ");
    deepEq(fns.categoriesFor("luffy"), b, "mutation of result does not corrupt data");
  });

  // ---------------------------------------------------------------------------
  // bountyCard — mastery note presence / absence
  // ---------------------------------------------------------------------------
  test("bounty: bountyCard mastery renders .bty-mastery-note mentioning the character", function () {
    H.resetState({ bountyTab: "mastery", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("naruto", "mastery");
    S.bountyMissions[key] = [["with", ["ninja"], 3]];
    var node = fns.bountyCard("naruto");
    var note = node.querySelector(".bty-mastery-note");
    assert(note, "mastery card has .bty-mastery-note");
    var cname = fns.nameFor("naruto");
    assert(note.textContent.indexOf(cname) >= 0, "note mentions the character name '" + cname + "'");
  });

  test("bounty: bountyCard unlock has NO .bty-mastery-note", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("zoro", "unlock");
    S.bountyMissions[key] = [["with", ["pirate"], 3]];
    var node = fns.bountyCard("zoro");
    eq(node.querySelector(".bty-mastery-note"), null, "unlock card has no mastery note");
  });

  test("bounty: bountyCard without missions shows loading note", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var node = fns.bountyCard("zoro");
    assert(node.querySelector(".bty-loading"), "no missions -> .bty-loading");
    eq(node.querySelector(".bty-grid"), null, "no grid until missions arrive");
  });

  // ---------------------------------------------------------------------------
  // bountyCard mission cells — versus vs with/against
  // ---------------------------------------------------------------------------
  test("bounty: versus cell renders TWO target symbols (.bty-split, two .bty-tg-img) + WITH/AGAINST", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("zoro", "unlock");
    // two real archetypes so bountyTargetImg returns a category icon URL for each
    S.bountyMissions[key] = [["versus", ["ninja", "pirate"], 3]];
    var node = fns.bountyCard("zoro");
    var cell = node.querySelector(".bty-cell.bty-versus");
    assert(cell, "versus cell present");
    var split = cell.querySelector(".bty-split");
    assert(split, "versus cell has .bty-split");
    eq(split.querySelectorAll(".bty-tg-img").length, 2, "two target images in a versus split");
    eq(split.querySelectorAll(".bty-half").length, 2, "two halves");
    // type label: WITH + AGAINST + a separator
    var typeEl = cell.querySelector(".bty-type");
    assert(typeEl, "has .bty-type");
    assert(typeEl.textContent.indexOf("WITH") >= 0, "label has WITH");
    assert(typeEl.textContent.indexOf("AGAINST") >= 0, "label has AGAINST");
    eq(typeEl.querySelectorAll(".k-with").length, 1, "one WITH word");
    eq(typeEl.querySelectorAll(".k-against").length, 1, "one AGAINST word");
    eq(typeEl.querySelectorAll(".k-sep").length, 1, "one separator between the two words");
  });

  test("bounty: 'with' cell renders one target symbol + only WITH", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("zoro", "unlock");
    S.bountyMissions[key] = [["with", ["pirate"], 3]];
    var node = fns.bountyCard("zoro");
    var cell = node.querySelector(".bty-cell.bty-with");
    assert(cell, "with cell present");
    eq(cell.querySelector(".bty-split"), null, "no split for a single requirement");
    assert(cell.querySelector(".bty-cell-img"), "single requirement uses .bty-cell-img");
    eq(cell.querySelectorAll(".bty-tg-img").length, 1, "exactly one target image");
    var typeEl = cell.querySelector(".bty-type");
    assert(typeEl.textContent.indexOf("WITH") >= 0, "WITH label");
    assert(typeEl.textContent.indexOf("AGAINST") < 0, "no AGAINST label");
    eq(typeEl.querySelectorAll(".k-sep").length, 0, "no separator for single requirement");
  });

  test("bounty: 'against' cell renders one target symbol + only AGAINST", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("zoro", "unlock");
    S.bountyMissions[key] = [["against", ["ninja"], 2]];
    var node = fns.bountyCard("zoro");
    var cell = node.querySelector(".bty-cell.bty-against");
    assert(cell, "against cell present");
    eq(cell.querySelector(".bty-split"), null, "no split");
    eq(cell.querySelectorAll(".bty-tg-img").length, 1, "one target image");
    var typeEl = cell.querySelector(".bty-type");
    assert(typeEl.textContent.indexOf("AGAINST") >= 0, "AGAINST label");
    assert(typeEl.textContent.indexOf("WITH") < 0, "no WITH label");
    assert(cell.querySelector(".bty-cell-img"), "single requirement uses .bty-cell-img");
  });

  test("bounty: mission cell shows cnt/goal progress", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("zoro", "unlock");
    S.bountyMissions[key] = [["with", ["pirate"], 5]];
    // give the bounty active progress so cell reads 2/5
    var prog = new Array(25).fill(0); prog[0] = 2;
    S.player.active_bounties[key] = prog;
    var node = fns.bountyCard("zoro");
    var p = node.querySelector(".bty-cell-prog");
    assert(p, "has .bty-cell-prog");
    eq(p.textContent, "2/5", "progress text");
  });

  test("bounty: completed cell gets the .done class", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("zoro", "unlock");
    S.bountyMissions[key] = [["with", ["pirate"], 3]];
    var prog = new Array(25).fill(0); prog[0] = 3;
    S.player.active_bounties[key] = prog;
    var node = fns.bountyCard("zoro");
    var cell = node.querySelector(".bty-cell");
    assert(cell.className.indexOf("done") >= 0, "cell with cnt>=goal is .done");
  });

  // ---------------------------------------------------------------------------
  // bountyCard archetype-icon click sets S.catView
  // ---------------------------------------------------------------------------
  test("bounty: clicking a card archetype icon sets S.catView to that category", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, bountySel: "zoro", screen: "menu", menuOverlay: "bounties", player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("zoro", "unlock");
    S.bountyMissions[key] = [["with", ["pirate"], 3]];
    var node = fns.bountyCard("zoro");
    var img = node.querySelector(".bty-tg-img.cat");
    assert(img, "archetype target image carries .cat (clickable)");
    eq(S.catView, null, "catView starts null");
    img.click();
    eq(S.catView, "pirate", "clicking the pirate archetype icon sets catView=pirate");
  });

  // ---------------------------------------------------------------------------
  // categoryModal — categories with member counts + selected members
  // ---------------------------------------------------------------------------
  test("bounty: categoryModal lists every category with correct member count", function () {
    H.resetState({ catView: null });
    var node = fns.categoryModal();
    var cats = realCategories();
    var names = Object.keys(cats).sort();
    var rows = node.querySelectorAll(".cat-list-row");
    eq(rows.length, names.length, "one row per category");
    // verify a couple of known counts against the data file
    for (var i = 0; i < rows.length; i++) {
      var nm = rows[i].querySelector(".cat-list-name").textContent;
      var cnt = rows[i].querySelector(".cat-list-count").textContent;
      // find the category whose titleCase matches this row's name
      var match = names.filter(function (c) { return fns.titleCase(c) === nm; })[0];
      assert(match != null, "row name maps to a real category: " + nm);
      eq(cnt, String((cats[match] || []).length), "count for " + match);
    }
  });

  test("bounty: categoryModal shows the selected category's members", function () {
    H.resetState({ catView: "pirate" });
    var node = fns.categoryModal();
    var cats = realCategories();
    var members = cats["pirate"] || [];
    var grid = node.querySelector(".cat-members-grid");
    assert(grid, "has members grid");
    eq(grid.querySelectorAll(".cat-member").length, members.length, "member count matches pirate roster");
    var sub = node.querySelector(".cat-members-sub");
    assert(sub.textContent.indexOf(String(members.length)) >= 0, "subtitle states member count");
    // selected row is marked .sel and is the pirate row
    var selRow = node.querySelector(".cat-list-row.sel");
    assert(selRow, "a row is selected");
    eq(selRow.querySelector(".cat-list-name").textContent, fns.titleCase("pirate"), "pirate row selected");
  });

  test("bounty: categoryModal falls back to first category when catView invalid", function () {
    H.resetState({ catView: "not_a_category" });
    var node = fns.categoryModal();
    var names = Object.keys(realCategories()).sort();
    var selRow = node.querySelector(".cat-list-row.sel");
    assert(selRow, "an invalid catView still selects a default row");
    eq(selRow.querySelector(".cat-list-name").textContent, fns.titleCase(names[0]), "defaults to first category");
  });

  test("bounty: clicking a category row sets S.catView (member-count selection)", function () {
    H.resetState({ catView: "pirate", screen: "menu", menuOverlay: "bounties" });
    var node = fns.categoryModal();
    var names = Object.keys(realCategories()).sort();
    // pick a row that is NOT currently selected
    var target = names.filter(function (c) { return c !== "pirate"; })[0];
    var rows = node.querySelectorAll(".cat-list-row");
    var row = null;
    rows.forEach(function (r) { if (r.querySelector(".cat-list-name").textContent === fns.titleCase(target)) row = r; });
    assert(row, "found the target row");
    row.click();
    eq(S.catView, target, "clicking a row sets catView to that category");
  });

  // ---------------------------------------------------------------------------
  // bountiesMenu — structure + category button
  // ---------------------------------------------------------------------------
  test("bounty: bountiesMenu renders tabs, active bar, category button, and a roster list", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var node = fns.bountiesMenu();
    eq(node.querySelectorAll(".bty-tab").length, 2, "two tabs (unlock/mastery)");
    assert(node.querySelector(".bty-active"), "active bar present");
    var catBtn = node.querySelector(".bty-cat-btn");
    assert(catBtn, "category button present");
    assert(!catBtn.disabled, "category button enabled when categories loaded");
    assert(node.querySelectorAll(".bty-list-item").length > 0, "roster list populated");
  });

  test("bounty: bountiesMenu unlock list excludes owned/starter chars; mastery includes them", function () {
    // naruto is a starter -> owned. In unlock tab it should be filtered out.
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    assert(fns.bountyOwned("naruto"), "naruto is owned (starter)");
    var unlockNode = fns.bountiesMenu();
    var unlockNames = Array.prototype.map.call(unlockNode.querySelectorAll(".bty-li-name"), function (e) { return e.textContent; });
    var naruName = fns.nameFor("naruto");
    assert(unlockNames.indexOf(naruName) < 0, "owned starter not in unlock list");

    H.resetState({ bountyTab: "mastery", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var masteryNode = fns.bountiesMenu();
    var masteryNames = Array.prototype.map.call(masteryNode.querySelectorAll(".bty-li-name"), function (e) { return e.textContent; });
    assert(masteryNames.indexOf(naruName) >= 0, "owned starter appears in mastery list");
  });

  test("bounty: bountiesMenu active bar reflects active_bounties count + chips", function () {
    var key = fns.bountyKeyFor("zoro", "unlock");
    var ab = {}; ab[key] = new Array(25).fill(0);
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: ab } });
    var node = fns.bountiesMenu();
    var label = node.querySelector(".bty-active-label");
    assert(label.textContent.indexOf("1/" + C.BOUNTY_MAX_ACTIVE) >= 0, "label shows 1/" + C.BOUNTY_MAX_ACTIVE);
    eq(node.querySelectorAll(".bty-active-chip").length, 1, "one active chip");
  });

  // ---------------------------------------------------------------------------
  // RESILIENCE
  // ---------------------------------------------------------------------------
  test("bounty: bountiesMenu does NOT throw when bountyData is null", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    withBountyData(null, function () {
      noThrow(function () { fns.bountiesMenu(); }, "bountiesMenu with null bountyData");
      var node = fns.bountiesMenu();
      var catBtn = node.querySelector(".bty-cat-btn");
      assert(catBtn.disabled, "category button disabled when no categories");
    });
  });

  test("bounty: bountiesMenu does NOT throw with empty bountyMissions + no player", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: null });
    noThrow(function () { fns.bountiesMenu(); }, "bountiesMenu null player");
  });

  test("bounty: bountyCard does NOT throw when bountyData is null", function () {
    H.resetState({ bountyTab: "mastery", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("naruto", "mastery");
    S.bountyMissions[key] = [["versus", ["ninja", "pirate"], 3], ["with", ["luffy"], 2]];
    withBountyData(null, function () {
      noThrow(function () { fns.bountyCard("naruto"); }, "bountyCard null bountyData");
    });
  });

  test("bounty: bountyCard does NOT throw with malformed/partial mission tuples", function () {
    H.resetState({ bountyTab: "unlock", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("zoro", "unlock");
    // missing targets, empty target list, weird type, missing goal
    S.bountyMissions[key] = [
      ["with", [], 3],
      ["versus", ["ninja"], 2],     // versus but only one target -> second part filtered out
      ["mystery", ["pirate"], 1],   // unknown type -> falls through to default 'with'
      ["against"],                  // no targets / no goal
    ];
    noThrow(function () { fns.bountyCard("zoro"); }, "bountyCard malformed missions");
  });

  test("bounty: categoryModal does NOT throw when bountyData is null", function () {
    H.resetState({ catView: null });
    withBountyData(null, function () {
      noThrow(function () { fns.categoryModal(); }, "categoryModal null bountyData");
      var node = fns.categoryModal();
      eq(node.querySelectorAll(".cat-list-row").length, 0, "no category rows without data");
      assert(node.querySelector(".note"), "shows a 'no categories' note");
    });
  });

  test("bounty: full render does NOT throw with catView open and null bountyData", function () {
    H.resetState({ screen: "menu", menuOverlay: "bounties", catView: "pirate", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    withBountyData(null, function () {
      noThrow(function () { render(); }, "render with catView open + null data");
    });
  });

  // ---------------------------------------------------------------------------
  // IDEMPOTENCY — re-render stability
  // ---------------------------------------------------------------------------
  test("bounty: bountyCard re-render is stable (same structure twice)", function () {
    H.resetState({ bountyTab: "mastery", bountyMissions: {}, player: { ap: 0, unlocks: [], active_bounties: {} } });
    var key = fns.bountyKeyFor("naruto", "mastery");
    S.bountyMissions[key] = [["versus", ["ninja", "pirate"], 3], ["with", ["luffy"], 2], ["against", ["ninja"], 1]];
    var a = fns.bountyCard("naruto");
    var b = fns.bountyCard("naruto");
    eq(a.querySelectorAll(".bty-cell").length, b.querySelectorAll(".bty-cell").length, "same cell count");
    eq(a.querySelectorAll(".bty-tg-img").length, b.querySelectorAll(".bty-tg-img").length, "same image count");
    eq(!!a.querySelector(".bty-mastery-note"), !!b.querySelector(".bty-mastery-note"), "mastery note stable");
  });

  test("bounty: categoryModal selection is idempotent (re-render same catView)", function () {
    H.resetState({ catView: "ninja" });
    var a = fns.categoryModal();
    var b = fns.categoryModal();
    eq(a.querySelectorAll(".cat-member").length, b.querySelectorAll(".cat-member").length, "stable member count");
    eq(a.querySelector(".cat-list-row.sel").querySelector(".cat-list-name").textContent,
       b.querySelector(".cat-list-row.sel").querySelector(".cat-list-name").textContent, "stable selection");
    eq(S.catView, "ninja", "rendering categoryModal does not mutate catView");
  });
})();

// ============================================================================
// AREA: shop purchases + nexus donations (app.js: shopOwned/buyShopItem/shopCard/shopConfirm/shopMenu, doDonate/nexusMenu/nexusRow/prettyUniverse/fmtAp)
// ============================================================================
(function () {
  "use strict";
  var H = window.AATest, fns = H.fns, C = H.consts, S = H.S, render = H.render;
  var test = H.test, assert = H.assert, eq = H.eq, deepEq = H.deepEq, near = H.near, noThrow = H.noThrow, throws = H.throws;

  // A real catalog item: [unlock, category, img, name, price]
  var ITEM = ["gamepanel_color_cyan", "gamepanel", "res://x.png", "Action Panel - Cyan", 800];
  var UNLOCK = ITEM[0], PRICE = ITEM[4];

  // ---------------------------------------------------------------------------
  // fmtAp — formats numbers sanely (locale-agnostic: compare to native toLocaleString)
  // ---------------------------------------------------------------------------
  test("shop: fmtAp formats a normal number like toLocaleString", function () {
    eq(fns.fmtAp(1234567), (1234567).toLocaleString(), "matches native locale format");
  });
  test("shop: fmtAp coerces null/undefined/0 to \"0\"", function () {
    eq(fns.fmtAp(0), (0).toLocaleString(), "zero");
    eq(fns.fmtAp(null), (0).toLocaleString(), "null -> 0");
    eq(fns.fmtAp(undefined), (0).toLocaleString(), "undefined -> 0");
  });
  test("shop: fmtAp always returns a string", function () {
    assert(typeof fns.fmtAp(42) === "string", "string for number");
    assert(typeof fns.fmtAp(undefined) === "string", "string for undefined");
  });

  // ---------------------------------------------------------------------------
  // prettyUniverse — map raw enums to clean names; pass clean ones through
  // ---------------------------------------------------------------------------
  test("nexus: prettyUniverse passes a clean name through unchanged", function () {
    eq(fns.prettyUniverse("Demon Slayer"), "Demon Slayer", "clean passthrough");
  });
  test("nexus: prettyUniverse titlecases a RAW_ENUM", function () {
    eq(fns.prettyUniverse("FULL_METAL_ALCHEMIST"), "Full Metal Alchemist", "enum -> words");
  });
  test("nexus: prettyUniverse picks the non-enum half of an enum to_string", function () {
    eq(fns.prettyUniverse("Frieren (CharacterConcept.Universe.FRIEREN)"), "Frieren", "name before enum parens");
  });
  test("nexus: prettyUniverse picks the clean name when enum precedes it", function () {
    eq(fns.prettyUniverse("RAW_ENUM (Clean Name)"), "Clean Name", "clean inside parens");
  });
  test("nexus: prettyUniverse returns falsy input as-is (null/empty)", function () {
    eq(fns.prettyUniverse(null), null, "null");
    eq(fns.prettyUniverse(""), "", "empty string");
  });
  test("nexus: prettyUniverse is idempotent on a clean name", function () {
    var once = fns.prettyUniverse("Naruto");
    eq(fns.prettyUniverse(once), once, "applying twice is stable");
  });
  test("nexus: prettyUniverse on real roster universes is non-empty + stable", function () {
    H.resetState({});
    var seen = {};
    (S.roster || []).slice(0, 40).forEach(function (r) {
      var p = fns.prettyUniverse(r.universe);
      assert(typeof p === "string" && p.length > 0, "non-empty pretty for " + r.universe);
      eq(fns.prettyUniverse(p), p, "stable for " + r.universe);
      seen[p] = true;
    });
    assert(Object.keys(seen).length > 0, "saw at least one universe");
  });

  test("nexus: universe view groups EVERY bucket by its wire universe (not just roster matches)", function () {
    H.resetState({ player: { ap: 9999 } });
    // [path_name, ap, universe] — incl. non-playable concept chars the roster.json doesn't list
    H.emit("nexus_state", { max: 5000, poll_open: true, sets: [
      ["kiba", 5000, "NARUTO"], ["shino", 3200, "NARUTO"], ["akainu", 4100, "ONE_PIECE"],
    ] });
    eq(S.nexusBucketUni.kiba, "Naruto", "NARUTO -> Naruto");
    eq(S.nexusBucketUni.akainu, "One Piece", "ONE_PIECE -> One Piece");
    // a universe button exists for a bucket-only universe
    var btns = [].map.call(fns.nexusMenu().querySelectorAll(".nx-uni"), function (b) { return b.textContent; });
    assert(btns.indexOf("One Piece") !== -1, "One Piece button present (bucket-only universe)");
    // the Naruto view lists BOTH non-roster concept buckets, sorted by AP
    S.nexusUniverse = "Naruto";
    var rows = fns.nexusMenu().querySelectorAll(".nx-row");
    eq(rows.length, 2, "both Naruto buckets shown");
    eq((rows[0].querySelector(".nx-apval") || {}).textContent, "5,000 AP", "highest-AP bucket first");
  });

  test("nexus: universe buttons come from the enum, not roster display names (no dupes)", function () {
    H.resetState({ player: { ap: 9999 } });
    S.roster = [{ path_name: "gon", name: "Gon", universe: "Hunter x Hunter" }];   // roster.json uses a lowercase x
    // server bucket wire: HUNTER_X_HUNTER -> prettyUniverse -> "Hunter X Hunter" (capital X) — a spacing/case variant
    H.emit("nexus_state", { max: 5000, poll_open: true, sets: [
      ["killua", 4000, "HUNTER_X_HUNTER"], ["hisoka", 1500, "HUNTER_X_HUNTER"],
    ] });
    eq(S.nexusBucketUni.killua, "Hunter X Hunter", "enum titlecased with capital X (differs from roster label)");
    // the two labels differ by exactly the x/X case, so the pre-fix Set kept both -> duplicate buttons
    var btns = [].map.call(fns.nexusMenu().querySelectorAll(".nx-uni"), function (b) { return b.textContent; });
    var hunter = btns.filter(function (t) { return /hunter/i.test(t); });
    eq(hunter.length, 1, "exactly one Hunter X Hunter button (enum + bucket variant deduped by uniKey)");
    eq(hunter[0], "Hunter X Hunter", "label is the enum-derived name, not roster's 'Hunter x Hunter'");
    assert(btns.indexOf("Hunter x Hunter") === -1, "roster's lowercase-x display name is not used for a button");
    // selecting that one button groups BOTH buckets under it
    S.nexusUniverse = "Hunter X Hunter";
    var rows = fns.nexusMenu().querySelectorAll(".nx-row");
    eq(rows.length, 2, "both buckets grouped under the single enum button");
  });

  test("nexus: dead roster universes are gone and Invincible is disabled", function () {
    H.resetState({ player: { ap: 100 } });
    S.roster = [{ path_name: "saber", name: "Saber", universe: "Fate/stay night" }];   // roster display name that drifts from the enum
    H.emit("nexus_state", { max: 100, poll_open: true, sets: [["inv", 50, "INVINCIBLE"], ["naru", 40, "NARUTO"]] });
    var btns = [].map.call(fns.nexusMenu().querySelectorAll(".nx-uni"), function (b) { return b.textContent; });
    assert(btns.indexOf("Fate/stay night") === -1, "no dead Fate/stay night button (roster name)");
    assert(btns.indexOf("Fate") !== -1, "enum Fate button present");
    assert(btns.indexOf("Invincible") === -1, "Invincible disabled even though it has a bucket");
    assert(btns.indexOf("Naruto") !== -1, "enum Naruto present");
  });

  test("nexus: leaderboard rows are donatable (clicking opens the donate popup)", function () {
    H.resetState({ player: { ap: 500 }, nexusBuckets: { naruto: 300, sasuke: 200 }, nexusMax: 300, nexusPollOpen: true, nexusUniverse: null });
    var rows = fns.nexusMenu().querySelectorAll('.nx-list[data-scrollkey="nx-top"] .nx-row');
    var donatable = fns.nexusMenu().querySelectorAll('.nx-list[data-scrollkey="nx-top"] .nx-row.donatable');
    assert(rows.length >= 1, "leaderboard has rows");
    eq(donatable.length, rows.length, "every leaderboard row is donatable");
    fns.nexusMenu().querySelector('.nx-list[data-scrollkey="nx-top"] .nx-row.donatable').click();
    assert(S.nexusDonate != null, "clicking a leaderboard row opens the donate popup");
  });

  test("cosmetics: 'Unlocked only' filter hides locked cosmetics", function () {
    H.resetState({ roster: [{ path_name: "a", name: "A" }, { path_name: "b", name: "B" }], player: { mastery_xp: { a: 1000000 } }, cosmeticTab: "playercard", cosOnlyUnlocked: false });
    eq(fns.cosmeticsMenu().querySelectorAll(".cos-grid .cos-cell").length, 2, "all characters shown when the filter is off");
    S.cosOnlyUnlocked = true;
    eq(fns.cosmeticsMenu().querySelectorAll(".cos-grid .cos-cell").length, 1, "only the unlocked character shown when the filter is on");
  });

  // ---------------------------------------------------------------------------
  // shopOwned — reflects player.unlocks and the "all_unlock" master flag
  // ---------------------------------------------------------------------------
  test("shop: shopOwned true when unlock is in player.unlocks", function () {
    H.resetState({ player: { ap: 0, unlocks: [UNLOCK] } });
    assert(fns.shopOwned(UNLOCK), "owned via explicit unlock");
  });
  test("shop: shopOwned false when not owned", function () {
    H.resetState({ player: { ap: 0, unlocks: [] } });
    assert(!fns.shopOwned(UNLOCK), "not owned");
  });
  test("shop: shopOwned true for everything when all_unlock present", function () {
    H.resetState({ player: { ap: 0, unlocks: ["all_unlock"] } });
    assert(fns.shopOwned(UNLOCK), "all_unlock covers this item");
    assert(fns.shopOwned("anything_else"), "all_unlock covers arbitrary item");
  });
  test("shop: shopOwned safe with null player / missing unlocks", function () {
    H.resetState({ player: null });
    assert(!fns.shopOwned(UNLOCK), "no player -> not owned");
    H.resetState({ player: {} });
    assert(!fns.shopOwned(UNLOCK), "no unlocks array -> not owned");
  });

  // ---------------------------------------------------------------------------
  // buyShopItem — debit AP + add unlock + send save frame; guarded
  // ---------------------------------------------------------------------------
  test("shop: buyShopItem debits AP, adds unlock, sends save_cosmetics", function () {
    H.resetState({ player: { ap: 5000, unlocks: [] }, shopBuy: { unlock: UNLOCK, name: ITEM[3], price: PRICE } });
    fns.buyShopItem(UNLOCK, PRICE);
    eq(S.player.ap, 5000 - PRICE, "AP debited by price");
    assert(S.player.unlocks.indexOf(UNLOCK) >= 0, "unlock added");
    eq(H.sentOfType("save_cosmetics").length, 1, "one save frame sent");
    eq(S.shopBuy, null, "confirm popup cleared");
  });
  test("shop: buyShopItem save frame carries the updated unlocks", function () {
    H.resetState({ player: { ap: 5000, unlocks: [] }, shopBuy: { unlock: UNLOCK, name: ITEM[3], price: PRICE } });
    fns.buyShopItem(UNLOCK, PRICE);
    var frame = H.lastSent("save_cosmetics");
    assert(frame && frame.payload && frame.payload.update, "frame has update blob");
    assert(frame.payload.update.unlocks.indexOf(UNLOCK) >= 0, "unlock present in saved update");
    eq(frame.payload.update.ap, 5000 - PRICE, "saved AP reflects debit");
  });
  test("shop: buyShopItem guarded when AP < price — no debit, no unlock, no save", function () {
    H.resetState({ player: { ap: 100, unlocks: [] }, shopBuy: { unlock: UNLOCK, name: ITEM[3], price: PRICE } });
    fns.buyShopItem(UNLOCK, PRICE);
    eq(S.player.ap, 100, "AP unchanged");
    eq(S.player.unlocks.length, 0, "no unlock added");
    eq(H.sentOfType("save_cosmetics").length, 0, "no save frame");
    eq(S.shopBuy, null, "popup still cleared");
    eq(S.msgKind, "bad", "shows a bad message");
  });
  test("shop: buyShopItem idempotent — buying an owned item does not double-debit", function () {
    H.resetState({ player: { ap: 5000, unlocks: [UNLOCK] }, shopBuy: { unlock: UNLOCK, name: ITEM[3], price: PRICE } });
    fns.buyShopItem(UNLOCK, PRICE);
    eq(S.player.ap, 5000, "owned -> AP untouched");
    eq(S.player.unlocks.filter(function (u) { return u === UNLOCK; }).length, 1, "no duplicate unlock");
    eq(H.sentOfType("save_cosmetics").length, 0, "no save on owned purchase");
  });
  test("shop: buyShopItem twice in a row debits only once (idempotent after own)", function () {
    H.resetState({ player: { ap: 5000, unlocks: [] }, shopBuy: { unlock: UNLOCK, name: ITEM[3], price: PRICE } });
    fns.buyShopItem(UNLOCK, PRICE);
    // second attempt: now owned, popup repopulated to simulate a double-click
    S.shopBuy = { unlock: UNLOCK, name: ITEM[3], price: PRICE };
    fns.buyShopItem(UNLOCK, PRICE);
    eq(S.player.ap, 5000 - PRICE, "debited exactly once");
    eq(S.player.unlocks.filter(function (u) { return u === UNLOCK; }).length, 1, "unlock present exactly once");
    eq(H.sentOfType("save_cosmetics").length, 1, "exactly one save frame total");
  });
  test("shop: buyShopItem safe with null player — no throw, no send", function () {
    H.resetState({ player: null });
    noThrow(function () { fns.buyShopItem(UNLOCK, PRICE); }, "buyShopItem null player");
    eq(H.sentOfType("save_cosmetics").length, 0, "no save with null player");
  });

  // ---------------------------------------------------------------------------
  // doDonate — debit AP + bump bucket + send donate frame; guarded
  // ---------------------------------------------------------------------------
  test("nexus: doDonate debits AP, bumps bucket, sends donate frame", function () {
    var path = "naruto";
    H.resetState({ player: { ap: 5000 }, nexusBuckets: { naruto: 100 }, nexusMax: 100, nexusPollOpen: true, nexusDonate: { path_name: path, amount: "250" } });
    fns.doDonate(path);
    eq(S.player.ap, 5000 - 250, "AP debited");
    eq(S.nexusBuckets[path], 100 + 250, "bucket bumped");
    var frame = H.lastSent("donate");
    assert(frame, "donate frame sent");
    eq(frame.payload.path_name, path, "frame path");
    eq(frame.payload.amount, 250, "frame amount (floored number)");
    eq(S.nexusDonate, null, "popup cleared");
    eq(S.msgKind, "ok", "ok message");
  });
  test("nexus: doDonate floors fractional amount and raises nexusMax if leader", function () {
    var path = "naruto";
    H.resetState({ player: { ap: 5000 }, nexusBuckets: { naruto: 0 }, nexusMax: 1, nexusPollOpen: true, nexusDonate: { path_name: path, amount: "300.9" } });
    fns.doDonate(path);
    eq(S.nexusBuckets[path], 300, "amount floored to 300");
    eq(H.lastSent("donate").payload.amount, 300, "frame amount floored");
    eq(S.nexusMax, 300, "nexusMax raised to new leader");
  });
  test("nexus: doDonate guarded at amount > AP — no debit, no bucket change, no frame", function () {
    var path = "naruto";
    H.resetState({ player: { ap: 100 }, nexusBuckets: { naruto: 50 }, nexusMax: 50, nexusPollOpen: true, nexusDonate: { path_name: path, amount: "500" } });
    fns.doDonate(path);
    eq(S.player.ap, 100, "AP unchanged");
    eq(S.nexusBuckets[path], 50, "bucket unchanged");
    eq(H.sentOfType("donate").length, 0, "no donate frame");
    eq(S.msgKind, "bad", "bad message");
  });
  test("nexus: doDonate guarded on invalid/zero amount and closed poll", function () {
    var path = "naruto";
    H.resetState({ player: { ap: 5000 }, nexusBuckets: { naruto: 50 }, nexusPollOpen: true, nexusDonate: { path_name: path, amount: "0" } });
    fns.doDonate(path);
    eq(S.player.ap, 5000, "zero amount: no debit");
    eq(H.sentOfType("donate").length, 0, "zero amount: no frame");
    // closed poll with a valid amount
    H.resetState({ player: { ap: 5000 }, nexusBuckets: { naruto: 50 }, nexusPollOpen: false, nexusDonate: { path_name: path, amount: "100" } });
    fns.doDonate(path);
    eq(S.player.ap, 5000, "closed poll: no debit");
    eq(H.sentOfType("donate").length, 0, "closed poll: no frame");
  });
  test("nexus: doDonate then update_buckets echo reconciles bucket (round-trip)", function () {
    var path = "naruto";
    H.resetState({ player: { ap: 5000 }, nexusBuckets: { naruto: 100 }, nexusMax: 100, nexusPollOpen: true, nexusDonate: { path_name: path, amount: "200" } });
    fns.doDonate(path);
    eq(S.nexusBuckets[path], 300, "optimistic local bump");
    // server echoes authoritative bucket total + AP
    H.emit("update_buckets", { path_name: path, amount: 300, current_max: 300 });
    eq(S.nexusBuckets[path], 300, "bucket reconciled to server value");
    eq(S.nexusMax, 300, "nexusMax matches leader");
  });

  // ---------------------------------------------------------------------------
  // Renderer resilience — shopMenu / nexusMenu must not throw on empty/partial state
  // ---------------------------------------------------------------------------
  test("shop: shopMenu renders without throwing on empty player", function () {
    H.resetState({ player: {} });
    noThrow(function () { fns.shopMenu(); }, "shopMenu empty player");
    H.resetState({ player: null });
    noThrow(function () { fns.shopMenu(); }, "shopMenu null player");
  });
  test("shop: shopMenu owned-count badge renders and reflects owned items", function () {
    H.resetState({ player: { ap: 9999, unlocks: [] }, shopTab: "gamepanel" });
    var node = fns.shopMenu();
    var count = node.querySelector(".shop-count");
    assert(count, "owned-count element present");
    assert(/0 \//.test(count.textContent), "0 owned initially, got: " + count.textContent);
    // mark one owned, re-render, count rises (catalog gamepanel includes gamepanel_color_cyan)
    H.resetState({ player: { ap: 9999, unlocks: ["gamepanel_color_cyan"] }, shopTab: "gamepanel" });
    var node2 = fns.shopMenu();
    assert(/^1 \//.test(node2.querySelector(".shop-count").textContent), "1 owned now, got: " + node2.querySelector(".shop-count").textContent);
  });
  test("nexus: nexusMenu renders without throwing on empty player + empty buckets", function () {
    H.resetState({ player: {} });
    noThrow(function () { fns.nexusMenu(); }, "nexusMenu empty player");
    H.resetState({ player: null, nexusBuckets: {} });
    noThrow(function () { fns.nexusMenu(); }, "nexusMenu null player empty buckets");
  });
  test("nexus: nexusMenu universe view + donate popup render without throwing", function () {
    H.resetState({ player: { ap: 1000 }, nexusBuckets: { naruto: 500 }, nexusMax: 500, nexusUniverse: "Naruto", nexusDonate: { path_name: "naruto" } });
    noThrow(function () { fns.nexusMenu(); }, "nexusMenu with universe + donate popup");
  });
  test("nexus: nexusMenu leaderboard shows your AP via fmtAp", function () {
    H.resetState({ player: { ap: 12345 }, nexusBuckets: { naruto: 10, sasuke: 20 }, nexusMax: 20 });
    var node = fns.nexusMenu();
    var apEl = node.querySelector(".nx-ap");
    assert(apEl, "ap header present");
    assert(apEl.textContent.indexOf(fns.fmtAp(12345)) >= 0, "shows formatted AP, got: " + apEl.textContent);
  });
})();

// ============================================================================
// AREA: title builder
// ============================================================================
(function () {
  "use strict";
  var H = window.AATest, fns = H.fns, C = H.consts, S = H.S, render = H.render;
  var test = H.test, assert = H.assert, eq = H.eq, deepEq = H.deepEq, near = H.near, noThrow = H.noThrow, throws = H.throws;

  // ---- unlockedTitleWords: base words ------------------------------------
  test("title: unlockedTitleWords always includes every BASE_TITLE_WORD (no mastery)", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: [] });
    var w = fns.unlockedTitleWords();
    assert(w instanceof Set, "returns a Set");
    C.BASE_TITLE_WORDS.forEach(function (b) {
      assert(w.has(b), "missing base word: " + b);
    });
  });

  test("title: base words present even when player is null", function () {
    H.resetState({ player: null, titleEdit: [] });
    var w;
    noThrow(function () { w = fns.unlockedTitleWords(); }, "unlockedTitleWords with null player");
    C.BASE_TITLE_WORDS.forEach(function (b) {
      assert(w.has(b), "missing base word (null player): " + b);
    });
  });

  test("title: base words present even when titles+roster data absent (player null path)", function () {
    // titles/roster are real loaded data; the function guards on (t && S.roster),
    // so with no mastery contribution we still must get every base word.
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: [] });
    var w = fns.unlockedTitleWords();
    eq(w.has("Beta") && w.has("Anime") && w.has("Arena"), true, "core base words present");
    // distinct case-sensitive entries
    assert(w.has("The"), "has 'The'");
    assert(w.has("the"), "has 'the'");
  });

  // ---- unlockedTitleWords: equipped-title words --------------------------
  test("title: unlockedTitleWords includes words from the currently-equipped title", function () {
    H.resetState({ player: { mastery_xp: {}, title: "Hokage Supreme" }, titleEdit: [] });
    var w = fns.unlockedTitleWords();
    assert(w.has("Hokage"), "equipped word Hokage included");
    assert(w.has("Supreme"), "equipped word Supreme included");
    // base words still there too
    assert(w.has("Beta"), "base word still present");
  });

  test("title: equipped-title split ignores empty fragments", function () {
    H.resetState({ player: { mastery_xp: {}, title: "  Lone   Wolf  " }, titleEdit: [] });
    var w;
    noThrow(function () { w = fns.unlockedTitleWords(); }, "messy whitespace title");
    assert(w.has("Lone"), "Lone present");
    assert(w.has("Wolf"), "Wolf present");
    assert(!w.has(""), "no empty-string word");
  });

  // ---- unlockedTitleWords: mastery unlocks -------------------------------
  test("title: lesser-title mastery words unlock at level 2 (>=250 xp)", function () {
    H.resetState({ player: { mastery_xp: { naruto: 250 }, title: "" }, titleEdit: [] });
    eq(fns.masteryLevel("naruto"), 2, "naruto at level 2");
    var w = fns.unlockedTitleWords();
    assert(w.has("Outcast"), "lesser word Outcast unlocked");
    assert(w.has("Orange"), "lesser word Orange unlocked");
    assert(!w.has("Kyuubi"), "greater word still locked at lvl 2");
  });

  test("title: greater-title mastery words unlock at level 4 (>=800 xp)", function () {
    H.resetState({ player: { mastery_xp: { naruto: 800 }, title: "" }, titleEdit: [] });
    eq(fns.masteryLevel("naruto"), 4, "naruto at level 4");
    var w = fns.unlockedTitleWords();
    assert(w.has("Outcast"), "lesser still there at lvl4");
    assert(w.has("Kyuubi"), "greater word Kyuubi unlocked");
  });

  test("title: no mastery words below threshold (level 1)", function () {
    H.resetState({ player: { mastery_xp: { naruto: 100 }, title: "" }, titleEdit: [] });
    eq(fns.masteryLevel("naruto"), 1, "naruto level 1");
    var w = fns.unlockedTitleWords();
    assert(!w.has("Outcast"), "lesser word locked below lvl2");
    assert(!w.has("Kyuubi"), "greater word locked below lvl4");
  });

  test("title: unlockedTitleWords is stable across repeated calls (idempotent)", function () {
    H.resetState({ player: { mastery_xp: { naruto: 800 }, title: "Hokage" }, titleEdit: [] });
    var a = Array.from(fns.unlockedTitleWords()).sort();
    var b = Array.from(fns.unlockedTitleWords()).sort();
    deepEq(b, a, "two computations equal");
  });

  // ---- addTitleWord ------------------------------------------------------
  test("title: addTitleWord appends to the edit list", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: [] });
    fns.addTitleWord("Anime");
    fns.addTitleWord("Arena");
    deepEq(S.titleEdit, ["Anime", "Arena"], "appended in order");
  });

  test("title: addTitleWord lazily initializes titleEdit when undefined", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" } });
    S.titleEdit = undefined;
    noThrow(function () { fns.addTitleWord("Beta"); }, "add with no prior titleEdit");
    deepEq(S.titleEdit, ["Beta"], "titleEdit created with one word");
  });

  test("title: addTitleWord dedupes — adding the same word twice is a no-op", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: [] });
    fns.addTitleWord("Test");
    fns.addTitleWord("Test");
    fns.addTitleWord("Test");
    deepEq(S.titleEdit, ["Test"], "no duplicates");
  });

  test("title: addTitleWord caps at MAX_TITLE_WORDS and rejects further adds", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: [] });
    var pool = ["Beta", "Tester", "The", "of", "the", "Test"]; // 6 distinct
    pool.forEach(function (x) { fns.addTitleWord(x); });
    eq(S.titleEdit.length, C.MAX_TITLE_WORDS, "capped at MAX");
    deepEq(S.titleEdit, pool.slice(0, C.MAX_TITLE_WORDS), "only first MAX kept");
  });

  test("title: addTitleWord at cap sets a bad error message", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: ["Beta", "Tester", "The", "of", "the"] });
    eq(S.titleEdit.length, C.MAX_TITLE_WORDS, "starts full");
    fns.addTitleWord("Test");
    eq(S.titleEdit.length, C.MAX_TITLE_WORDS, "still capped");
    eq(S.msgKind, "bad", "msgKind bad on overflow");
    assert(/at most/.test(S.msg || ""), "error message mentions 'at most': " + S.msg);
  });

  test("title: addTitleWord re-add of existing word at cap is still a no-op (dedupe wins)", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: ["Beta", "Tester", "The", "of", "the"] });
    noThrow(function () { fns.addTitleWord("Beta"); }, "re-add at cap");
    deepEq(S.titleEdit, ["Beta", "Tester", "The", "of", "the"], "unchanged");
  });

  // ---- removeTitleWord ---------------------------------------------------
  test("title: removeTitleWord removes by index", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: ["Anime", "Arena", "Test"] });
    fns.removeTitleWord(1);
    deepEq(S.titleEdit, ["Anime", "Test"], "middle word removed");
  });

  test("title: removeTitleWord with out-of-range index is a safe no-op", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: ["Anime", "Arena"] });
    noThrow(function () { fns.removeTitleWord(99); }, "remove out-of-range high");
    deepEq(S.titleEdit, ["Anime", "Arena"], "unchanged after high index");
  });

  test("title: removeTitleWord on undefined titleEdit does not throw", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" } });
    S.titleEdit = undefined;
    noThrow(function () { fns.removeTitleWord(0); }, "remove with no titleEdit");
  });

  test("title: add then remove the same word returns to empty (idempotent round-trip)", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: [] });
    fns.addTitleWord("Beta");
    fns.removeTitleWord(0);
    deepEq(S.titleEdit, [], "back to empty");
  });

  // ---- saveTitle ---------------------------------------------------------
  test("title: saveTitle writes joined title to S.player.title and sends a save frame", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: ["The", "Anime", "Arena"] });
    fns.saveTitle();
    eq(S.player.title, "The Anime Arena", "title joined with spaces");
    var f = H.lastSent("save_cosmetics");
    assert(f, "save_cosmetics frame sent");
    assert(f.payload && f.payload.update, "frame carries update payload");
    eq(f.payload.update.title, "The Anime Arena", "update payload carries title");
    eq(S.msgKind, "ok", "ok msgKind on save");
  });

  test("title: saving an empty edit clears the title", function () {
    H.resetState({ player: { mastery_xp: {}, title: "Old Title" }, titleEdit: [] });
    fns.saveTitle();
    eq(S.player.title, "", "title cleared to empty string");
    var f = H.lastSent("save_cosmetics");
    assert(f, "frame sent on clear");
    eq(f.payload.update.title, "", "cleared title in payload");
    assert(/clear/i.test(S.msg || ""), "message indicates cleared: " + S.msg);
  });

  test("title: saveTitle with no player is a no-op (no frame sent, no throw)", function () {
    H.resetState({ player: null, titleEdit: ["Beta"] });
    noThrow(function () { fns.saveTitle(); }, "saveTitle with null player");
    eq(H.sentOfType("save_cosmetics").length, 0, "no frame sent without player");
  });

  test("title: save->resave round-trip is idempotent (same title, frame each time)", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: ["Beta", "Tester"] });
    fns.saveTitle();
    var firstTitle = S.player.title;
    fns.saveTitle();
    eq(S.player.title, firstTitle, "title unchanged on resave");
    eq(S.player.title, "Beta Tester", "expected joined value");
    eq(H.sentOfType("save_cosmetics").length, 2, "a frame per save call");
  });

  test("title: saved cosmetic update omits mastery_xp (preserves server progress)", function () {
    H.resetState({ player: { mastery_xp: { naruto: 800 }, title: "" }, titleEdit: ["Anime"] });
    fns.saveTitle();
    var f = H.lastSent("save_cosmetics");
    assert(f && f.payload && f.payload.update, "update present");
    eq(f.payload.update.hasOwnProperty("mastery_xp"), false, "mastery_xp omitted from update");
  });

  // ---- titleMenu renderer ------------------------------------------------
  test("title: titleMenu renders pool + builder without throwing (clean state)", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: [] });
    var node;
    noThrow(function () { node = fns.titleMenu(); }, "titleMenu clean");
    assert(node && node.querySelector(".tm-pool"), "pool rendered");
    assert(node.querySelector(".tm-builder"), "builder rendered");
    // empty edit => hint in builder, count 0 / MAX
    assert(node.querySelector(".tm-hint"), "hint shown when empty");
    var count = node.querySelector(".tm-count");
    assert(count && count.textContent.indexOf("0 / " + C.MAX_TITLE_WORDS) >= 0, "count shows 0 / MAX: " + (count && count.textContent));
  });

  test("title: titleMenu pool excludes words already in the edit", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: ["Anime"] });
    var node = fns.titleMenu();
    var poolWords = Array.prototype.map.call(node.querySelectorAll(".tm-pool .tm-chip"), function (c) { return c.textContent; });
    assert(poolWords.indexOf("Anime") === -1, "edited word not in pool");
    assert(poolWords.indexOf("Arena") >= 0, "other base word still in pool");
    // builder shows the chosen word as a 'used' chip
    var used = node.querySelectorAll(".tm-builder .tm-chip.used");
    eq(used.length, 1, "one used chip in builder");
  });

  test("title: titleMenu at MAX disables pool chips and shows full count", function () {
    H.resetState({ player: { mastery_xp: {}, title: "" }, titleEdit: ["Beta", "Tester", "The", "of", "the"] });
    var node;
    noThrow(function () { node = fns.titleMenu(); }, "titleMenu full edit");
    var count = node.querySelector(".tm-count");
    assert(count && count.textContent.indexOf(C.MAX_TITLE_WORDS + " / " + C.MAX_TITLE_WORDS) >= 0, "count shows MAX / MAX");
    var poolChips = node.querySelectorAll(".tm-pool .tm-chip");
    if (poolChips.length) {
      assert(poolChips[0].disabled === true, "pool chips disabled at max");
      assert(poolChips[0].className.indexOf("off") >= 0, "pool chips have 'off' class at max");
    }
  });

  test("title: titleMenu renders without throwing when player is null", function () {
    H.resetState({ player: null, titleEdit: [] });
    var node;
    noThrow(function () { node = fns.titleMenu(); }, "titleMenu null player");
    assert(node && node.className.indexOf("title-menu") >= 0, "title-menu node returned");
  });

  test("title: titleMenu Save button disabled when edit matches equipped title (not dirty)", function () {
    H.resetState({ player: { mastery_xp: {}, title: "Beta Tester" }, titleEdit: ["Beta", "Tester"] });
    var node = fns.titleMenu();
    var save = node.querySelector(".tm-save");
    assert(save, "save button exists");
    eq(save.disabled, true, "save disabled when not dirty");
  });
})();

// ============================================================================
// AREA: character select grid, filters, team, search
// ============================================================================
(function () {
  "use strict";
  var H = window.AATest, fns = H.fns, C = H.consts, S = H.S, render = H.render;
  var test = H.test, assert = H.assert, eq = H.eq, deepEq = H.deepEq, near = H.near, noThrow = H.noThrow, throws = H.throws;

  function cells(node) { return node ? node.querySelectorAll(".mg-cell") : []; }
  function gridCells() { return cells(fns.gridArea()); }
  function pathSet(node) {
    var s = {};
    node.querySelectorAll(".mg-cell").forEach(function (c) {
      // title attr holds the display name; use data-search prefix which begins with name+universe+path_name
      s[c.getAttribute("title") || ""] = true;
    });
    return s;
  }
  function visibleCells(node) {
    return Array.prototype.filter.call(node.querySelectorAll(".mg-cell"), function (c) {
      return c.style.display !== "none";
    });
  }

  // ---------------------------------------------------------------- CHAR_SELECT_ORDER
  test("charselect: CHAR_SELECT_ORDER entries are all unique", function () {
    var ord = C.CHAR_SELECT_ORDER;
    assert(Array.isArray(ord), "is array");
    assert(ord.length > 0, "roster order is non-empty");
    eq(new Set(ord).size, ord.length, "no duplicate entries");
  });

  test("charselect: order starts with the starter cluster (naruto first)", function () {
    var ord = C.CHAR_SELECT_ORDER;
    eq(ord[0], "naruto", "naruto leads");
    deepEq(ord.slice(0, 10),
      ["naruto", "luffy", "yuji", "midoriya", "goku", "natsu", "meliodas", "madoka", "asta", "maka"],
      "starter cluster prefix");
  });

  test("charselect: kakashi/uryuu are removed — not in the roster or the select order", function () {
    var ord = C.CHAR_SELECT_ORDER;
    assert(ord.indexOf("kakashi") < 0 && ord.indexOf("uryuu") < 0, "not in select order");
    assert(ord.indexOf("naruto") >= 0 && ord.indexOf("sasuke") >= 0, "real chars present");
    H.resetState({});
    var paths = (S.roster || []).map(function (r) { return r.path_name; });
    assert(paths.indexOf("kakashi") < 0 && paths.indexOf("uryuu") < 0, "removed from roster tracking");
    assert(paths.indexOf("naruto") >= 0, "real roster chars still present");
  });

  // ---------------------------------------------------------------- charUnlocked
  test("charselect: charUnlocked true for always-gate starters regardless of unlocks", function () {
    H.resetState({ player: { unlocks: [] } });
    eq(fns.charUnlocked({ gate: "always" }), true, "always gate");
    eq(fns.charUnlocked({ gate: "" }), true, "empty gate");
    eq(fns.charUnlocked({}), true, "missing gate");
  });

  test("charselect: charUnlocked respects unlock token and all_unlock", function () {
    H.resetState({ player: { unlocks: [] } });
    eq(fns.charUnlocked({ gate: "sasuke_unlock" }), false, "locked w/o token");
    S.player.unlocks = ["sasuke_unlock"];
    eq(fns.charUnlocked({ gate: "sasuke_unlock" }), true, "unlocked by token");
    eq(fns.charUnlocked({ gate: "bakugo_unlock" }), false, "other still locked");
    S.player.unlocks = ["all_unlock"];
    eq(fns.charUnlocked({ gate: "bakugo_unlock" }), true, "all_unlock opens everything");
  });

  test("charselect: charUnlocked is null-safe with no player", function () {
    H.resetState({ player: null });
    eq(fns.charUnlocked({ gate: "always" }), true, "starter ok w/o player");
    eq(fns.charUnlocked({ gate: "sasuke_unlock" }), false, "locked w/o player");
  });

  // ---------------------------------------------------------------- toggleChar
  test("charselect: toggleChar add then remove is an idempotent pair", function () {
    H.resetState({ player: { unlocks: [] } });
    eq(S.team.length, 0, "starts empty");
    fns.toggleChar("naruto");
    deepEq(S.team, ["naruto"], "added once");
    fns.toggleChar("naruto");
    deepEq(S.team, [], "removed -> back to empty");
  });

  test("charselect: toggleChar caps team at 3, rejects 4th", function () {
    H.resetState({ player: { unlocks: [] } });
    fns.toggleChar("naruto");
    fns.toggleChar("luffy");
    fns.toggleChar("goku");
    deepEq(S.team, ["naruto", "luffy", "goku"], "three picked");
    fns.toggleChar("natsu");
    eq(S.team.length, 3, "4th rejected");
    assert(S.team.indexOf("natsu") < 0, "natsu not added");
    eq(S.msgKind, "err", "error feedback set");
  });

  test("charselect: toggleChar keeps team entries unique", function () {
    H.resetState({ player: { unlocks: [] } });
    fns.toggleChar("naruto");
    fns.toggleChar("luffy");
    // toggling an existing member removes it (no duplicate path possible)
    fns.toggleChar("naruto");
    deepEq(S.team, ["luffy"], "re-toggle removed, no dup");
    eq(new Set(S.team).size, S.team.length, "no duplicates");
  });

  test("charselect: toggleChar refuses a locked character", function () {
    H.resetState({ player: { unlocks: [] } });
    // sasuke is gated on sasuke_unlock and present in roster
    fns.toggleChar("sasuke");
    deepEq(S.team, [], "locked char not added");
  });

  test("charselect: toggleChar tolerates an unknown path_name", function () {
    H.resetState({ player: { unlocks: [] } });
    noThrow(function () { fns.toggleChar("___nope___"); }, "unknown char no throw");
    // unknown char has no roster entry => charUnlocked check skipped, gets added (it's not locked)
    deepEq(S.team, ["___nope___"], "unknown added (no roster -> not locked)");
  });

  // ---------------------------------------------------------------- charAbilitySearchText
  test("charselect: charAbilitySearchText non-empty and includes ability text for naruto", function () {
    H.resetState({});
    var txt = fns.charAbilitySearchText("naruto");
    assert(typeof txt === "string" && txt.length > 0, "non-empty once abilityInfo loaded");
    eq(txt, txt.toLowerCase(), "lowercased");
    assert(txt.indexOf("toad kumite") >= 0, "includes ability name text");
    assert(txt.indexOf("harmful") >= 0, "includes class text");
  });

  test("charselect: charAbilitySearchText returns '' for unknown path", function () {
    H.resetState({});
    eq(fns.charAbilitySearchText("___unknown_char___"), "", "empty for unknown");
  });

  test("charselect: charAbilitySearchText is stable across repeated calls (memoized)", function () {
    H.resetState({});
    var a = fns.charAbilitySearchText("luffy");
    var b = fns.charAbilitySearchText("luffy");
    eq(a, b, "same value twice");
  });

  // ---------------------------------------------------------------- gridArea default
  test("charselect: gridArea renders one .mg-cell per roster entry", function () {
    H.resetState({ player: { unlocks: [] } });
    var node = noThrow(function () { return fns.gridArea(); }, "gridArea no throw");
    eq(cells(node).length, C.CHAR_SELECT_ORDER.length, "one cell per roster entry, no filters");
  });

  test("charselect: gridArea cells carry data-search with name/universe/path", function () {
    H.resetState({ player: { unlocks: [] } });
    var node = fns.gridArea();
    var first = node.querySelector(".mg-cell");
    var ds = first.getAttribute("data-search");
    assert(ds && ds.length > 0, "data-search present");
    eq(ds, ds.toLowerCase(), "data-search lowercased");
  });

  test("charselect: gridArea Category dropdown lists the bounty categories", function () {
    H.resetState({ player: { unlocks: [] } });
    var node = fns.gridArea();
    var sels = node.querySelectorAll("select.filter-sel");
    assert(sels.length >= 2, "two filter selects (anime + category)");
    var catSel = sels[1];
    var opts = catSel.querySelectorAll("option");
    // first option is the "Any" sentinel, then sorted categories (35)
    eq(opts[0].value, "", "Any sentinel first");
    eq(opts.length, 36, "Any + 35 categories");
  });

  // ---------------------------------------------------------------- gridArea filters
  test("charselect: animeFilter shrinks grid to One Piece members (membership)", function () {
    H.resetState({ player: { unlocks: [] }, animeFilter: "One Piece" });
    var node = fns.gridArea();
    var n = cells(node).length;
    assert(n < C.CHAR_SELECT_ORDER.length, "fewer than default");
    eq(n, 6, "6 One Piece select chars");
    var names = pathSet(node);
    [fns.nameFor("luffy"), fns.nameFor("zoro")].forEach(function (nm) { assert(names[nm], "contains " + nm); });
  });

  test("charselect: catFilter shrinks grid to 'air' category members (membership)", function () {
    H.resetState({ player: { unlocks: [] }, catFilter: "air" });
    var node = fns.gridArea();
    var n = cells(node).length;
    assert(n < C.CHAR_SELECT_ORDER.length, "fewer than default");
    eq(n, 10, "10 air members in select");
  });

  test("charselect: colorFilters AND-narrows the grid", function () {
    H.resetState({ player: { unlocks: [] }, colorFilters: [0] });
    var one = cells(fns.gridArea()).length;
    H.resetState({ player: { unlocks: [] }, colorFilters: [0, 1] });
    var two = cells(fns.gridArea()).length;
    assert(one < C.CHAR_SELECT_ORDER.length, "single color narrows");
    assert(two <= one, "adding a second color (AND) cannot widen");
  });

  test("charselect: unknown catFilter yields 0 cells without throwing", function () {
    H.resetState({ player: { unlocks: [] }, catFilter: "___no_such_category___" });
    var node = noThrow(function () { return fns.gridArea(); }, "no throw on bad cat");
    eq(cells(node).length, 0, "no members match");
  });

  test("charselect: combined filters re-render stable (idempotent)", function () {
    H.resetState({ player: { unlocks: [] }, animeFilter: "One Piece", colorFilters: [] });
    var a = cells(fns.gridArea()).length;
    var b = cells(fns.gridArea()).length;
    eq(a, b, "two renders give same cell count");
  });

  // ---------------------------------------------------------------- applyCharFilter
  test("charselect: applyCharFilter hides non-matching cells in place", function () {
    H.resetState({ player: { unlocks: [] } });
    var node = fns.gridArea();
    var before = cells(node).length;
    eq(before, C.CHAR_SELECT_ORDER.length, "full grid");
    fns.applyCharFilter(node, "luffy");
    var vis = visibleCells(node);
    assert(vis.length >= 1 && vis.length < before, "filtered to a subset");
    vis.forEach(function (c) {
      assert((c.getAttribute("data-search") || "").indexOf("luffy") >= 0, "visible cell matches query");
    });
  });

  test("charselect: applyCharFilter with empty query shows all cells (idempotent reset)", function () {
    H.resetState({ player: { unlocks: [] } });
    var node = fns.gridArea();
    fns.applyCharFilter(node, "naruto");
    assert(visibleCells(node).length < C.CHAR_SELECT_ORDER.length, "narrowed");
    fns.applyCharFilter(node, "");
    eq(visibleCells(node).length, C.CHAR_SELECT_ORDER.length, "empty query restores all");
    // applying empty twice stays full
    fns.applyCharFilter(node, "");
    eq(visibleCells(node).length, C.CHAR_SELECT_ORDER.length, "still full");
  });

  test("charselect: applyCharFilter tolerates null query and empty grid node", function () {
    H.resetState({ player: { unlocks: [] } });
    var node = fns.gridArea();
    noThrow(function () { fns.applyCharFilter(node, null); }, "null query no throw");
    eq(visibleCells(node).length, C.CHAR_SELECT_ORDER.length, "null query shows all");
    var empty = document.createElement("div");
    noThrow(function () { fns.applyCharFilter(empty, "anything"); }, "empty grid no throw");
  });

  // ---------------------------------------------------------------- randomizeTeam
  test("charselect: randomizeTeam picks 3 unlocked unique chars", function () {
    H.resetState({ player: { unlocks: [] } });
    fns.randomizeTeam();
    eq(S.team.length, 3, "exactly 3");
    eq(new Set(S.team).size, 3, "unique");
    S.team.forEach(function (pn) {
      var c = S.roster.find(function (x) { return x.path_name === pn; });
      assert(c && fns.charUnlocked(c), pn + " is unlocked");
    });
  });

  test("charselect: randomizeTeam re-run replaces (still exactly 3 unique)", function () {
    H.resetState({ player: { unlocks: [] } });
    fns.randomizeTeam();
    fns.randomizeTeam();
    eq(S.team.length, 3, "still 3 after second run");
    eq(new Set(S.team).size, 3, "still unique");
  });

  // ---------------------------------------------------------------- selectAndInspect
  test("charselect: selectAndInspect is two-click — focus, then add, then remove", function () {
    H.resetState({ player: { unlocks: [] } });
    fns.selectAndInspect("naruto");
    deepEq(S.team, [], "first click focuses only (no team change)");
    assert(S.menuInspect && S.menuInspect.path_name === "naruto", "inspect set to naruto");
    fns.selectAndInspect("naruto");
    deepEq(S.team, ["naruto"], "second click adds to team");
    fns.selectAndInspect("naruto");
    deepEq(S.team, [], "third click removes from team");
    assert(S.menuInspect && S.menuInspect.path_name === "naruto", "inspect still on naruto");
  });

  test("charselect: second click on a full team does not add a 4th (shows error)", function () {
    H.resetState({ player: { unlocks: [] }, team: ["naruto", "luffy", "goku"] });
    fns.selectAndInspect("natsu");   // first click: focus only
    assert(S.menuInspect && S.menuInspect.path_name === "natsu", "focuses natsu");
    eq(S.team.length, 3, "team unchanged on focus");
    fns.selectAndInspect("natsu");   // second click: attempt to add onto a full team
    eq(S.team.length, 3, "team still 3 — no 4th added");
    assert(S.team.indexOf("natsu") < 0, "natsu not added");
    eq(S.msgKind, "err", "team-full error shown");
  });

  // ---------------------------------------------------------------- categoriesFor (grid badges)
  test("charselect: categoriesFor returns sorted archetypes for naruto", function () {
    H.resetState({});
    var cats = fns.categoriesFor("naruto");
    deepEq(cats, ["air", "ninja"], "naruto archetypes (sorted)");
    var unknown = fns.categoriesFor("___nobody___");
    deepEq(unknown, [], "empty for unknown char");
  });
})();

// ============================================================================
// AREA: session/net message handling + state hygiene
// ============================================================================
(function () {
  "use strict";
  var H = window.AATest, fns = H.fns, C = H.consts, S = H.S, render = H.render;
  var test = H.test, assert = H.assert, eq = H.eq, deepEq = H.deepEq, near = H.near, noThrow = H.noThrow, throws = H.throws;

  function appHtml() { var a = document.getElementById("app"); return a ? a.innerHTML : ""; }

  // ---------------------------------------------------------------------------
  // onMatch — records kind + apBefore (= current player.ap) + screen battle
  // ---------------------------------------------------------------------------
  test("session: onMatch (Quick) records kind, apBefore, sets battle screen", function () {
    H.resetState({ player: { username: "X", ap: 4200 }, queued: true });
    fns.onMatch({ opponent: { username: "Foe" }, first_turn: true, seed: 7, canonical_role: 0 }, "Quick Match");
    eq(S.screen, "battle", "screen -> battle");
    eq(S.queued, false, "queued cleared");
    eq(S.match.kind, "Quick Match", "kind recorded");
    eq(S.match.apBefore, 4200, "apBefore = player.ap at match start");
    eq(S.match.canonical_role, 0, "canonical_role carried");
    deepEq(S.match.opponent, { username: "Foe" }, "opponent carried");
  });

  test("session: onMatch defaults apBefore to 0 when player/ap missing", function () {
    H.resetState({ player: null });
    fns.onMatch({}, "Quick Match");
    eq(S.match.apBefore, 0, "apBefore falls back to 0");
    deepEq(S.match.opponent, {}, "opponent defaults to {}");
    eq(S.match.kind, "Quick Match", "kind kept");
  });

  test("session: onMatch with no kind uses 'Match'", function () {
    H.resetState({ player: { ap: 10 } });
    fns.onMatch({});
    eq(S.match.kind, "Match", "default kind label");
  });

  // Regression: tapping a TARGETED ability whose valid-target set is empty (e.g. every legal
  // target is currently invulnerable) must REFUSE, not auto-stage a target-less action that
  // pops a phantom "queued" panel. Mirrors the desktop engine, which can't commit an ability
  // with no flagged target. Drives the real rendered board so it exercises onAbilityTap.
  test("battle: tapping an ability with no valid targets refuses (no phantom queued panel)", function () {
    function mkChar(pn, abilities) { return { path_name: pn, hp: 100, max_hp: 100, dead: false, effects: [], abilities: abilities || [] }; }
    var energy = { pool: { 0: 5, 1: 5, 2: 5, 3: 5 } };
    var snap = {
      acting_role: "p1",
      sides: [
        { role: "p1", username: "Me", energy: energy, team: [
          mkChar("res://t/a", [
            { source_basename: "notarget",  ability_name: "All-Invuln Skill", special_targets: [],  target_type: 0, cost: {}, cooldown_remaining: 0, usable: true },
            { source_basename: "hastarget", ability_name: "Has-Target Skill", special_targets: [3], target_type: 0, cost: {}, cooldown_remaining: 0, usable: true },
          ]),
          mkChar("res://t/b"), mkChar("res://t/c"),
        ] },
        { role: "p2", username: "Opp", energy: energy, team: [ mkChar("res://t/x"), mkChar("res://t/y"), mkChar("res://t/z") ] },
      ],
    };
    H.resetState({ screen: "battle", snapshot: snap, match: { canonical_role: 0, opponent: {} }, player: {},
      staged: [], targeting: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, prevHp: {}, described: null, msg: "", msgKind: "" });
    render();
    var tiles = document.querySelectorAll(".team-col.mine .abilities .ab");
    eq(tiles.length, 2, "two ability tiles rendered (both tappable)");
    // tap the ability with no valid targets
    tiles[0].dispatchEvent(new MouseEvent("click", { bubbles: true }));
    eq(S.staged.length, 0, "no action staged (pre-fix it auto-staged with [] targets)");
    eq(S.targeting, null, "did not enter target selection");
    assert(/no valid targets/i.test(S.msg || ""), "shows a 'no valid targets' message; got: " + S.msg);
    eq(document.querySelectorAll(".team-col.mine .staged").length, 0, "no phantom queued panel in the DOM");
    // sanity: a normal targeted ability still enters target selection
    render();
    var tiles2 = document.querySelectorAll(".team-col.mine .abilities .ab");
    tiles2[1].dispatchEvent(new MouseEvent("click", { bubbles: true }));
    assert(S.targeting && S.targeting.ability_idx === 1, "a targeted ability with valid targets still enters targeting");
    deepEq(S.targeting.special_targets, [3], "targeting carries the server's valid target set");
  });

  // THE CLICKED CHARACTER IS THE PRIMARY TARGET. The server walks target_idxs in order and
  // targeter_component.add_target makes the FIRST index it receives the main_target; nothing
  // downstream re-derives it. So for an AoE the clicked character must LEAD the list, or every
  // ability that splits main-vs-splash (X-Burner 25/10, gojo3 45/15, korra7 40/20, boruto6 20/10,
  // ace3, jupiter3, ganta3, lizandpatty1/2, …) silently resolves on the wrong character.
  // The bug: special_targets is sliced straight from the server, which builds it in ascending
  // canonical order, so the top enemy was always primary no matter who you clicked.
  test("battle: an AoE sends the CLICKED target first (it becomes the server's main_target)", function () {
    function mkChar(pn, abilities) { return { path_name: pn, hp: 100, max_hp: 100, dead: false, effects: [], abilities: abilities || [] }; }
    var energy = { pool: { 0: 5, 1: 5, 2: 5, 3: 5 } };
    function mkSnap() {
      return { acting_role: "p1", sides: [
        { role: "p1", username: "Me", energy: energy, team: [
          mkChar("res://t/a", [
            // target_type 2 = ALL, 1 = ALL_FACTION, 0 = SINGLE.
            { source_basename: "aoe",  ability_name: "Splash All",     special_targets: [3, 4, 5], target_type: 2, cost: {}, cooldown_remaining: 0, usable: true },
            { source_basename: "fac",  ability_name: "Splash Faction", special_targets: [3, 4, 5], target_type: 1, cost: {}, cooldown_remaining: 0, usable: true },
            { source_basename: "one",  ability_name: "Single",         special_targets: [3, 4, 5], target_type: 0, cost: {}, cooldown_remaining: 0, usable: true },
          ]),
          mkChar("res://t/b"), mkChar("res://t/c"),
        ] },
        { role: "p2", username: "Opp", energy: energy, team: [ mkChar("res://t/x"), mkChar("res://t/y"), mkChar("res://t/z") ] },
      ] };
    }
    // Tap ability `slot`, then click the enemy at canonical index `clicked`.
    function castAt(slot, clicked) {
      H.resetState({ screen: "battle", snapshot: mkSnap(), match: { canonical_role: 0, opponent: {} }, player: {},
        staged: [], targeting: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, prevHp: {}, described: null, msg: "", msgKind: "" });
      render();
      document.querySelectorAll(".team-col.mine .abilities .ab")[slot].dispatchEvent(new MouseEvent("click", { bubbles: true }));
      assert(S.targeting, "entered targeting for slot " + slot);
      render();
      var tile = document.querySelector('.char[data-canon="' + clicked + '"]');
      assert(tile, "enemy tile canon " + clicked + " is in the DOM");
      tile.dispatchEvent(new MouseEvent("click", { bubbles: true }));
      eq(S.staged.length, 1, "one action staged");
      return S.staged[0].target_idxs;
    }
    // ALL: every valid target still goes out, but the clicked one leads.
    deepEq(castAt(0, 5), [5, 3, 4], "ALL clicked on the BOTTOM enemy leads with 5");
    deepEq(castAt(0, 4), [4, 3, 5], "ALL clicked on the MIDDLE enemy leads with 4");
    deepEq(castAt(0, 3), [3, 4, 5], "ALL clicked on the TOP enemy is still [3,4,5]");
    // ALL_FACTION: same rule, restricted to the clicked side.
    deepEq(castAt(1, 5), [5, 3, 4], "ALL_FACTION clicked on the bottom enemy leads with 5");
    // SINGLE is unaffected — one target, and it is the clicked one.
    deepEq(castAt(2, 4), [4], "SINGLE sends only the clicked target");
  });

  // Energy pips render the game's own symbol PNGs (assets/images/<color>_energy.png). Locks the
  // index→image mapping so RANDOM (pure-black random_energy.png) can never silently revert to a
  // white/tinted dot — the bug this replaced.
  test("battle: cost pips use the energy symbol PNGs (random = random_energy.png, not white)", function () {
    function mkChar(pn, abilities) { return { path_name: pn, hp: 100, max_hp: 100, dead: false, effects: [], abilities: abilities || [] }; }
    var energy = { pool: { 0: 3, 1: 3, 2: 3, 3: 3 } };
    var snap = { acting_role: "p1", sides: [
      { role: "p1", username: "Me", energy: energy, team: [
        mkChar("res://t/a", [
          { source_basename: "wr", ability_name: "W+R", special_targets: [3], target_type: 0, cost: { 2: 1, 4: 1 }, cooldown_remaining: 0, usable: true },
        ]),
        mkChar("res://t/b"), mkChar("res://t/c"),
      ] },
      { role: "p2", username: "Opp", energy: energy, team: [ mkChar("res://t/x"), mkChar("res://t/y"), mkChar("res://t/z") ] },
    ] };
    H.resetState({ screen: "battle", snapshot: snap, match: { canonical_role: 0, opponent: {} }, player: {},
      staged: [], targeting: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, prevHp: {}, described: null, msg: "", msgKind: "" });
    render();
    var pips = document.querySelectorAll(".team-col.mine .abilities .ab .cost .epx");
    eq(pips.length, 2, "two cost pips (1 white + 1 random)");
    var byTitle = {};
    pips.forEach(function (p) { byTitle[p.getAttribute("title")] = getComputedStyle(p).backgroundImage; });
    assert(/white_energy\.png/.test(byTitle.White || ""), "White pip uses white_energy.png");
    assert(/random_energy\.png/.test(byTitle.Random || ""), "Random pip uses random_energy.png");
    assert(!/white_energy/.test(byTitle.Random || ""), "Random pip is NOT the white image");
    // the energy-pool "Total" pip reuses the RANDOM orb, not the 'T' total_energy.png tile
    var totalPip = document.querySelector(".energy .epip.total .epx");
    assert(totalPip, "pool total pip rendered");
    var totalBg = totalPip ? getComputedStyle(totalPip).backgroundImage : "";
    assert(/random_energy\.png/.test(totalBg), "total pip uses random_energy.png");
    assert(!/total_energy/.test(totalBg), "total pip is NOT total_energy.png");
  });

  // Invisible effects (visibility != "all") are visible ONLY to the side that CAST them — gated by
  // the caster (e.user canonical idx) vs the viewer, NOT by which character hosts the effect. Locks
  // the fix for the leak where an enemy's invisible debuff on MY char (e.g. Yubel's taunt) showed.
  test("battle: invisible effects show only to the caster's side, not by host character", function () {
    function eff(name, visibility, user, rid) { return { name: name, display_name: name, visibility: visibility, user: user, unique_render_id: rid, system: false, duration: 2, mag: 0, display_mag: false, display_stacks: false, stack_count: 0, icon_path: "", description: name }; }
    function mkChar(pn, effects) { return { path_name: pn, hp: 100, max_hp: 100, dead: false, effects: effects || [], abilities: [] }; }
    var energy = { pool: { 0: 1, 1: 1, 2: 1, 3: 1 } };
    // viewer = p1 (role 0): my chars canonical 0-2, enemy 3-5.
    var myChar = mkChar("res://t/mine", [
      eff("EnemyTaunt", "enemy_hidden", 3, 1),   // invisible, enemy-cast onto MY char -> HIDE (the reported bug)
      eff("MyBuff",     "user_only",    0, 2),   // invisible, self-cast              -> SHOW
      eff("PublicBuff", "all",          0, 3),   // visible                           -> SHOW
    ]);
    var enemyChar = mkChar("res://t/foe", [
      eff("EnemyHiddenBuff", "enemy_hidden", 3, 4),  // invisible, enemy-cast on enemy char -> HIDE
      eff("MyHiddenDebuff",  "user_only",    0, 5),  // invisible, self-cast on enemy       -> SHOW (I cast it)
      eff("PublicDebuff",    "all",          3, 6),  // visible                             -> SHOW
    ]);
    H.resetState({ screen: "battle", snapshot: { acting_role: "p1", sides: [
      { role: "p1", username: "Me", energy: energy, team: [myChar, mkChar("res://t/b"), mkChar("res://t/c")] },
      { role: "p2", username: "Opp", energy: energy, team: [enemyChar, mkChar("res://t/y"), mkChar("res://t/z")] },
    ] }, match: { canonical_role: 0, opponent: {} }, player: {}, staged: [], targeting: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, prevHp: {}, described: null, msg: "", msgKind: "" });
    render();
    var mineEff = document.querySelectorAll('.char[data-canon="0"] .effects .eff');
    var foeEff = document.querySelectorAll('.char[data-canon="3"] .effects .eff');
    eq(mineEff.length, 2, "my char: enemy's invisible taunt hidden; my buff + public shown");
    eq(foeEff.length, 2, "enemy char: enemy's invisible buff hidden; my invisible debuff + public shown");
    // every effect still shown on MY char is caster-mine (eff-ally) — the enemy-cast invisible one is gone
    Array.prototype.forEach.call(mineEff, function (n) { assert(/eff-ally/.test(n.className), "no enemy-cast invisible effect leaks onto my char"); });
  });

  // Invisibility SENSING: Toph's passive reveals invisible *Physical* enemy effects; Kurotsuchi
  // Mayuri's "Data Collection" mark reveals *every* invisible enemy effect — but only while the
  // sensor is alive. Ported from effect_storage_component.get_effect_clusters; the bug was that the
  // web client dropped this reveal and always hid the opponent's invisible effects.
  function senseEff(name, visibility, user, rid, opts) {
    opts = opts || {};
    return { name: name, display_name: name, visibility: visibility, user: user, unique_render_id: rid, system: false, duration: 2, mag: 0, display_mag: false, display_stacks: false, stack_count: 0, icon_path: "", description: name, is_physical: !!opts.physical, effect_type: opts.type || 0 };
  }
  function senseChar(pn, effects) { return { path_name: pn, hp: 100, max_hp: 100, dead: false, banished: false, effects: effects || [], abilities: [] }; }
  function senseState(myTeam, enemyChar) {
    var energy = { pool: { 0: 1, 1: 1, 2: 1, 3: 1 } };
    H.resetState({ screen: "battle", snapshot: { acting_role: "p1", sides: [
      { role: "p1", username: "Me", energy: energy, team: myTeam },
      { role: "p2", username: "Opp", energy: energy, team: [enemyChar, senseChar("res://y"), senseChar("res://z")] },
    ] }, match: { canonical_role: 0, opponent: {} }, player: {}, staged: [], targeting: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, prevHp: {}, described: null, msg: "", msgKind: "" });
    render();
    return document.querySelectorAll('.char[data-canon="3"] .effects .eff').length;
  }

  test("battle: Toph reveals invisible Physical enemy effects, not non-physical, and only while alive", function () {
    function enemy() {
      return senseChar("res://foe", [
        senseEff("HiddenPhys",   "enemy_hidden", 3, 11, { physical: true }),   // enemy-cast, invisible, PHYSICAL
        senseEff("HiddenEnergy", "enemy_hidden", 3, 12, { physical: false }),  // enemy-cast, invisible, non-physical
      ]);
    }
    // Baseline: no sensor on my team -> both invisible enemy effects hidden.
    eq(senseState([senseChar("res://a"), senseChar("res://b"), senseChar("res://c")], enemy()), 0, "no sensor: enemy's invisible effects stay hidden");
    // Toph alive -> only the Physical one surfaces.
    eq(senseState([senseChar("toph"), senseChar("res://b"), senseChar("res://c")], enemy()), 1, "Toph reveals the physical hidden effect only");
    // Dead Toph senses nothing (character_in_team requires alive).
    var deadToph = senseChar("toph"); deadToph.dead = true;
    eq(senseState([deadToph, senseChar("res://b"), senseChar("res://c")], enemy()), 0, "dead Toph reveals nothing");
  });

  test("battle: Kurotsuchi Data Collection mark reveals all invisible enemy effects (only while marked & alive)", function () {
    function enemy() {
      return senseChar("res://foe", [
        senseEff("HiddenEnergy", "enemy_hidden", 3, 21, { physical: false }),  // enemy-cast, invisible, NON-physical
      ]);
    }
    var dataCollection = senseEff("Data Collection", "user_only", 0, 30, { type: 25 });   // self MARK on Mayuri
    // Marked, living Mayuri -> the non-physical invisible enemy effect is revealed (Toph could not).
    eq(senseState([senseChar("kurotsuchi", [dataCollection]), senseChar("res://b"), senseChar("res://c")], enemy()), 1, "Data Collection reveals every invisible enemy effect");
    // Mayuri present but WITHOUT the mark -> no reveal.
    eq(senseState([senseChar("kurotsuchi"), senseChar("res://b"), senseChar("res://c")], enemy()), 0, "unmarked Mayuri reveals nothing");
    // Banished marked Mayuri -> no reveal (sensor must be alive/unbanished).
    var banished = senseChar("kurotsuchi", [dataCollection]); banished.banished = true;
    eq(senseState([banished, senseChar("res://b"), senseChar("res://c")], enemy()), 0, "banished Mayuri reveals nothing");
  });

  // Diane's Mother Catastrophe (diane1) applies an invisible, Physical pending-strike marker to
  // Diane herself. Server fix: diane1.gd now sets ticking_trigger.invisible=true, so the wire ships
  // it as an invisible effect whose user is Diane. It must show to Diane's OWNER, hide from the
  // targeted enemy, and be revealed to that enemy only by a sensing kit (Toph reads Physical).
  test("battle: Diane's invisible Physical strike-marker — owner sees it; enemy only via a revealer", function () {
    var ownMarker = senseEff("Mother Catastrophe", "user_only", 0, 77, { physical: true });    // on my Diane (canon 0)
    var foeMarker = function () { return senseEff("Mother Catastrophe", "enemy_hidden", 3, 78, { physical: true }); }; // on enemy Diane (canon 3)
    // (A) The owner sees their own Diane's marker.
    H.resetState({ screen: "battle", snapshot: { acting_role: "p1", sides: [
      { role: "p1", username: "Me", energy: { pool: { 0: 1, 1: 1, 2: 1, 3: 1 } }, team: [senseChar("diane", [ownMarker]), senseChar("res://b"), senseChar("res://c")] },
      { role: "p2", username: "Opp", energy: { pool: { 0: 1, 1: 1, 2: 1, 3: 1 } }, team: [senseChar("res://x"), senseChar("res://y"), senseChar("res://z")] },
    ] }, match: { canonical_role: 0, opponent: {} }, player: {}, staged: [], targeting: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, prevHp: {}, described: null, msg: "", msgKind: "" });
    render();
    eq(document.querySelectorAll('.char[data-canon="0"] .effects .eff').length, 1, "owner sees their own Diane's invisible marker");
    // (B) The targeted enemy does NOT see it without a revealer; (C) Toph reveals the Physical marker.
    eq(senseState([senseChar("res://a"), senseChar("res://b"), senseChar("res://c")], senseChar("diane", [foeMarker()])), 0, "enemy can't see Diane's hidden marker");
    eq(senseState([senseChar("toph"), senseChar("res://b"), senseChar("res://c")], senseChar("diane", [foeMarker()])), 1, "Toph reveals Diane's Physical marker to the enemy");
  });

  // Saved-team restoration: the last team is persisted server-side as player.characters; the client
  // restores S.team from it on login (so a refresh doesn't wipe it) and pushes every change back via
  // save_cosmetics (so a later cosmetic save can't clobber the team with a stale roster).
  test("team: login restores S.team from player.characters", function () {
    H.resetState({ team: [], player: null });
    H.emit("receive_login_response", { json_string: JSON.stringify({ id: 1, player: { characters: ["res://a", "res://b", "res://c"] } }) });
    deepEq(S.team, ["res://a", "res://b", "res://c"], "team restored from player.characters");
    eq(S.screen, "menu", "logged in -> menu");
  });

  test("team: login restore drops non-strings and caps at 3", function () {
    H.resetState({ team: ["stale"], player: null });
    H.emit("receive_login_response", { json_string: JSON.stringify({ id: 1, player: { characters: ["a", null, "b", "c", "d"] } }) });
    deepEq(S.team, ["a", "b", "c"], "filtered to strings, capped to 3");
  });

  test("team: login with no saved characters clears the team", function () {
    H.resetState({ team: ["stale"], player: null });
    H.emit("receive_login_response", { json_string: JSON.stringify({ id: 1, player: { username: "X" } }) });
    deepEq(S.team, [], "no characters field -> empty team");
  });

  test("team: toggling a character syncs player.characters and saves it", function () {
    H.resetState({ player: { username: "X", characters: [], unlocks: [] }, team: [], roster: [{ path_name: "res://gon", name: "Gon" }] });
    fns.toggleChar("res://gon");
    deepEq(S.team, ["res://gon"], "added to the live selection");
    deepEq(S.player.characters, ["res://gon"], "player.characters kept in lockstep");
    var saves = H.sentOfType("save_cosmetics");
    assert(saves.length >= 1, "a save_cosmetics frame was sent");
    deepEq(saves[saves.length - 1].payload.update.characters, ["res://gon"], "saved blob carries the current team (not a stale one)");
  });

  test("team: removing a character persists the smaller team", function () {
    H.resetState({ player: { username: "X", characters: ["res://gon"], unlocks: [] }, team: ["res://gon"], roster: [{ path_name: "res://gon", name: "Gon" }] });
    fns.toggleChar("res://gon");   // toggle off
    deepEq(S.team, [], "removed from the live selection");
    deepEq(S.player.characters, [], "player.characters synced to empty");
  });

  // Registration: the login screen's Register button sends a register frame; a success response
  // auto-logs-in with the same credentials, a failure surfaces the server's message.
  test("login: successful register auto-logs-in with the same credentials", function () {
    H.resetState({ screen: "login", conn: "connected", _regCreds: { url: "ws://x", user: "newguy", pass: "pw", remember: false } });
    H.emit("receive_register_response", { message: "Registration successful! Logging you in…" });
    var logins = H.sentOfType("login");
    assert(logins.length >= 1, "a login frame was sent after a successful register");
    eq(logins[logins.length - 1].payload.username, "newguy", "auto-login uses the registered username");
  });

  test("login: failed register shows the server message and does not log in", function () {
    H.resetState({ screen: "login", conn: "connected", _regCreds: { url: "ws://x", user: "taken", pass: "pw", remember: false } });
    H.emit("receive_register_response", { message: "Registration failed! An account with that name already exists." });
    eq(S.msg, "Registration failed! An account with that name already exists.", "shows the failure message");
    eq(S.msgKind, "err", "failure marked as error");
    eq(H.sentOfType("login").length, 0, "no auto-login on a failed register");
  });

  // Reconnect restores the queue-derived match type + AP baseline (previously dropped), so the
  // game-over modal can show the match type row and derive AP gained after a reconnected match.
  test("reconnect: resumes with match type + AP baseline restored (quick)", function () {
    function mkChar(pn) { return { path_name: pn, hp: 100, max_hp: 100, dead: false, effects: [], abilities: [] }; }
    var energy = { pool: { 0: 1, 1: 1, 2: 1, 3: 1 } };
    var snap = { sides: [ { role: "p1", username: "Me", team: [mkChar("a"), mkChar("b"), mkChar("c")], energy: energy }, { role: "p2", username: "Opp", team: [mkChar("x"), mkChar("y"), mkChar("z")], energy: energy } ], acting_role: "p1", match_over: false };
    H.resetState({ player: { ap: 1000, streak: 2 }, reconnecting: true });
    H.emit("receive_session_reconnect", { info: JSON.stringify({ match_type: 1, enemy: {}, canonical_role: 0, snapshot: snap }) });
    eq(S.screen, "battle", "resumed into battle");
    eq(S.match && S.match.kind, "Quick Match", "match type restored (match_type 1 -> Quick Match)");
    eq(S.match && S.match.apBefore, 1000, "apBefore seeded from the reconnect-time AP");
    eq(S.match && S.match.streakBefore, 2, "streakBefore seeded from the reconnect-time streak");
  });

  test("reconnect: maps ranked match_type (3) to the Ladder Match label", function () {
    function mkChar(pn) { return { path_name: pn, hp: 100, max_hp: 100, dead: false, effects: [], abilities: [] }; }
    var energy = { pool: { 0: 1, 1: 1, 2: 1, 3: 1 } };
    var snap = { sides: [ { role: "p1", team: [mkChar("a"), mkChar("b"), mkChar("c")], energy: energy }, { role: "p2", team: [mkChar("x"), mkChar("y"), mkChar("z")], energy: energy } ], acting_role: "p1", match_over: false };
    H.resetState({ player: { ap: 500, streak: 0 }, reconnecting: true });
    H.emit("receive_session_reconnect", { info: JSON.stringify({ match_type: 3, canonical_role: 1, snapshot: snap }) });
    eq(S.match && S.match.kind, "Ladder Match", "match_type 3 -> Ladder Match");
  });

  // bounty_rerolls / active_bounties are DICTS; the save_cosmetics blob must never default them to
  // 0 / [] (that corrupted the server: a float bounty_rerolls crashed get_bounty_rerolls and an []
  // active_bounties wiped the player's bounties).
  test("cosmetics: makeCosmeticUpdate defaults bounty fields to {} (not 0/[]) when absent", function () {
    var upd = fns.makeCosmeticUpdate({ username: "x" });
    deepEq(upd.bounty_rerolls, {}, "bounty_rerolls defaults to {} (a dict), not 0");
    deepEq(upd.active_bounties, {}, "active_bounties defaults to {} (a dict), not []");
  });

  test("cosmetics: makeCosmeticUpdate preserves existing bounty dicts", function () {
    var upd = fns.makeCosmeticUpdate({ username: "x", bounty_rerolls: { naruto: 2 }, active_bounties: { naruto: [1, 2, 3] } });
    deepEq(upd.bounty_rerolls, { naruto: 2 }, "keeps the real bounty_rerolls dict");
    deepEq(upd.active_bounties, { naruto: [1, 2, 3] }, "keeps the real active_bounties dict");
  });

  // Avatar URL editor: applyAvatar("") resets to the default + saves; the modal renders on click.
  // (The valid-URL onload / bad-URL onerror paths load real images and are covered in the preview.)
  test("avatar: applyAvatar('') resets to default and persists it", function () {
    H.resetState({ player: { username: "x", avatar_url: "http://old.example/a.png" }, avatarEdit: true });
    fns.applyAvatar("");
    eq(S.player.avatar_url, "", "avatar_url reset to default (empty)");
    eq(S.avatarEdit, null, "editor closed");
    var saves = H.sentOfType("save_cosmetics");
    assert(saves.length >= 1, "a save_cosmetics frame was sent");
    eq(saves[saves.length - 1].payload.update.avatar_url, "", "the save carries the empty avatar_url");
  });

  test("avatar: the editor modal renders on the menu when avatarEdit is set", function () {
    H.resetState({ player: { username: "x", avatar_url: "" }, screen: "menu", menuOverlay: null, queued: false, avatarEdit: true, roster: [] });
    render();
    assert(!!document.querySelector(".av-modal"), "avatar modal present");
    assert(!!document.querySelector(".av-modal .av-url"), "URL input present");
  });

  test("avatar: clicking the player-panel avatar opens the editor", function () {
    H.resetState({ player: { username: "x", avatar_url: "" }, screen: "menu", menuOverlay: null, queued: false, avatarEdit: null, roster: [] });
    render();
    var av = document.querySelector(".pp-avatar");
    assert(!!av, "avatar element present");
    av.dispatchEvent(new Event("click", { bubbles: true }));
    eq(S.avatarEdit, true, "clicking the avatar sets avatarEdit");
  });

  // Private match: mutual invite. queuePrivate sends the target + team, sets the waiting state.
  test("private: queuePrivate sends a queue_private frame with the target + team", function () {
    H.resetState({ team: ["a", "b", "c"], privatePrompt: true });
    fns.queuePrivate("bob");
    var q = H.sentOfType("queue_private");
    assert(q.length >= 1, "queue_private frame sent");
    eq(q[q.length - 1].payload.target_username, "bob", "target username sent");
    deepEq(q[q.length - 1].payload.characters, ["a", "b", "c"], "team sent");
    eq(S.queued, true, "queued");
    eq(S.privateTarget, "bob", "privateTarget set (drives the waiting message)");
    eq(S.privatePrompt, null, "invite prompt closed");
  });

  test("private: queuePrivate rejects an empty username or incomplete team", function () {
    H.resetState({ team: ["a", "b", "c"] });
    fns.queuePrivate("");
    eq(H.sentOfType("queue_private").length, 0, "nothing sent for an empty username");
    eq(S.msgKind, "err", "error shown");
    H.resetState({ team: ["a", "b"] });
    fns.queuePrivate("bob");
    eq(H.sentOfType("queue_private").length, 0, "nothing sent when the team isn't 3");
    eq(S.msgKind, "err", "error shown");
  });

  test("private: the invite modal renders on the menu when privatePrompt is set", function () {
    H.resetState({ player: { username: "x" }, screen: "menu", menuOverlay: null, queued: false, privatePrompt: true, team: [], roster: [] });
    render();
    assert(!!document.querySelector(".pm-modal"), "private modal present");
    assert(!!document.querySelector(".pm-modal .pm-in"), "username input present");
  });

  // Ability quick-nav: the battle ability description shows the whole kit as a top strip.
  test("battle: ability view shows a quick-nav strip; clicking switches abilities", function () {
    function mkAb(bn, nm) { return { source_basename: bn, ability_name: nm, cost: { 0: 1 }, cooldown_remaining: 0 }; }
    function mkChar(pn, abs) { return { path_name: pn, hp: 100, max_hp: 100, dead: false, effects: [], abilities: abs || [] }; }
    var abs = [mkAb("tn1", "Rasengan"), mkAb("tn2", "Clone"), mkAb("tn3", "Sage"), mkAb("tn4", "Kurama")];
    var energy = { pool: { 0: 1, 1: 1, 2: 1, 3: 1 } };
    // enemy char path_name "res://tn" has no kit in ability_info, so the nav uses its 4 active skills
    H.resetState({ screen: "battle", snapshot: { sides: [
      { role: "p1", team: [mkChar("res://a"), mkChar("res://b"), mkChar("res://c")], energy: energy },
      { role: "p2", team: [mkChar("res://tn", abs), mkChar("res://y"), mkChar("res://z")], energy: energy } ], acting_role: "p1" },
      match: { canonical_role: 0, opponent: {} }, described: { mode: "ability", char_idx: 3, ability_idx: 0, ability: abs[0] } });
    render();
    var tiles = document.querySelectorAll(".descpanel .desc-nav .desc-nav-skill");
    eq(tiles.length, 4, "nav strip shows the whole kit");
    eq(document.querySelectorAll(".desc-nav-skill.sel").length, 1, "current ability highlighted");
    tiles[2].dispatchEvent(new Event("click", { bubbles: true }));
    eq(S.described.ability_idx, 2, "clicking a nav tile switches the described ability");
  });

  // Mobile battle viewport: zoom the 1200px design to CONTAIN the screen (min of the width- and
  // height-fit, against the measured board height) as the initial + minimum scale — the WHOLE board
  // is visible by default and can't zoom out below it, but pinch-IN is allowed.
  test("viewport: battle viewport is width-constrained in portrait", function () {
    var c = fns.battleViewportContent(375, 812, 732);   // portrait phone, board 732px tall
    assert(/width=1200/.test(c), "renders the 1200 design width");
    assert(/initial-scale=0\.3125/.test(c), "initial scale = 375/1200 (portrait fits to width, the tighter axis)");
    assert(/minimum-scale=0\.3125/.test(c), "minimum scale = fit (can't zoom out below the full scene)");
    assert(/maximum-scale=5/.test(c) && /user-scalable=yes/.test(c), "zoom-in allowed");
  });

  test("viewport: battle viewport fits the board HEIGHT when height-constrained (landscape)", function () {
    var c = fns.battleViewportContent(812, 375, 732);   // landscape phone; height is the tighter axis
    assert(/initial-scale=0\.5122/.test(c) && /minimum-scale=0\.5122/.test(c), "scale = floor(375/732) so the whole board HEIGHT fits (sides letterbox)");
    var tall = fns.battleViewportContent(812, 375, 902);   // staged action + open description -> taller board
    assert(/initial-scale=0\.4157/.test(tall), "a taller board zooms out further (375/902) to stay fully visible");
  });

  test("viewport: fit scale is clamped to 1 on screens larger than the design", function () {
    var c = fns.battleViewportContent(1400, 1000, 700);
    assert(/initial-scale=1(\D|$)/.test(c) && /minimum-scale=1(\D|$)/.test(c), "scale clamped to 1 (never upscales the design)");
  });

  // Buying a bounty square: set its progress to the mission goal, debit 1500 AP, persist.
  function _missions25(goal) { var m = []; for (var i = 0; i < 25; i++) m.push(["with", ["ninja"], goal]); return m; }
  test("bounty: buying a square completes it, debits 1500 AP, and saves", function () {
    H.resetState({ player: { ap: 5000, active_bounties: { naruto: new Array(25).fill(0) } }, bountyMissions: { naruto: _missions25(3) } });
    fns.buyBountySquare("naruto", 4);
    eq(S.player.active_bounties.naruto[4], 3, "square 4 set to its goal");
    eq(S.player.ap, 3500, "1500 AP debited");
    var saves = H.sentOfType("save_cosmetics");
    assert(saves.length >= 1, "persisted via save_cosmetics");
    eq(saves[saves.length - 1].payload.update.active_bounties.naruto[4], 3, "saved blob carries the completed square");
  });

  // The price rose 1000 -> 1500, so this band is the regression that matters: it used to be enough.
  test("bounty: 1400 AP is NOT enough to buy a square at the 1500 price", function () {
    H.resetState({ player: { ap: 1400, active_bounties: { naruto: new Array(25).fill(0) } }, bountyMissions: { naruto: _missions25(3) } });
    fns.buyBountySquare("naruto", 2);
    eq(S.player.active_bounties.naruto[2], 0, "square unchanged");
    eq(S.player.ap, 1400, "no AP spent");
    eq(S.msgKind, "err", "shows an error");
  });

  // ---------------------------------------------------------------------------
  // Ladder post-game: rating movement + the division-change callout
  // ---------------------------------------------------------------------------
  // A ladder match is identified by match.ranked, NOT by the label: the label is "Ladder Match", so
  // the old /ranked/i.test(kind) gate was always false and every ranked-only branch was dead.
  function _ladder(extra) {
    return Object.assign({ kind: "Ladder Match", ranked: true, apBefore: 0, canonical_role: 0 }, extra || {});
  }
  test("ladder: the ranked gate keys on the flag, not the display label", function () {
    H.resetState({ match: _ladder() });
    assert(fns.isRankedMatch(), "match.ranked drives it");
    assert(!/ranked/i.test("Ladder Match"), "...which the old label test could never have matched");
    H.resetState({ match: { kind: "Quick Match", ranked: false } });
    assert(!fns.isRankedMatch(), "a quick match is not ranked");
  });

  test("ladder: AP gain is scored for a ladder match (was null via the dead label gate)", function () {
    H.resetState({ match: _ladder({ vsBot: false }) });
    eq(fns.matchApGain(true), 500, "500 AP for a ladder win over a human");
    eq(fns.matchApGain(false), 50, "50 AP for a ladder loss");
    H.resetState({ match: _ladder({ vsBot: true }) });
    eq(fns.matchApGain(true), 250, "250 AP when the opponent was the queue's bot");
  });

  test("ladder: the post-game panel shows the rating delta and the new rating", function () {
    H.resetState({ match: _ladder(), matchResult: { won: true, apGain: 500 },
      rankedResult: { won: true, delta: 27, rating_before: 1180, rating_after: 1207,
                      rank_before: 2, tier_before: 4, rank_after: 3, tier_after: 1,
                      promoted: true, demoted: false, rank_changed: true } });
    var node = fns.gameOverModal();
    var cell = node.querySelector(".go-rating");
    assert(cell, "rating cell present");
    eq(cell.textContent, "+27 → 1207", "signed delta and the resulting rating");
    assert(/up/.test(cell.className), "styled as a gain");
  });

  test("ladder: a rating LOSS renders signed and styled down", function () {
    H.resetState({ match: _ladder(), matchResult: { won: false, apGain: 50 },
      rankedResult: { won: false, delta: -31, rating_before: 1207, rating_after: 1176,
                      rank_before: 3, tier_before: 1, rank_after: 2, tier_after: 4,
                      promoted: false, demoted: true, rank_changed: true } });
    var cell = fns.gameOverModal().querySelector(".go-rating");
    eq(cell.textContent, "-31 → 1176", "negative delta keeps its own sign");
    assert(/down/.test(cell.className), "styled as a loss");
  });

  test("ladder: crossing a rank shows the RANK UP callout with both divisions", function () {
    H.resetState({ match: _ladder(), matchResult: { won: true, apGain: 500 },
      rankedResult: { delta: 27, rating_after: 1207, rank_before: 2, tier_before: 4,
                      rank_after: 3, tier_after: 1, promoted: true, demoted: false, rank_changed: true } });
    var banner = fns.divisionChangeBanner();
    assert(banner, "callout rendered");
    assert(/RANK UP/.test(banner.textContent), "rank crossing gets the louder headline");
    eq(banner.querySelector(".go-div-from").textContent, "Silver 4", "from Silver 4");
    eq(banner.querySelector(".go-div-to").textContent, "Gold 1", "to Gold 1");
    assert(/major/.test(banner.className), "a whole-rank move is marked major");
  });

  test("ladder: a division-only promotion is NOT marked major", function () {
    H.resetState({ match: _ladder(), matchResult: { won: true },
      rankedResult: { delta: 18, rank_before: 3, tier_before: 1, rank_after: 3, tier_after: 2,
                      promoted: true, demoted: false, rank_changed: false } });
    var banner = fns.divisionChangeBanner();
    assert(/Promoted/.test(banner.textContent), "promoted headline");
    assert(!/major/.test(banner.className), "same rank -> not major");
    eq(banner.querySelector(".go-div-to").textContent, "Gold 2", "Gold 1 -> Gold 2");
  });

  test("ladder: a demotion renders the down callout", function () {
    H.resetState({ match: _ladder(), matchResult: { won: false },
      rankedResult: { delta: -22, rank_before: 3, tier_before: 2, rank_after: 3, tier_after: 1,
                      promoted: false, demoted: true, rank_changed: false } });
    var banner = fns.divisionChangeBanner();
    assert(/Demoted/.test(banner.textContent), "demoted headline");
    assert(/down/.test(banner.className), "styled down");
  });

  test("ladder: NO callout when the match did not cross a division line", function () {
    H.resetState({ match: _ladder(), matchResult: { won: true },
      rankedResult: { delta: 12, rank_before: 3, tier_before: 2, rank_after: 3, tier_after: 2,
                      promoted: false, demoted: false, rank_changed: false } });
    eq(fns.divisionChangeBanner(), null, "an ordinary ladder game shows nothing");
  });

  test("ladder: ranked rows never appear on a non-ladder match", function () {
    H.resetState({ match: { kind: "Quick Match", ranked: false, apBefore: 0, canonical_role: 0 },
      matchResult: { won: true, apGain: 100 },
      rankedResult: { delta: 27, rank_before: 2, tier_before: 4, rank_after: 3, tier_after: 1, promoted: true } });
    var node = fns.gameOverModal();
    eq(node.querySelector(".go-rating"), null, "no rating row on a quick match");
    eq(fns.divisionChangeBanner(), null, "no division callout either");
  });

  test("ladder: every rank maps to badge art, with masters art reused for Grandmaster", function () {
    // The shipped files are "<rank> small.png"; there is no grandmaster art, so Master and
    // Grandmaster both use "masters small.png" (Rank.rank_emblem makes the same substitution).
    var expect = ["iron", "bronze", "silver", "gold", "platinum", "diamond", "masters", "masters"];
    for (var r = 0; r < expect.length; r++) {
      var img = fns.rankBadge(r);
      assert(img, "rank " + r + " produced an image");
      // The element starts on the preferred "<rank> badge.png"; the shipped fallback is what the
      // onerror chain swaps in. Assert the FALLBACK filename is the one that exists on disk.
      var fired = false;
      img.dispatchEvent(new Event("error"));
      fired = img.dataset.fellBack === "1";
      assert(fired, "rank " + r + " falls back when the preferred badge art is absent");
      assert(decodeURIComponent(img.getAttribute("src")).indexOf(expect[r] + " small.png") !== -1,
        "rank " + r + " falls back to '" + expect[r] + " small.png'");
    }
  });

  test("ladder: a second failure removes the badge instead of leaving a broken image", function () {
    var img = fns.rankBadge(0);
    img.dispatchEvent(new Event("error"));   // preferred missing -> swap to the fallback
    eq(img.dataset.fellBack, "1", "marked as fallen back");
    document.body.appendChild(img);
    img.dispatchEvent(new Event("error"));   // fallback missing too -> drop it
    eq(img.parentNode, null, "element removed rather than showing a broken-image icon");
  });

  test("ladder: an unknown rank index yields no badge", function () {
    eq(fns.rankBadge(99), null, "out-of-range rank produces nothing");
  });

  test("ladder: divisionName maps the rank index and division (1 = lowest)", function () {
    eq(fns.divisionName(0, 1), "Iron 1", "Iron 1 is the bottom of the ladder");
    eq(fns.divisionName(7, 4), "Grandmaster 4", "Grandmaster saturates at division 4");
  });

  test("bounty: buying a square is blocked without enough AP", function () {
    H.resetState({ player: { ap: 500, active_bounties: { naruto: new Array(25).fill(0) } }, bountyMissions: { naruto: _missions25(3) } });
    fns.buyBountySquare("naruto", 0);
    eq(S.player.active_bounties.naruto[0], 0, "square unchanged");
    eq(S.player.ap, 500, "no AP spent");
    eq(S.msgKind, "err", "shows an error");
  });

  test("bounty: buying an already-complete square spends nothing", function () {
    var prog = new Array(25).fill(0); prog[2] = 3;
    H.resetState({ player: { ap: 5000, active_bounties: { naruto: prog } }, bountyMissions: { naruto: _missions25(3) } });
    fns.buyBountySquare("naruto", 2);
    eq(S.player.ap, 5000, "no AP spent on an already-complete square");
  });

  test("bounty: mastery bounty squares cannot be bought with AP", function () {
    H.resetState({ player: { ap: 5000, active_bounties: { naruto_mastery: new Array(25).fill(0) } }, bountyMissions: { naruto_mastery: _missions25(3) } });
    fns.buyBountySquare("naruto_mastery", 4);
    eq(S.player.active_bounties.naruto_mastery[4], 0, "mastery square unchanged");
    eq(S.player.ap, 5000, "no AP spent on a mastery bounty");
    eq(S.msgKind, "err", "shows the mastery-only-play message");
  });

  // Password change: sends current+new; on success updates the in-memory + saved-login credentials
  // so reconnect / "keep me logged in" keep working; on failure surfaces the server message.
  test("settings: changePassword sends the current and new password", function () {
    H.resetState({ player: { username: "x" }, username: "x" });
    fns.changePassword("old", "newpass");
    var sent = H.sentOfType("change_password");
    assert(sent.length >= 1, "a change_password frame was sent");
    eq(sent[sent.length - 1].payload.current, "old", "current password sent");
    eq(sent[sent.length - 1].payload.new, "newpass", "new password sent");
  });

  test("settings: successful password change updates stored + saved credentials", function () {
    try { localStorage.setItem("aa_login", JSON.stringify({ user: "x", pass: "old" })); } catch (e) {}
    H.resetState({ player: { username: "x" }, username: "x", creds: { url: "ws://x", user: "x", pass: "old" }, _pwChange: { newPass: "newpass" } });
    H.emit("receive_change_password_response", { ok: true, message: "Password updated." });
    eq(S.creds.pass, "newpass", "in-memory reconnect creds updated");
    var saved = null; try { saved = JSON.parse(localStorage.getItem("aa_login") || "null"); } catch (e) {}
    eq(saved && saved.pass, "newpass", "saved-login password updated");
    eq(S.msgKind, "ok", "success message");
    try { localStorage.removeItem("aa_login"); } catch (e) {}
  });

  test("settings: failed password change surfaces the message and leaves creds untouched", function () {
    H.resetState({ player: { username: "x" }, username: "x", creds: { url: "ws://x", user: "x", pass: "old" }, _pwChange: { newPass: "newpass" } });
    H.emit("receive_change_password_response", { ok: false, message: "Current password is incorrect." });
    eq(S.creds.pass, "old", "creds unchanged on failure");
    eq(S.msg, "Current password is incorrect.", "server message shown");
    eq(S.msgKind, "err", "error kind");
  });

  // Two-click grid selection: first click focuses (shows info), second click on the focused char
  // adds/removes it from the team.
  test("select: first grid click focuses the character, no team change", function () {
    H.resetState({ roster: [{ path_name: "a", name: "A" }], player: null, team: [], menuInspect: null });
    fns.selectAndInspect("a");
    eq(S.menuInspect && S.menuInspect.path_name, "a", "character focused / info shown");
    deepEq(S.team, [], "team unchanged on the first click");
  });

  test("select: second click on the focused character adds it; a third removes it", function () {
    H.resetState({ roster: [{ path_name: "a", name: "A" }], player: null, team: [], menuInspect: { path_name: "a", mode: "character" } });
    fns.selectAndInspect("a");
    deepEq(S.team, ["a"], "second click adds");
    fns.selectAndInspect("a");
    deepEq(S.team, [], "third click removes");
  });

  test("select: clicking a different character only refocuses (no add)", function () {
    H.resetState({ roster: [{ path_name: "a", name: "A" }, { path_name: "b", name: "B" }], player: null, team: [], menuInspect: { path_name: "a", mode: "character" } });
    fns.selectAndInspect("b");
    eq(S.menuInspect.path_name, "b", "refocused to b");
    deepEq(S.team, [], "no team change");
  });

  test("select: toggleTeamMember respects the 3-character cap", function () {
    H.resetState({ roster: [{ path_name: "a" }, { path_name: "b" }, { path_name: "c" }, { path_name: "d" }], player: null, team: ["a", "b", "c"] });
    fns.toggleTeamMember("d");
    deepEq(S.team, ["a", "b", "c"], "cannot add a 4th");
    eq(S.msgKind, "err", "shows the full-team error");
  });

  test("select: a locked character can be focused (info shown) but not added", function () {
    H.resetState({ roster: [{ path_name: "lk", name: "Locked", gate: "x_unlock" }], player: { unlocks: [] }, team: [], menuInspect: null });
    fns.selectAndInspect("lk");
    eq(S.menuInspect && S.menuInspect.path_name, "lk", "locked char focused — info shown");
    deepEq(S.team, [], "not added on the focus click");
    fns.selectAndInspect("lk");   // second click tries to add
    deepEq(S.team, [], "still not added — character is locked");
    eq(S.msgKind, "err", "shows the unlock-required message");
  });

  test("roster: previously-missing character bios are populated", function () {
    H.resetState({});
    ["hibari", "lizandpatty", "yubel", "seventeen", "uranus", "cooler", "kurotsuchi", "broly", "cell", "mercury", "venus", "jaden", "jesse", "rakko", "toudou", "tamaki", "ace"].forEach(function (pn) {
      var c = (S.roster || []).find(function (r) { return r.path_name === pn; });
      assert(c && c.bio && c.bio.length > 20, pn + " has a non-empty bio");
    });
  });

  test("teams: save, load, overwrite, and delete a named team", function () {
    try { localStorage.removeItem("aa_teams_tester"); } catch (e) {}
    H.resetState({ username: "tester", player: null, roster: [{ path_name: "a" }, { path_name: "b" }, { path_name: "c" }], team: ["a", "b", "c"] });
    fns.saveCurrentTeam("Rush");
    var list = fns.loadSavedTeamsList();
    eq(list.length, 1, "one saved team");
    eq(list[0].name, "Rush", "name stored");
    S.team = [];
    fns.loadSavedTeam(0);
    deepEq(S.team, ["a", "b", "c"], "loading restores the saved roster");
    fns.saveCurrentTeam("Rush");   // same name -> overwrite
    eq(fns.loadSavedTeamsList().length, 1, "resaving the same name does not duplicate");
    fns.deleteSavedTeam(0);
    eq(fns.loadSavedTeamsList().length, 0, "deleted");
  });

  // ---------------------------------------------------------------------------
  // receive_quick/ranked/private_match incoming frames -> match.kind label
  // ---------------------------------------------------------------------------
  test("session: receive_quick_match sets kind 'Quick Match'", function () {
    H.resetState({ player: { ap: 100 } });
    H.emit("receive_quick_match", { opponent: { username: "Q" }, first_turn: false, seed: 1, canonical_role: 1 });
    eq(S.screen, "battle", "battle");
    eq(S.match.kind, "Quick Match", "quick kind");
    eq(S.match.apBefore, 100, "apBefore from player");
  });

  test("session: receive_ranked_match sets kind 'Ladder Match'", function () {
    H.resetState({ player: { ap: 100 } });
    H.emit("receive_ranked_match", { opponent: {}, canonical_role: 0 });
    eq(S.match.kind, "Ladder Match", "ranked kind");
  });

  test("session: receive_private_match sets kind 'Private Match'", function () {
    H.resetState({ player: { ap: 100 } });
    H.emit("receive_private_match", { opponent: {}, canonical_role: 0 });
    eq(S.match.kind, "Private Match", "private kind");
  });

  // ---------------------------------------------------------------------------
  // receive_player_update — plain merge (no active matchResult) vs apGain compute
  // ---------------------------------------------------------------------------
  test("session: receive_player_update with no active matchResult just merges player", function () {
    H.resetState({ player: { username: "X", ap: 100 }, match: null, matchResult: null });
    H.emit("receive_player_update", { json_string: JSON.stringify({ username: "X", ap: 250, wins: 5 }) });
    eq(S.player.ap, 250, "ap merged");
    eq(S.player.wins, 5, "wins merged");
    eq(S.matchResult, null, "no matchResult created");
  });

  test("session: receive_player_update accepts an already-parsed object", function () {
    H.resetState({ player: { ap: 1 } });
    H.emit("receive_player_update", { json_string: { ap: 999 } });
    eq(S.player.ap, 999, "object form merged");
  });

  test("session: player_update WITH matchResult+match computes apGain = newAp - apBefore", function () {
    H.resetState({ player: { ap: 1000 }, match: { kind: "Quick Match", apBefore: 1000, canonical_role: 0 }, matchResult: { won: true } });
    H.emit("receive_player_update", { json_string: JSON.stringify({ ap: 1150 }) });
    eq(S.player.ap, 1150, "player updated");
    eq(S.matchResult.apGain, 150, "apGain = 1150 - 1000");
    eq(S.matchResult.won, true, "won preserved through the merge");
  });

  test("session: apGain uses match.apBefore, not the live (already-updated) player.ap", function () {
    // apBefore snapshots match-start AP; live player.ap may differ — gain must key off apBefore.
    H.resetState({ player: { ap: 5000 }, match: { apBefore: 4000, canonical_role: 0 }, matchResult: { won: false } });
    H.emit("receive_player_update", { json_string: JSON.stringify({ ap: 3950 }) });
    eq(S.matchResult.apGain, -50, "apGain = 3950 - 4000 (loss)");
    eq(S.matchResult.won, false, "loss flag preserved");
  });

  test("session: apGain falls back to player.ap when match.apBefore is absent", function () {
    H.resetState({ player: { ap: 700 }, match: { canonical_role: 0 }, matchResult: { won: true } });
    H.emit("receive_player_update", { json_string: JSON.stringify({ ap: 800 }) });
    eq(S.matchResult.apGain, 100, "apGain = 800 - 700 (no apBefore -> uses player.ap)");
  });

  // ---------------------------------------------------------------------------
  // IDEMPOTENCY — apGain computed once, second update does not recompute
  // ---------------------------------------------------------------------------
  test("session: second player_update does NOT recompute apGain (set once)", function () {
    H.resetState({ player: { ap: 1000 }, match: { apBefore: 1000, canonical_role: 0 }, matchResult: { won: true } });
    H.emit("receive_player_update", { json_string: JSON.stringify({ ap: 1150 }) });
    eq(S.matchResult.apGain, 150, "first compute");
    // A later refresh (e.g. mastery xp landing) must not blow away the recorded gain.
    H.emit("receive_player_update", { json_string: JSON.stringify({ ap: 1300 }) });
    eq(S.player.ap, 1300, "player still merges");
    eq(S.matchResult.apGain, 150, "apGain stays at the first delta (not recomputed)");
  });

  test("session: onMatch is stable when re-issued (apBefore re-snapshots current ap)", function () {
    H.resetState({ player: { ap: 2000 } });
    fns.onMatch({ opponent: {}, canonical_role: 0 }, "Quick Match");
    var first = S.match.apBefore;
    fns.onMatch({ opponent: {}, canonical_role: 0 }, "Quick Match");
    eq(S.match.apBefore, first, "re-issue with unchanged player.ap yields the same apBefore");
    eq(S.match.kind, "Quick Match", "kind stable");
    eq(S.screen, "battle", "still battle");
  });

  // ---------------------------------------------------------------------------
  // bounty_missions — caches under its key
  // ---------------------------------------------------------------------------
  test("session: bounty_missions caches S.bountyMissions[key]", function () {
    H.resetState({ bountyMissions: {} });
    var ms = [{ a: 1 }, { b: 2 }];
    H.emit("bounty_missions", { key: "naruto", missions: ms });
    assert(S.bountyMissions.naruto, "key present");
    deepEq(S.bountyMissions.naruto, ms, "missions cached verbatim");
  });

  test("session: bounty_missions with missing missions caches []", function () {
    H.resetState({ bountyMissions: {} });
    H.emit("bounty_missions", { key: "gon" });
    deepEq(S.bountyMissions.gon, [], "defaults to empty list");
  });

  test("session: bounty_missions re-emit overwrites same key (idempotent cache slot)", function () {
    H.resetState({ bountyMissions: {} });
    H.emit("bounty_missions", { key: "luffy", missions: [{ x: 1 }] });
    H.emit("bounty_missions", { key: "luffy", missions: [{ x: 1 }] });
    eq(Object.keys(S.bountyMissions).length, 1, "single key");
    deepEq(S.bountyMissions.luffy, [{ x: 1 }], "value stable on re-emit");
  });

  // ---------------------------------------------------------------------------
  // opponent disconnect / reconnect toggles oppGone
  // ---------------------------------------------------------------------------
  test("session: opponent disconnect/reconnect notifications toggle oppGone", function () {
    H.resetState({ oppGone: false });
    H.emit("receive_opponent_disconnect_notification", {});
    eq(S.oppGone, true, "oppGone set on disconnect");
    H.emit("receive_opponent_reconnect_notification", {});
    eq(S.oppGone, false, "oppGone cleared on reconnect");
  });

  // ---------------------------------------------------------------------------
  // receive_session_reconnect — resumes battle (valid snapshot) or menu (no match)
  // ---------------------------------------------------------------------------
  test("session: receive_session_reconnect resumes battle with a live snapshot", function () {
    H.resetState({ reconnecting: true, screen: "login", player: { username: "Me" } });
    var snap = {
      current_turn: 1, acting_role: "p1", match_over: false,
      sides: [{ role: "p1", username: "Me", team: [] }, { role: "p2", username: "Foe", team: [] }],
    };
    noThrow(function () {
      H.emit("receive_session_reconnect", { info: { snapshot: snap, enemy: { username: "Foe" }, canonical_role: 0 } });
    }, "reconnect-to-battle render");
    eq(S.screen, "battle", "screen -> battle");
    eq(S.reconnecting, false, "reconnecting cleared");
    eq(S.matchResult, null, "match not over -> no result");
    deepEq(S.match.opponent, { username: "Foe" }, "enemy carried into match.opponent");
  });

  test("session: receive_session_reconnect with no sides -> menu (match ended)", function () {
    H.resetState({ reconnecting: true, screen: "login", match: { kind: "x" }, snapshot: { stale: 1 } });
    noThrow(function () {
      H.emit("receive_session_reconnect", { info: { snapshot: { current_turn: 1 } } });
    }, "reconnect-to-menu render");
    eq(S.screen, "menu", "screen -> menu");
    eq(S.match, null, "match cleared");
    eq(S.snapshot, null, "snapshot cleared");
    eq(S.reconnecting, false, "reconnecting cleared");
  });

  test("session: receive_session_reconnect with match_over snapshot sets won:null", function () {
    H.resetState({ reconnecting: true, player: {} });
    var snap = { current_turn: 2, acting_role: "p1", match_over: true, sides: [{ role: "p1", team: [] }, { role: "p2", team: [] }] };
    noThrow(function () {
      H.emit("receive_session_reconnect", { info: { snapshot: snap, canonical_role: 0 } });
    }, "reconnect match-over render");
    eq(S.screen, "battle", "battle screen (over)");
    assert(S.matchResult && S.matchResult.won === null, "matchResult.won === null on match_over");
  });

  // ---------------------------------------------------------------------------
  // finishReconnect — applies patch and always clears reconnecting
  // ---------------------------------------------------------------------------
  test("session: finishReconnect clears reconnecting and applies the patch", function () {
    H.resetState({ reconnecting: true, screen: "battle" });
    fns.finishReconnect({ screen: "menu", msg: "Reconnected", msgKind: "ok" });
    eq(S.reconnecting, false, "reconnecting cleared");
    eq(S.screen, "menu", "screen patched");
    eq(S.msg, "Reconnected", "msg patched");
  });

  // ---------------------------------------------------------------------------
  // returnToMenu — clears match/snapshot/matchResult/etc. (reached via game-over button)
  // ---------------------------------------------------------------------------
  test("session: returnToMenu (game-over button) resets match/snapshot/matchResult", function () {
    H.resetState({
      screen: "battle",
      match: { kind: "Quick Match", apBefore: 100, canonical_role: 0 },
      snapshot: { sides: [] },
      matchResult: { won: true, apGain: 50 },
      staged: [{ char_idx: 0 }], oppGone: true, queued: true, confirmSurrender: true,
    });
    var modal = fns.gameOverModal();
    var btn = modal.querySelector(".go-btn");
    assert(btn, "game-over modal has a Return-to-Menu button");
    noThrow(function () { btn.click(); }, "returnToMenu via click");
    eq(S.screen, "menu", "screen -> menu");
    eq(S.match, null, "match cleared");
    eq(S.snapshot, null, "snapshot cleared");
    eq(S.matchResult, null, "matchResult cleared");
    deepEq(S.staged, [], "staged cleared");
    eq(S.oppGone, false, "oppGone cleared");
    eq(S.queued, false, "queued cleared");
    eq(S.confirmSurrender, false, "surrender confirm cleared");
  });

  // ---------------------------------------------------------------------------
  // gameOverModal — apGain rendering: '…' until known, signed once known
  // ---------------------------------------------------------------------------
  test("session: gameOverModal shows '…' for AP gain until it is computed", function () {
    H.resetState({ match: { kind: "Quick Match", apBefore: 0, canonical_role: 0 }, matchResult: { won: true } });
    var node = noThrow(function () { return fns.gameOverModal(); }, "render pending modal");
    var apCell = node.querySelector(".go-ap");
    assert(apCell, "AP cell present");
    eq(apCell.textContent, "…", "shows ellipsis when apGain == null");
  });

  test("session: gameOverModal renders signed AP gain once known", function () {
    H.resetState({ match: { kind: "Ranked Match", apBefore: 0, canonical_role: 0 }, matchResult: { won: true, apGain: 75 } });
    var node = noThrow(function () { return fns.gameOverModal(); }, "render gain modal");
    eq(node.querySelector(".go-ap").textContent, "+75", "positive gain prefixed with +");
    H.resetState({ match: { kind: "Ranked Match", canonical_role: 0 }, matchResult: { won: false, apGain: -30 } });
    var node2 = fns.gameOverModal();
    eq(node2.querySelector(".go-ap").textContent, "-30", "negative gain keeps its sign");
  });

  // ---------------------------------------------------------------------------
  // RESILIENCE — malformed / unknown / partial frames must not throw or corrupt
  // ---------------------------------------------------------------------------
  test("session: malformed player_update json ('{bad') does not throw or corrupt", function () {
    H.resetState({ player: { username: "Keep", ap: 321 } });
    noThrow(function () { H.emit("receive_player_update", { json_string: "{bad" }); }, "bad json");
    eq(S.player.ap, 321, "player untouched");
    eq(S.player.username, "Keep", "player intact");
    noThrow(function () { render(); }, "render after bad frame");
  });

  test("session: player_update with null json_string leaves player unchanged", function () {
    H.resetState({ player: { ap: 42 } });
    noThrow(function () { H.emit("receive_player_update", { json_string: null }); }, "null json");
    eq(S.player.ap, 42, "no overwrite from null payload");
  });

  test("session: an unknown message type does not throw or change state", function () {
    H.resetState({ player: { ap: 9 }, screen: "menu" });
    var before = JSON.stringify(S.player);
    noThrow(function () { H.emit("totally_unknown_type", { foo: "bar" }); }, "unknown type");
    eq(JSON.stringify(S.player), before, "player unchanged");
    eq(S.screen, "menu", "screen unchanged");
  });

  test("session: bounty_missions with no key does not throw or add a slot", function () {
    H.resetState({ bountyMissions: {} });
    noThrow(function () { H.emit("bounty_missions", { missions: [{ a: 1 }] }); }, "no-key frame");
    eq(Object.keys(S.bountyMissions).length, 0, "cache untouched (handler requires m.key)");
  });

  test("session: nexus_state with empty payload does not throw; buckets reset to {}", function () {
    H.resetState({ nexusBuckets: { naruto: 5 }, nexusMax: 99 });
    noThrow(function () { H.emit("nexus_state", {}); }, "empty nexus_state");
    deepEq(S.nexusBuckets, {}, "no sets -> empty buckets");
    eq(S.nexusMax, 1, "max floors at 1");
  });

  // ---------------------------------------------------------------------------
  // set + render idempotency
  // ---------------------------------------------------------------------------
  test("session: set({}) then render twice is stable (idempotent #app innerHTML)", function () {
    H.resetState({ screen: "login", username: "stable" });
    render();
    var a = appHtml();
    noThrow(function () { render(); }, "second render");
    var b = appHtml();
    eq(a, b, "two renders of the same state produce identical #app innerHTML");
  });

  test("session: emitting a benign frame re-renders without corrupting #app", function () {
    H.resetState({ screen: "menu", player: { username: "M", ap: 10 } });
    render();
    noThrow(function () { H.emit("receive_opponent_reconnect_notification", {}); }, "benign emit render");
    var app = document.getElementById("app");
    assert(app && app.querySelector(".screen"), "a screen is still mounted");
  });
})();

// ============================================================================
// AREA: render resilience + idempotency across all menu/meta screens
// ============================================================================
(function () {
  "use strict";
  var H = window.AATest, fns = H.fns, C = H.consts, S = H.S, render = H.render;
  var test = H.test, assert = H.assert, eq = H.eq, deepEq = H.deepEq, near = H.near, noThrow = H.noThrow, throws = H.throws;

  function app() { return document.getElementById("app"); }
  // render twice, return [html1, html2] for idempotency comparison
  function renderTwice() {
    render();
    var a = app().innerHTML;
    render();
    var b = app().innerHTML;
    return [a, b];
  }

  // ---- per-renderer resilience: clean empty player, null player, partial player ----
  var MENU_RENDERERS = ["menuInfoPanel", "playerPanel", "gameOverModal", "masteryMenu", "masteryDetail",
    "cosmeticsMenu", "nexusMenu", "bountiesMenu", "titleMenu", "shopMenu", "ladderMenu", "settingsMenu", "categoryModal"];

  MENU_RENDERERS.forEach(function (name) {
    test("render: " + name + " returns a node + no throw with empty player {}", function () {
      H.resetState({ player: {} });
      var node;
      noThrow(function () { node = name === "masteryDetail" ? fns[name]("naruto") : fns[name](); }, name + " threw on empty player");
      assert(node && node.nodeType === 1, name + " should return an element node");
    });

    test("render: " + name + " no throw with player=null", function () {
      H.resetState({ player: null });
      noThrow(function () { name === "masteryDetail" ? fns[name]("naruto") : fns[name](); }, name + " threw on null player");
    });

    test("render: " + name + " no throw with partial player (username only)", function () {
      H.resetState({ player: { username: "Tester" } });
      noThrow(function () { name === "masteryDetail" ? fns[name]("naruto") : fns[name](); }, name + " threw on partial player");
    });
  });

  // ---- gameOverModal: banner + rows + Return button across matchResult/apGain combos ----
  test("render: gameOverModal won=true renders Victory banner + Return button", function () {
    H.resetState({ matchResult: { won: true, apGain: 120 }, match: { kind: "Quick Match" } });
    var node = fns.gameOverModal();
    var banner = node.querySelector(".go-banner");
    assert(banner && /Victory/.test(banner.textContent), "expected Victory banner");
    var btn = node.querySelector(".go-btn");
    assert(btn && btn.tagName === "BUTTON", "expected a Return button");
    assert(/Return/.test(btn.textContent), "Return button text");
    var ap = node.querySelector(".go-ap");
    eq(ap.textContent, "+120", "apGain 120 -> +120");
    // match type row present when S.match.kind set
    assert(/Quick Match/.test(node.textContent), "match type row should show kind");
  });

  test("render: gameOverModal won=false renders Defeat banner", function () {
    H.resetState({ matchResult: { won: false, apGain: -30 }, match: { kind: "Ranked Match" } });
    var node = fns.gameOverModal();
    var banner = node.querySelector(".go-banner");
    assert(/Defeat/.test(banner.textContent), "expected Defeat banner");
    eq(node.querySelector(".go-ap").textContent, "-30", "negative apGain renders with sign");
  });

  test("render: gameOverModal won=null + apGain null renders 'Match Over' + '…'", function () {
    H.resetState({ matchResult: { won: null, apGain: null }, match: null });
    var node = fns.gameOverModal();
    var banner = node.querySelector(".go-banner");
    assert(/Match Over/.test(banner.textContent), "won=null -> Match Over");
    eq(node.querySelector(".go-ap").textContent, "…", "apGain null -> ellipsis");
    // S.match null: no match-type row, but AP row + button still present
    assert(node.querySelector(".go-btn"), "Return button still present");
    var rows = node.querySelectorAll(".go-row");
    eq(rows.length, 1, "only the AP-gained row when S.match is null");
  });

  test("render: gameOverModal with completely empty matchResult={} no throw", function () {
    H.resetState({ matchResult: {} });
    var node;
    noThrow(function () { node = fns.gameOverModal(); }, "gameOverModal threw on {}");
    assert(/Match Over/.test(node.querySelector(".go-banner").textContent), "empty result -> Match Over");
  });

  // ---- playerPanel: avatar + details (pp-top) without throwing for missing fields ----
  test("render: playerPanel renders pp-top (avatar + details) with empty player", function () {
    H.resetState({ player: {} });
    var node = fns.playerPanel();
    assert(node.querySelector(".pp-top"), "pp-top row present");
    assert(node.querySelector(".pp-avatar"), "avatar block present");
    assert(node.querySelector(".pp-details"), "details block present");
    // name falls back to "Player" when nothing set
    assert(/Player/.test(node.querySelector(".pp-name").textContent), "name falls back to Player");
    // 3 team slots always rendered
    eq(node.querySelectorAll(".pt-slot").length, 3, "always 3 team slots");
  });

  test("render: playerPanel uses S.username fallback for name", function () {
    H.resetState({ player: null, username: "Hokage" });
    var node = fns.playerPanel();
    eq(node.querySelector(".pp-name").textContent, "Hokage", "name falls back to S.username");
    assert(/Clanless/.test(node.textContent), "clan defaults to Clanless");
  });

  // ---- menuInfoPanel character + ability mode ----
  test("render: menuInfoPanel empty (no inspect) -> .menu-info.empty", function () {
    H.resetState({ menuInspect: null });
    var node = fns.menuInfoPanel();
    assert(node.classList.contains("empty"), "no inspect -> empty panel");
  });

  test("render: menuInfoPanel character mode renders bio + skills", function () {
    H.resetState({ menuInspect: { path_name: "naruto", mode: "character" } });
    var node = fns.menuInfoPanel();
    assert(node.querySelector(".mi-bio"), "bio block present in character mode");
    assert(node.querySelectorAll(".mi-skill").length >= 1, "skill strip has entries (naruto has abilities)");
    assert(!node.classList.contains("empty"), "not the empty panel");
  });

  test("render: menuInfoPanel ability mode renders desc-header for naruto1", function () {
    H.resetState({ menuInspect: { path_name: "naruto", mode: "ability", basename: "naruto1" } });
    var node = fns.menuInfoPanel();
    assert(node.querySelector(".desc-header"), "ability mode renders desc-header");
    assert(node.querySelector(".desc-cd"), "cooldown line present");
  });

  test("render: menuInfoPanel ability mode no throw for unknown basename", function () {
    H.resetState({ menuInspect: { path_name: "naruto", mode: "ability", basename: "naruto_does_not_exist_999" } });
    var node;
    noThrow(function () { node = fns.menuInfoPanel(); }, "menuInfoPanel threw on unknown ability");
    assert(node.querySelector(".desc-header"), "still renders a header with fallback name");
  });

  // Regression: after clicking a skill (ability mode) the portrait must return the panel to the bio.
  // Previously the portrait had no handler, so the bio was unreachable once any ability was inspected.
  test("render: menuInfoPanel portrait click returns from ability mode to bio", function () {
    H.resetState({ menuInspect: { path_name: "naruto", mode: "ability", basename: "naruto1" } });
    var node = fns.menuInfoPanel();
    assert(!node.querySelector(".mi-bio"), "ability mode: no bio shown");
    var port = node.querySelector(".mi-portrait");
    assert(port, "portrait rendered in ability mode");
    port.click();
    assert(S.menuInspect && S.menuInspect.mode === "character", "portrait click -> character (bio) mode");
    eq(S.menuInspect.path_name, "naruto", "stays on the same character");
    assert(fns.menuInfoPanel().querySelector(".mi-bio"), "bio is reachable again after the click");
  });

  // render() preserves scroll position (BOTH axes) across its full DOM teardown, so selecting an
  // ability/skill tile no longer snaps horizontal strips back to the left. #app is narrowed to force
  // the .mi-skills strip to overflow regardless of harness width; the width is set on #app itself
  // (not a child), so it survives render()'s innerHTML wipe.
  test("scroll: horizontal strip position is preserved across a re-render (ability click)", function () {
    var app = document.getElementById("app");
    var prevW = app.style.width;
    app.style.width = "260px";
    try {
      H.resetState({ screen: "menu", player: { username: "T", unlocks: ["all_unlock"], mastery_xp: {} }, team: [], menuInspect: { path_name: "impmon", mode: "character" } });
      render();
      var strip = document.querySelector(".mi-skills");
      assert(strip, "ability strip rendered");
      assert(strip.scrollWidth > strip.clientWidth + 2, "precondition: strip overflows horizontally");
      strip.scrollLeft = strip.scrollWidth;            // scroll to the right end (browser clamps to max)
      var scrolled = strip.scrollLeft;
      assert(scrolled > 0, "precondition: strip is actually scrolled off the left");
      var tiles = strip.querySelectorAll(".mi-skill");
      tiles[tiles.length - 1].click();                 // selecting a skill triggers a full re-render
      var after = document.querySelector(".mi-skills");
      assert(after, "strip still present after re-render");
      assert(Math.abs(after.scrollLeft - scrolled) <= 2, "scrollLeft preserved (did NOT reset to the left)");
    } finally {
      app.style.width = prevW;
      render();
    }
  });

  // ---- full render() resilience for each screen ----
  test("render: full render() no throw on login screen (clean state)", function () {
    H.resetState({ screen: "login" });
    noThrow(function () { render(); }, "render threw on login");
    assert(app().querySelector(".screen"), "login screen rendered");
  });

  test("render: full render() no throw on menu screen with empty player", function () {
    H.resetState({ screen: "menu", player: {} });
    noThrow(function () { render(); }, "render threw on menu");
    assert(app().querySelector(".screen.menu"), "menu screen rendered");
  });

  // ---- IDEMPOTENCY: render() twice -> identical #app.innerHTML ----
  test("idempotency: login render() twice identical innerHTML", function () {
    H.resetState({ screen: "login" });
    var r = renderTwice();
    eq(r[0], r[1], "login render not idempotent");
  });

  test("idempotency: menu render() twice identical innerHTML", function () {
    H.resetState({ screen: "menu", player: { username: "T", ap: 5000 } });
    var r = renderTwice();
    eq(r[0], r[1], "menu render not idempotent");
  });

  // ---- IDEMPOTENCY: each menuOverlay value renders + is stable ----
  var OVERLAYS = ["mastery", "cosmetics", "nexus", "titles", "settings", "ladder", "bounties", "shop"];
  OVERLAYS.forEach(function (ov) {
    test("idempotency: menuOverlay='" + ov + "' render() twice no throw + identical", function () {
      H.resetState({ screen: "menu", menuOverlay: ov, player: { username: "T", ap: 5000, unlocks: [], active_bounties: {} } });
      var r;
      noThrow(function () { r = renderTwice(); }, "render threw for overlay " + ov);
      // modal actually mounted
      assert(app().querySelector(".modal-overlay") || app().querySelector(".modal-panel"), "overlay " + ov + " should mount a modal");
      eq(r[0], r[1], "overlay " + ov + " render not idempotent");
    });
  });

  test("idempotency: switching menuOverlay through all values does not throw", function () {
    OVERLAYS.forEach(function (ov) {
      H.resetState({ screen: "menu", menuOverlay: ov, player: { username: "T", ap: 100, unlocks: [], active_bounties: {} } });
      noThrow(function () { render(); }, "render threw switching to overlay " + ov);
    });
  });

  test("idempotency: menuOverlay with player=null still renders each overlay", function () {
    OVERLAYS.forEach(function (ov) {
      H.resetState({ screen: "menu", menuOverlay: ov, player: null });
      noThrow(function () { render(); }, "render threw for overlay " + ov + " with null player");
    });
  });

  // ---- settingsMenu specific: note when logged out, rows when logged in ----
  test("render: settingsMenu shows login note when player=null", function () {
    H.resetState({ player: null });
    var node = fns.settingsMenu();
    assert(node.classList.contains("note"), "logged-out settings is a .note");
    assert(/Log in/.test(node.textContent), "prompts to log in");
    assert(!node.querySelector(".set-row"), "no setting rows when logged out");
  });

  test("render: settingsMenu renders rows for empty player {} (treated as logged in)", function () {
    H.resetState({ player: {} });
    var node = fns.settingsMenu();
    assert(node.classList.contains("settings-menu"), "empty player {} -> settings-menu");
    assert(node.querySelectorAll(".set-row").length >= 4, "renders setting rows");
  });

  // ---- shopMenu renders with loaded catalog + default tab ----
  test("render: shopMenu renders shop-menu with default gamepanel tab", function () {
    H.resetState({ player: { ap: 10000, unlocks: [] } });
    var node = fns.shopMenu();
    assert(node.classList.contains("shop-menu"), "shop-menu rendered (catalog loaded in harness)");
    assert(node.querySelector(".shop-grid"), "shop grid present");
    assert(node.querySelectorAll(".shop-tab").length >= 1, "shop tabs present");
  });

  // ---- categoryModal renders real categories ----
  test("render: categoryModal renders category list + members (real bountyData)", function () {
    H.resetState({ catView: "ninja" });
    var node = fns.categoryModal();
    assert(node.querySelector(".cat-list"), "category list present");
    assert(node.querySelectorAll(".cat-list-row").length >= 1, "has category rows");
    assert(node.querySelector(".cat-members"), "members pane present");
  });

  test("render: categoryModal no throw with null catView (falls back to first)", function () {
    H.resetState({ catView: null });
    var node;
    noThrow(function () { node = fns.categoryModal(); }, "categoryModal threw with null catView");
    assert(node.querySelector(".cat-list-row"), "still lists categories");
  });

  // ---- a correctness spot-check on real data used by these renderers ----
  test("render: categoriesFor('naruto') is ['air','ninja'] (feeds menuInfoPanel cats)", function () {
    H.resetState({});
    deepEq(fns.categoriesFor("naruto"), ["air", "ninja"], "naruto categories");
  });

  test("render: bountyCompleted true when a winning pattern is fully met", function () {
    H.resetState({});
    // pattern [0,1,2,3,4] exists; craft missions/progress so those 5 cells meet goal
    var missions = [];
    for (var i = 0; i < 25; i++) missions.push(["with", ["naruto"], 1]);
    var progress = new Array(25).fill(0);
    [0, 1, 2, 3, 4].forEach(function (i) { progress[i] = 1; });
    eq(fns.bountyCompleted(progress, missions), true, "row 0 pattern completes the card");
    // and incomplete when one cell short
    progress[2] = 0;
    eq(fns.bountyCompleted(progress, missions), false, "missing a cell -> not complete");
  });

  test("render: bountyCompleted resilient to null progress/missions", function () {
    H.resetState({});
    noThrow(function () { fns.bountyCompleted(null, null); }, "bountyCompleted threw on null");
    eq(fns.bountyCompleted(null, null), false, "null -> false");
  });
})();
