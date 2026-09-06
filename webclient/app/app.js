// app.js — Anime Arena web client (v1): login -> queue -> render battle board.
// State + screens + render. Turn SUBMISSION is the next increment (board is
// read-only for now). Uses AANet from net.js.

(function () {
  "use strict";

  // ---- helpers -------------------------------------------------------------
  const $ = (sel, root) => (root || document).querySelector(sel);
  function el(tag, attrs, children) {
    const n = document.createElement(tag);
    if (attrs) for (const k in attrs) {
      if (attrs[k] == null || attrs[k] === false) continue;
      if (k === "class") n.className = attrs[k];
      else if (k === "html") n.innerHTML = attrs[k];
      else if (k.startsWith("on")) n.addEventListener(k.slice(2), attrs[k]);
      else n.setAttribute(k, attrs[k]);
    }
    (children || []).forEach((c) => { if (c == null || c === false) return; n.appendChild(typeof c === "string" ? document.createTextNode(c) : c); });
    return n;
  }
  const titleCase = (s) => (s || "").replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
  const DATA_BUST = "?v=" + Date.now();   // cache-bust the JSON manifests (fetch() isn't covered by index.html's bust)
  const CAMPAIGN_ENABLED = false;   // campaign mode is locked/hidden until it's finished — flip to true to re-enable
  // A DEV origin is localhost / a private-LAN IP / *.local — i.e. never the public production
  // domain. The gateway override below is honored ONLY on dev origins, so a crafted ?ws= link can
  // never redirect a real production login to a hostile server.
  function isDevOrigin(h) {
    return h === "" || h === "localhost" || h === "127.0.0.1"
      || /^192\.168\./.test(h) || /^10\./.test(h)
      || /^172\.(1[6-9]|2[0-9]|3[01])\./.test(h) || /\.local$/.test(h);
  }
  // Gateway URL. Production always uses the hosted wss. On a dev origin (no login-screen server
  // field), the gateway is, in order: window.AA_WS, a ?ws=<url> query param (persisted for the
  // browser, ?ws=reset clears it), a saved localStorage 'aa_ws', else the SAME host that served
  // the page on gateway port 5695 — so `godot --headless` on this machine just works, and a phone
  // on the LAN can point at the PC's IP automatically.
  function defaultServerUrl() {
    if (typeof window !== "undefined" && window.AA_WS) return window.AA_WS;
    const h = (typeof location !== "undefined" && location.hostname) || "";
    if (isDevOrigin(h)) {
      try {
        const qs = new URLSearchParams(location.search).get("ws");
        if (qs !== null) {
          if (qs === "" || qs === "reset") localStorage.removeItem("aa_ws");
          else { localStorage.setItem("aa_ws", qs); return qs; }
        }
        const saved = localStorage.getItem("aa_ws");
        if (saved) return saved;
      } catch (e) {}
      return "ws://" + (h || "localhost") + ":5695";
    }
    return "wss://server.animaslashanimearenaserver.org";
  }
  const ENERGY_NAMES = ["Green", "Blue", "White", "Red", "Random"];
  // "Nexus Clash" tournament pools: each round restricts char-select to a fixed set of anime.
  // The strings are the EXACT `universe` values in roster.json (verified — a mismatch silently
  // drops that anime from its round). Together the four rounds partition every roster universe
  // (each character lands in exactly one round). Round 3's Fate covers both franchise strings.
  const NEXUS_CLASH_ROUNDS = {
    1: ["A Certain Scientific Railgun", "Baki", "Puella Magi Madoka Magica", "That Time I Got Reincarnated as a Slime", "Yu-Gi-Oh!", "One Piece", "Seven Deadly Sins", "My Hero Academia", "Chainsaw Man", "Avatar", "Naruto"],
    2: ["Assassination Classroom", "Overlord", "Sailor Moon", "Record of Ragnarok", "Attack on Titan", "Deadman Wonderland", "Demon Slayer", "Fairy Tail", "Akame ga Kill", "Bleach", "Katekyo Hitman Reborn"],
    3: ["Chivalry of a Failed Knight", "Jujutsu Kaisen", "One Punch Man", "Dragon Ball", "Black Clover", "Mirai Nikki", "Fate", "Fate/stay night", "Solo Leveling", "Symphogear", "Mashle", "Seraph Of The End", "Kill la Kill"],
    4: ["Fire Force", "Hunter x Hunter", "Digimon", "Frieren", "Konosuba", "Tokyo Ghoul", "Wonder Egg Priority", "Shaman King", "Soul Eater", "Fullmetal Alchemist", "InuYasha"],
  };
  // Rank enum order (components/rank_component.gd) → "Bronze 1"-style strings on the info cards.
  const RANKS = ["Iron", "Bronze", "Silver", "Gold", "Platinum", "Diamond", "Master", "Grandmaster", "Challenger"];
  let _timerKey = "", _timerStart = 0;   // local cosmetic per-turn timer (see timerBar)
  let _effPanel = null, _effAnchor = null;   // imperative effect hover/tap panel (body-level, escapes battle clip)

  // --- mastery (verbatim port of components/mastery_config.gd) ------------------
  const MAX_LEVEL = 100;
  const XP_THRESHOLDS = [0, 100, 250, 475, 800, 1250, 1850, 2650, 3700, 5050, 6750, 8850, 11400, 14500, 18200, 22600, 27800, 34000, 41300, 49900, 60000, 71800, 85600, 101700, 120400, 142100, 167300, 196500, 230300, 269400, 314600, 366700, 426700, 495700, 575000, 666000, 770300, 889700, 1026200, 1182000, 1359600, 1561800, 1791700, 2052800, 2348900, 2684200, 3063400, 3491700, 3974800, 4519000, 5131200, 5819100, 6590900, 7455700, 8423400, 9504800, 10711600, 12056600, 13553600, 15217900, 17065300, 19113500, 21380900, 23887500, 26654800, 29705700, 33064700, 36756900, 40810900, 45256100, 50123600, 55446200, 61258500, 67595300, 74496100, 82000700, 90150700, 98989400, 108561700, 118914600, 130095700, 142153400, 155139500, 169106200, 184104400, 200189900, 217417500, 235842300, 255520000, 276506300, 298856700, 322626400, 347869800, 374640400, 402990400, 432970500, 464630000, 498014100, 533167600, 570131600, 608943800];
  function xpToLevel(xp) { for (let i = MAX_LEVEL; i >= 0; i--) if (xp >= XP_THRESHOLDS[i]) return i; return 0; }
  function levelProgressFraction(xp) { const l = xpToLevel(xp); if (l >= MAX_LEVEL) return 1; const f = XP_THRESHOLDS[l], c = XP_THRESHOLDS[l + 1]; return c === f ? 1 : (xp - f) / (c - f); }
  function xpIntoLevel(xp) { return xp - XP_THRESHOLDS[xpToLevel(xp)]; }
  function xpNeededForLevel(xp) { const l = xpToLevel(xp); return l >= MAX_LEVEL ? 0 : XP_THRESHOLDS[l + 1] - XP_THRESHOLDS[l]; }
  // Admins get a front-end display override: every character reads as mastery Lv 99, which surfaces all
  // mastery-gated rewards (cosmetics, titles — all unlock at ≤ Lv 12) as unlocked. Display only; the
  // actual stored mastery_xp is untouched.
  function masteryLevel(path) { return S.isAdmin ? 99 : xpToLevel(((S.player && S.player.mastery_xp) || {})[path] || 0); }
  // reward track: [type, label, unlock level] in canonical order (mastery_config.gd:120-127)
  const MASTERY_REWARDS = [["lesser_title", "Lesser Title", 2], ["playercard", "Player Card", 3], ["greater_title", "Greater Title", 4], ["action_frame", "Game Panel", 5], ["hat", "Hat", 8], ["elite_action_frame", "Elite Panel", 12]];
  const UNLOCK_THRESHOLDS = { lesser_title: 2, playercard: 3, greater_title: 4, action_frame: 5, hat: 8, elite_action_frame: 12 };
  // Base title words every player has (Player.title_data default in player_component.gd — not saved to the blob).
  const BASE_TITLE_WORDS = ["Beta", "Tester", "The", "of", "the", "Test", "and", "Anime", "Arena", "for", "to"];
  const MAX_TITLE_WORDS = 5;
  // Character-select order + composition, mirroring the Godot client's
  // char_select_scene.initialize_characters(): starter_squads cluster to the front (in
  // their listed order), then the rest of char_name_list. Characters absent from
  // char_name_list (e.g. kakashi, uryuu) are not offered in select. Regenerate from
  // scripts/character_database.gd if char_name_list / starter_squads change.
  const CHAR_SELECT_ORDER = [
    "naruto", "luffy", "yuji", "midoriya", "goku", "natsu", "meliodas", "madoka", "asta", "maka",
    "aang", "tanjiro", "eren", "saitama", "gon", "misaka", "emiya", "ichigo", "rimuru", "edward",
    "inuyasha", "yugi", "tatsumi", "tsunayoshi", "shinra", "ryuko", "ganta", "ken", "gatomon", "yoh",
    "frieren", "shinoa", "nagisa", "denji", "sasuke", "sakura", "hinata", "hashirama", "boruto", "itachi",
    "zoro", "usopp", "ace", "marco", "rob", "law", "nobara", "megumi", "sukuna", "gojo", "toji",
    "uraraka", "bakugo", "todoroki", "tokoyami", "tsuyu", "toga", "allmight", "lucy", "gray", "erza",
    "mavis", "sayaka", "mami", "yuno", "noelle", "soul", "blackstar", "tsubaki", "kid", "lizandpatty",
    "crona", "death", "kitara", "toph", "korra", "akame", "sheele", "mine", "esdeath", "nezuko",
    "zenitsu", "inosuke", "rengoku", "muichiro", "uzui", "muzan", "diane", "king", "ban", "escanor", "yamamoto", "ryohei",
    "chrome", "squalo", "xanxus", "hibari", "mikasa", "levi", "genos", "tatsumaki", "tamaki", "arthur",
    "killua", "kurapika", "hisoka", "neferpitou", "kuroko", "gunha", "shokuhou", "rakko", "saber", "gilgamesh",
    "emiyaarcher", "jack", "semiramis", "frankenstein", "mash", "astolfo", "satsuki", "nonon", "orihime", "byakuya",
    "nel", "halibel", "nimaiya", "ichibe", "kurotsuchi", "yoruichi", "shiro", "touka", "arima", "veldora", "alphonse",
    "vegeta", "gohan", "gogeta", "cooler", "cell", "seventeen", "broly", "frieza", "piccolo", "hawkmon", "renamon",
    "impmon", "myotismon", "ladydevimon", "machinedramon", "gallantmon", "omnimon", "alphamon", "blackwargreymon", "horohoro", "lyserg",
    "jeanne", "koro", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "fern", "stark",
    "megumin", "kaiba", "pegasus", "jaden", "jesse", "yubel", "toudou", "adam", "gasai", "minene",
    "aiohto", "jinwoo", "tsubasa", "hibiki", "power", "mashburnedead",
    "ainz", "baki", "yusuke", "sesshomaru",
  ];
  const CHAR_SELECT_SET = new Set(CHAR_SELECT_ORDER);
  const CHAR_SELECT_RANK = new Map(CHAR_SELECT_ORDER.map((n, i) => [n, i]));
  function masteryCosmeticId(type, path) {
    return type === "playercard" ? "playercard_mastery_" + path
      : type === "action_frame" ? "gamepanel_mastery_" + path
      : type === "hat" ? "hat_mastery_" + path
      : type === "elite_action_frame" ? "mastery_panel_elite_" + path : "";
  }
  // Image base. Same-origin "/assets/images" in production (app + assets co-hosted);
  // override via window.AA_ASSET_BASE (e.g. a CDN, or a separate dev static server).
  const ASSET_BASE = "/assets/images";
  // Bump whenever bundled art/assets change. Appended as ?v= to every bundled-asset URL so a
  // same-named replacement (e.g. a new character portrait) busts the browser AND the Cloudflare
  // Pages edge cache — a plain redeploy does NOT, because the URL is unchanged.
  const ASSET_VERSION = "2026-08-30";
  function assetBase() { return (typeof window !== "undefined" && window.AA_ASSET_BASE) || ASSET_BASE; }

  // ---- state ---------------------------------------------------------------
  // Read a localStorage boolean pref (absent -> default). Hoisted so the S literal below can use it.
  function lsBool(key, def) { try { const v = localStorage.getItem(key); return v == null ? def : v !== "0"; } catch (e) { return def; } }
  const S = {
    net: new AANet(),
    conn: "disconnected",
    screen: "login",
    username: "",
    player: null,        // parsed player blob
    creds: null,         // {url, user, pass} kept in memory for silent reconnect
    reconnecting: false, // mid auto-reconnect (shows an overlay)
    queued: false,
    roster: null,        // [{path_name, name, universe}] from roster.json
    portraits: null,     // {path_name: {default, alts[]}} from portraits.json
    abilityIcons: null,  // {source_basename: "Folder/file.png"} from ability_icons.json
    abilityInfo: null,   // {source_basename: {name, description, classes, cooldown}} from ability_info.json
    glossary: null,      // skill_glossary.json — {terms, skills, categories} for hover keywords (GK)
    abilityAliases: null, // {script_basename: json_key} for abilities whose script name != key (ability_aliases.json)
    described: null,     // {char_idx, ability_idx, ability} shown in the bottom-right description panel
    team: [],            // selected path_names (max 3)
    charSearch: "",      // char-select search text
    colorFilters: [],    // char-select energy-color filter; AND-match, but Black (Random, 4) makes it an EXACT-colors match
    animeFilter: "",     // universe filter for the grid, or "" for all
    nexusRound: 0,       // "Nexus Clash: Round X" pool filter (1-4), or 0 for all
    catFilter: "",       // bounty-category filter for the grid, or "" for all
    hideLocked: false,   // when true, the char-select grid hides characters the player hasn't unlocked
    catView: null,       // bounty-category browser: the category whose members are shown, or null (closed)
    bountyBuy: null,     // { key, square, path } — pending "complete this square for AP" confirm, or null
    menuInspect: null,   // {path_name, mode:"character"|"ability", basename?} — char-select info panel
    disguise: "",        // Toga passive: chosen disguise path_name (session-only; sent as the optional 4th queue element)
    disguisePicker: false, // true while Toga's "Disguise" roster-picker modal is open
    disguiseSel: null,   // in-modal highlighted selection (path_name, or "" for None) before Confirm commits it
    jinwooForm: "",      // Sung Jin-woo: equipped summon ("" | "red" | "green" | "white" | "blue"); session-only, sent as a "form:<color>" queue token
    jinwooPicker: false, // true while Jin-woo's summon-picker modal is open
    menuOverlay: null,   // null | "mastery" | "cosmetics" — open top-menu overlay
    menuHelp: null,      // overlay-name whose "?" help card is showing (auto-hides when the panel changes)
    glossaryOpen: false, // the searchable term Glossary modal (openable from char-select AND in-battle)
    glossQuery: "",      // live search filter inside the Glossary modal
    // GK hover-keyword display prefs (client-only, localStorage-backed; default ON). gkColors=false
    // renders every keyword in one uniform color; gkKeywords=false disables keyword highlighting
    // entirely (effect-tooltip hover is unaffected — that's icon-triggered, not keyword-triggered).
    gkColors: lsBool("aa_gk_colors", true),
    gkKeywords: lsBool("aa_gk_keywords", true),
    clan: null,          // clan panel payload from clan_state: { clan:{...}|null, invitations:[], applications:[] }
    clanSearchResults: null,  // clan_search results (null until a search runs)
    social: null,        // social panel payload from social_state: { friends:[{username,status}], requests_in:[], requests_out:[], ignored:[] }
    clanSearchQuery: "", clanCreateName: "", clanCreateBanner: "", clanInviteName: "", clanBannerEdit: "", profileQuery: "", socialAddName: "", socialIgnoreName: "",  // input buffers (kept off-render)
    avatarEdit: null,    // true while the "set avatar URL" modal is open
    privatePrompt: null, // true while the "private match — enter opponent" modal is open
    privateTarget: null, // opponent username while queued for a private match
    masteryChar: null,   // selected character path_name in the mastery menu
    masterySort: "name", // mastery panel order: "name" (A→Z) | "mastery" (level/xp, highest first)
    cosmeticTab: "playercard",  // active cosmetics-menu tab
    cosmeticPreview: null,      // cosmetic entry ({tab,id,name,path,source,...}) shown in the cosmetics preview pane
    cosmeticSlot: 0,            // team slot (0..2) a panel/hat equips to (player_card is single)
    bgTarget: "ingame",        // cosmetics Background tab: which screen to set ("ingame" | "charselect")
    nexusUniverse: null,        // selected universe in the Nexus (null = leaderboard home)
    nexusBuckets: {},           // { path_name: ap } global community buckets (from nexus_state)
    nexusMax: 1,                // current leader bucket AP (denominator for progress bars)
    nexusPollOpen: true,        // whether Nexus donations are currently open
    nexusDonate: null,          // { path_name, amount? } — donation popup target
    titles: null,               // { lesser: {path:[words]}, greater: {path:[words]} } from titles.json
    titleEdit: null,            // working list of title words being composed in the Title menu
    ladder: null,               // { by_rating, by_wins, by_streak, clan_data } from the ladder request
    ladderTab: "by_rating",     // active Ladder tab
    profile: null,              // { username, wins, losses, rating, streak, rank, tier, clan, title, top_mastery[], match_history[] } from get_player_profile

    bountyData: null,           // { categories, winning_patterns, archetypes, starters } from bounty_data.json
    bountyTab: "unlock",        // "unlock" | "mastery"
    bountySel: null,            // selected character path_name (raw)
    bountyMissions: {},         // cache { bounty_key: [25 missions] } from the server
    btySearch: "",              // bounty character-list search text (off-render buffer, like charSearch)
    shopCatalog: null,          // { items: {cat:[item]}, display_names, order } from shop_catalog.json
    shopTab: "gamepanel",       // active shop category
    shopBuy: null,              // { unlock, name, price } — purchase confirm popup
    // --- campaign mode (Phase 0 + placeholder chapter X) ---
    campaign: null,             // persistent progress { chapter, node, stage, flags, visited, completed, party } (mirrors player.campaign_state)
    campaignData: null,         // campaign_chapters.json
    campaignDialogue: null,     // campaign_dialogue.json
    campaignEncounters: null,   // campaign_encounters.json
    campaignView: "map",        // "map" | "dialogue"
    campaignRun: null,          // active node-sequence runtime { nodeId, activationId, once, steps, idx, on_complete }
    campaignScene: null,        // active dialogue runtime { id, line }
    campaignMoving: null,       // { from, to } while the token glides between nodes
    campaignBattleReturn: false,// true while a campaign battle is out — its end resumes the sequence
    campaignLoadout: null,      // loadout editor: null=closed, else { tab:"party"|"skills", party:[], skills:[], inspect:<key|path> }
    match: null,         // {opponent, first_turn, seed, canonical_role}
    snapshot: null,      // latest wire snapshot
    prevHp: {},          // canonIdx -> last-rendered hp% (for the glide animation)
    staged: [],          // queued actions this turn: [{char_idx, ability_idx, target_idxs, ability_name, cost}]
    execOrder: null,     // End-Turn modal: ordered [{order_id, kind, label, icon}] resolution sequence (skills + ticking)
    randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 },  // turn's RANDOM pips assigned per color
    exchange: null,      // pending energy exchange {offer:{c:2}, request:r} | null
    exchangeSetup: null, // {give, get} while building an exchange in the panel
    targeting: null,     // active single-target pick: {char_idx, ability_idx, ability_name, special_targets}
    acting: false,       // a submit_turn_input is in flight
    matchResult: null,   // {won: true|false|null} once the match ends
    // Authoritative ladder movement for the match just played, straight from the server:
    // {won, rating_before, rating_after, delta, rank_before, tier_before, rank_after, tier_after,
    //  promoted, demoted, rank_changed}. Held OUTSIDE matchResult because it can arrive before the
    // MATCH_ENDED event that creates matchResult — the two frames have no ordering guarantee.
    rankedResult: null,
    viewer: null,        // {mode:'replay'|'spectate', ...} when watching, else null; disables all battle interactivity
    socialDockEnabled: false, // runtime switch: flipped on at login so the body-level chat dock shows (off pre-login)
    // --- Phase 2 chat (RAM ring buffers; no durable history — the server is authoritative) ---
    chat: { global: [], match: [], dms: {}, tab: "global", dm: null,
            unread: { global: 0, match: 0, dms: {} }, expanded: false, globalEnabled: true },
    chatInput: "",       // off-render input buffer (mutated by oninput; never through set()/render() — caret safety)
    confirmSurrender: false,
    oppGone: false,      // opponent disconnected (inside their reconnect window)
    railgunPlayed: false, // one-shot: has Misaka's Ultra Railgun VFX fired yet this match
    mineBladePlayed: false, // one-shot: has Mine's High Output Blast Blade VFX fired yet this match
    // Update/maintenance flow. null = normal. Otherwise {phase, message, deadline, bootId}:
    //   "warn"    - screen-wide banner + countdown, play continues
    //   "ejected" - forced to the login screen, login disabled, waiting for the new server
    //   "back"    - a different boot_id answered: the new build is live, reloading
    maint: null,
    msg: "",             // status line
    msgKind: "",
    logLines: [],
  };
  function set(patch) { Object.assign(S, patch); render(); }
  function log(kind, text) {
    S.logLines.push({ kind, text });
    if (S.logLines.length > 60) S.logLines.shift();
    const box = $("#log");
    if (box) { renderLog(box); box.scrollTop = box.scrollHeight; }
  }

  // ---- network wiring ------------------------------------------------------
  S.net.onStatus((c) => set({ conn: c }));
  S.net.on("*", (m) => log("in", JSON.stringify(m).slice(0, 200)));

  // Server announcement -> a wide scrolling marquee across this client's screen, on any screen.
  S.net.on("announcement", (m) => showMarquee(m && m.text, m && m.from));

  // ---- update / maintenance flow -------------------------------------------
  // Phase 1: the warning. A screen-wide banner with a live countdown, on every screen. Play is NOT
  // interrupted — the point is that nobody can miss it, not that everybody stops immediately.
  S.net.on("maintenance_notice", (m) => {
    if (noteBootId(m && m.boot_id)) return;
    const secs = Math.max(0, Number((m && m.seconds) || 0));
    S.maint = { phase: "warn", message: (m && m.message) || "The server is going down for an update.",
                deadline: secs > 0 ? Date.now() + secs * 1000 : 0, bootId: (m && m.boot_id) || "" };
    renderMaintBanner();
    set({});
  });
  // Phase 2: the eject. Everyone lands on the login screen with login disabled. Deliberately does
  // NOT close the socket — the server is still up until the operator stops it, and that stop is the
  // `_close` the waiting poller below keys off.
  S.net.on("maintenance_eject", (m) => {
    S.maint = { phase: "ejected", message: (m && m.message) || "The server is going down for an update.",
                deadline: 0, bootId: (m && m.boot_id) || "" };
    leaveForMaintenance();
  });
  // Also sent on every login by a server with no maintenance, so a banner left over from before a
  // restart clears itself instead of hanging around for the rest of the session.
  S.net.on("maintenance_cleared", (m) => {
    if (noteBootId(m && m.boot_id)) return;   // the process was replaced — reloading, nothing else matters
    if (!S.maint) return;
    const wasEjected = S.maint.phase === "ejected";
    stopMaintPoll();
    S.maint = null;
    renderMaintBanner();
    if (wasEjected) set({ msg: "Update cancelled — you can log in again.", msgKind: "ok" });
    else set({});
  });
  // A fresh page load during the lock (someone refreshed on their own) gets this instead of a login.
  // Admin-only ack for their own maintenance action (the eject reports what it stood down).
  S.net.on("maintenance_state", (m) => {
    const ph = (m && m.phase) || "";
    if (ph === "ejected") {
      set({ msg: "Ejected everyone — " + ((m && m.matches_cancelled) || 0) + " match(es) cancelled, " +
                 ((m && m.dequeued) || 0) + " dequeued. Safe to stop the server.", msgKind: "ok" });
    } else if (ph === "warn") {
      set({ msg: "Update announced (" + Math.round(((m && m.seconds) || 0) / 60) + " min).", msgKind: "ok" });
    } else {
      set({ msg: "Maintenance cancelled.", msgKind: "ok" });
    }
  });
  S.net.on("maintenance_locked", (m) => {
    S.maint = { phase: "ejected", message: (m && m.message) || "The server is going down for an update.",
                deadline: 0, bootId: (m && m.boot_id) || "" };
    // This frame is the server's ANSWER to a login — including the one attemptReconnect sends. Tear
    // the reconnect down or its overlay sits on top of the maintenance panel until _rcGiveUp fires
    // 112s later and then wipes the creds with a contradictory "could not reconnect".
    leaveForMaintenance();
    startMaintPoll();
  });
  // The poller's answer. A DIFFERENT boot_id means a different server process — the new build is
  // live, so this page (still running the OLD frontend) has to reload to pick it up.
  // Any frame carrying a boot_id is a chance to notice the process was replaced. noteBootId reloads
  // on a CHANGE (never on first sight), which catches clients that were disconnected when the eject
  // went out and so never entered the ejected phase at all.
  function noteBootId(id) {
    if (!id) return false;
    if (!S.bootId) { S.bootId = id; return false; }
    if (S.bootId === id) return false;
    S.bootId = id;
    bustedReload();
    return true;
  }
  S.net.on("server_status", (m) => {
    if (!S.maint || S.maint.phase !== "ejected") { noteBootId(m && m.boot_id); return; }
    const newBoot = (m && m.boot_id) || "";
    // Prefer the ejected path's own comparison: it shows "Update complete — reloading…" first.
    if (newBoot && S.maint.bootId && newBoot !== S.maint.bootId) { S.bootId = newBoot; maintenanceReload(); return; }
    if (m && m.maintenance === false && newBoot === S.maint.bootId) {
      // Same process, lock lifted: the admin cancelled rather than restarting.
      stopMaintPoll();
      S.maint = null;
      renderMaintBanner();
      set({ msg: "Update cancelled — you can log in again.", msgKind: "ok" });
    }
  });

  // Admin panel: online-players snapshot + result of a player modification.
  S.net.on("admin_players", (m) => renderAdminPlayers((m && m.players) || [], m && m.total_accounts));
  S.net.on("ultra_bot_status", (m) => { _adminBots = (m && m.bots) || []; _adminBotsRotation = !!(m && m.rotation_enabled); _adminBotsDeployed = !!(m && m.deployed); renderAdminBots(); });
  S.net.on("ultra_bot_result", (m) => { showToast(((m && m.username) || "bot") + ": " + ((m && m.action) || "") + ((m && m.ok) ? " ✓" : " ✗"), (m && m.ok) ? "ok" : "err"); refreshAdminBots(); });
  S.net.on("admin_modify_result", (m) => { set({ msg: ((m && m.target) || "") + ": " + ((m && m.note) || "done"), msgKind: "ok" }); refreshAdminPlayers(); });
  // Season reset. A preview reports counts and changes nothing; a real run reports how many accounts
  // were reset and where the automatic backup went. refreshAdminPlayers so the list reflects the wipe.
  S.net.on("admin_season_reset_result", (m) => {
    set({ msg: (m && m.note) || "Season reset done", msgKind: (m && m.ok) ? "ok" : "err" });
    if (m && m.ok && !m.dry_run) refreshAdminPlayers();
  });
  // Admin panel: per-character usage/win-rate aggregates (Char Usage tab).
  S.net.on("admin_character_stats", (m) => {
    _adminStats = (m && m.stats) || [];
    if (m && m.data_from != null) _adminStatsSpan = [m.data_from, m.data_to];
    renderAdminStatsTable();
  });

  // Admin panel: site-usage dashboard payload (Metrics tab). One message carries every figure on
  // screen, so the tiles and the charts always describe the same window and the same instant.
  S.net.on("admin_site_metrics", (m) => { _adminMetrics = m || null; renderAdminMetrics(); });

  // Clan panel: my clan / pending offers snapshot, search results, action toasts, live invite pings.
  S.net.on("clan_state", (m) => set({ clan: { clan: (m && m.clan) || null, invitations: (m && m.invitations) || [], applications: (m && m.applications) || [] } }));
  S.net.on("clan_search_result", (m) => set({ clanSearchResults: (m && m.clans) || [] }));
  S.net.on("clan_result", (m) => set({ msg: (m && m.note) || (m && m.ok ? "Done" : "Failed"), msgKind: m && m.ok ? "ok" : "err" }));
  S.net.on("clan_invite_notice", (m) => set({ msg: "You've been invited to clan " + ((m && m.clan_name) || ""), msgKind: "ok" }));

  // Social panel: friends / requests / ignore snapshot, action toasts, live request + presence pushes.
  // Server-authoritative like the clan panel — the client repaints from the pushed social_state and
  // never optimistically mutates (the presence handler only patches a status the server just told us).
  S.net.on("social_state", (m) => set({ social: {
    friends: (m && m.friends) || [], requests_in: (m && m.requests_in) || [],
    requests_out: (m && m.requests_out) || [], ignored: (m && m.ignored) || [],
  } }));
  S.net.on("social_result", (m) => showToast(m && m.note, (m && m.ok) ? "ok" : "err"));
  S.net.on("friend_request_notice", (m) => showToast("Friend request from " + ((m && m.from) || "someone"), "info"));
  S.net.on("friend_presence", (m) => {
    if (!S.social || !m) return;
    const f = (S.social.friends || []).find((x) => x.username === m.username);
    if (f) { f.status = m.status; render(); }   // repaint the friend's presence pill in place
  });

  // Phase 2 chat. The server owns membership, muting, the global kill switch and ignore-filtering;
  // the client just files each delivered message into the right RAM ring and repaints the dock.
  // Repaints go straight through syncSocialUI (a dock-only repaint) — NOT set()/render() — so a
  // steady message stream never tears down #app or drops a caret in some other panel's input.
  S.net.on("chat_message", (m) => {
    if (!m) return;
    const me = chatMe(), entry = { from: m.from, text: m.text, ts: m.ts }, ch = m.channel;
    let peer = null, isDm = false;
    if (ch === "global") { S.chat.global.push(entry); while (S.chat.global.length > 100) S.chat.global.shift(); }
    else if (ch === "match") { S.chat.match.push(entry); while (S.chat.match.length > 100) S.chat.match.shift(); }
    else if (ch === "dm") {
      isDm = true;
      peer = (m.from === me) ? m.to : m.from;   // the OTHER party is the thread key, whichever side I'm on
      const arr = (S.chat.dms[peer] || []).concat([entry]);
      while (arr.length > 100) arr.shift();
      S.chat.dms[peer] = arr;
    } else return;
    // Unread: only for messages from someone else that I'm not currently looking at.
    const viewing = S.chat.expanded && (
      (ch === "global" && S.chat.tab === "global") ||
      (ch === "match" && S.chat.tab === "match" && !isViewer()) ||   // viewer mode hides the Match tab, so it can't be "being viewed"
      (ch === "dm" && S.chat.tab === "dms" && S.chat.dm === peer));
    if (m.from !== me && !viewing) {
      if (isDm) S.chat.unread.dms[peer] = (S.chat.unread.dms[peer] || 0) + 1;
      else S.chat.unread[ch] = (S.chat.unread[ch] || 0) + 1;
    }
    if (isDm && m.from !== me && !S.chat.expanded) {   // an incoming DM while the dock is closed -> toast + chime
      const t = String(m.text == null ? "" : m.text);
      showToast(m.from + ": " + (t.length > 60 ? t.slice(0, 60) + "…" : t), "info");
      SFX.play("notify");
    }
    syncSocialUI();
  });
  S.net.on("chat_history", (m) => {
    if (!m) return;
    const msgs = (m.messages || []).map((x) => ({ from: x.from, text: x.text, ts: x.ts }));
    if (m.channel === "global") S.chat.global = msgs;
    else if (m.channel === "match") S.chat.match = msgs;
    else if (m.channel === "dm" && m.to) S.chat.dms[m.to] = msgs;
    else return;
    syncSocialUI();
  });
  S.net.on("chat_result", (m) => { if (m && !m.ok) showToast(m.note, "err"); });
  S.net.on("global_chat_state", (m) => { S.chat.globalEnabled = !!(m && m.enabled); syncSocialUI(); });

  S.net.on("receive_login_response", (m) => {
    let outer; try { outer = JSON.parse(m.json_string); } catch { return; }
    if (!outer || outer.id === 0) {
      if (S.reconnecting) return finishReconnect({ creds: null, screen: "login", msg: (outer && outer.message) || "Session expired — log in again", msgKind: "err" });
      clearSavedLogin();   // bad/stale saved creds shouldn't keep silently re-failing on load
      set({ msg: (outer && outer.message) || "Login failed", msgKind: "err", isAdmin: false });
      return;
    }
    let player = null;
    try { player = typeof outer.player === "string" ? JSON.parse(outer.player) : outer.player; } catch {}
    if (S.reconnecting) {
      // Reconnect login. id 2 = session resumed → a receive_session_reconnect should
      // follow with the live match (wait briefly, else the match ended → menu). id 1 =
      // session was wiped (>120s away / lobby drop) → no match → menu.
      set({ player, team: teamFromPlayer(player), isAdmin: !!outer.is_admin, socialDockEnabled: true });
      S.net.send("social_state", {});   // repopulate the Social badge/panel after a reconnect (id 1 & 2)
      _chatHistReq.delete("global"); S.net.send("chat_history", { channel: "global" }); _chatHistReq.add("global");   // dock state is client-side — re-pull global after a silent reconnect (match refetch rides receive_session_reconnect)
      for (const k of [..._chatHistReq]) {   // re-pull every open DM thread too (their buffers are server-side RAM)
        if (!k.startsWith("dm:")) continue;
        _chatHistReq.delete(k); S.net.send("chat_history", { channel: "dm", to: k.slice(3) }); _chatHistReq.add(k);
      }
      clearTimeout(S._rcTimer);
      if (outer.id === 2) {
        S._rcTimer = setTimeout(() => finishReconnect({ screen: "menu", match: null, snapshot: null, msg: "Match ended while you were away" }), 1500);
      } else if (S.viewer && S.viewer.mode === "replay") {
        // A socket blip during a REPLAY (purely local playback) only needed the login restored —
        // don't kick the user to the menu and destroy their playback position.
        finishReconnect({ msg: "Reconnected", msgKind: "ok" });
      } else {
        finishReconnect({ screen: "menu", match: null, snapshot: null, msg: "Reconnected", msgKind: "ok" });
      }
      return;
    }
    // Fresh (non-reconnect) login: wipe any prior user's chat so a re-login as a different account on
    // the same page doesn't inherit their buffers/threads (the reconnect branch above deliberately keeps them).
    S.chat = { global: [], match: [], dms: {}, tab: "global", dm: null, unread: { global: 0, match: 0, dms: {} }, expanded: false, globalEnabled: true };
    _chatHistReq.clear();
    // Restore the persisted pre-match selections (Toga disguise / Jin-woo form) for this account so a
    // refresh or re-login keeps them (the team round-trips via the server; these are browser-scoped).
    const pm = loadPrematch(player && player.username);
    set({ player, team: teamFromPlayer(player), disguise: pm.disguise, jinwooForm: pm.jinwooForm, screen: "menu", msg: "Logged in (id " + outer.id + ")", msgKind: "ok", isAdmin: !!outer.is_admin, socialDockEnabled: true });
    S.net.send("social_state", {});   // populate the Social badge/panel on login (before the panel is opened)
  });

  S.net.on("receive_register_response", (m) => {
    const ok = /success/i.test((m && m.message) || "");
    if (ok && S._regCreds) {   // account created — log straight in with the same credentials
      const c = S._regCreds; S._regCreds = null;
      doLogin(c.url, c.user, c.pass, c.remember);
      return;
    }
    set({ msg: (m && m.message) || "Registration failed", msgKind: ok ? "ok" : "err" });
  });

  S.net.on("receive_change_password_response", (m) => {
    if (m && m.ok) {
      const np = S._pwChange && S._pwChange.newPass; S._pwChange = null;
      if (np) {
        if (S.creds) S.creds.pass = np;                                    // keep the in-memory reconnect creds valid
        if (loadSavedLogin() && S.username) saveSavedLogin(S.username, np);   // and the "keep me logged in" copy
      }
      set({ msg: m.message || "Password updated", msgKind: "ok" });
    } else {
      set({ msg: (m && m.message) || "Could not change password", msgKind: "err" });
    }
  });

  // Reconnect resume: the server re-sent the snapshot-based package for the live match.
  // BattleScene.Match enum → the display kind onMatch uses (server ships info.match_type).
  const RECONNECT_KIND = { 0: "Private Match", 1: "Quick Match", 2: "Bot Match", 3: "Ladder Match", 4: "Campaign Battle" };
  S.net.on("receive_session_reconnect", (m) => {
    let info; try { info = typeof m.info === "string" ? JSON.parse(m.info) : m.info; } catch { return; }
    const snap = info && info.snapshot;
    if (!snap || !snap.sides) return finishReconnect({ screen: "menu", match: null, snapshot: null, msg: "Match ended while you were away" });
    clearInterval(_replayTimer); _replayTimer = null; S.viewer = null;   // resuming a LIVE match as a player — never as a viewer
    _chatHistReq.delete("match"); S.net.send("chat_history", { channel: "match" }); _chatHistReq.add("match");   // re-pull this match's chat after a silent reconnect (dock buffers are client-side)
    const p = S.player || {};
    finishReconnect({
      screen: "battle",
      // Restore the queue-derived fields the old reconnect path dropped, so the game-over modal
      // still shows the match type + AP gained. AP/streak are only awarded at match END, so the
      // player's current values (from the reconnect login) equal their at-match-start values.
      // match_type 2 = BOT (BattleScene.Match). An explicit practice bot (info.practice) is a "Bot
      // Match" (flat 50/0 AP); a non-practice bot is a quick-queue fallback (Quick AP + W/L), shown
      // as a Quick Match so matchApGain scores it with the Quick formula — not the flat bot award.
      match: { opponent: info.enemy || {}, canonical_role: info.canonical_role, first_turn: false, seed: 0,
               kind: (info.match_type === 2 ? (info.practice ? "Bot Match" : "Quick Match") : (RECONNECT_KIND[info.match_type] || "Match")),
               ranked: info.match_type === 3,
               vsBot: !!info.vs_bot,
               apBefore: p.ap || 0, streakBefore: p.streak || 0 },
      snapshot: ingestSnapshot(snap), staged: [], execOrder: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, exchangeSetup: null, randomModal: false, targeting: null, acting: false,
      matchResult: snap.match_over ? { won: null } : null, railgunPlayed: true, mineBladePlayed: true,
      msg: "Reconnected", msgKind: "ok",
    });
  });
  S.net.on("receive_opponent_disconnect_notification", () => set({ oppGone: true, msg: "Opponent disconnected — waiting for them to reconnect…", msgKind: "" }));
  S.net.on("receive_opponent_reconnect_notification", () => set({ oppGone: false, msg: "Opponent reconnected", msgKind: "ok" }));

  // The short-payload rejections send no reason, so the team message stays the default — but a
  // private invite can now also be rejected because the OTHER side is already in a match, and that
  // frame carries `reason`. Honour it or the player is told to fix a team that is already fine.
  S.net.on("receive_queue_rejected", (m) =>
    set({ queued: false, msg: (m && m.reason) || "Queue rejected — need a 3-character team", msgKind: "err" }));

  // Server-side error (e.g. a rejected turn — see _process_turn_input). Surface the reason and
  // re-enable the turn UI right away so a rejection never leaves `acting` stuck (the watchdog
  // is the slower fallback for the no-reply case). Harmless when not mid-turn (acting is false).
  S.net.on("error", (m) => {
    clearTurnWatchdog();
    set({ acting: false, msg: (m && m.reason) || "Server error", msgKind: "err" });
  });

  // Post-match (and other) fresh player data — refresh rank/AP/unlocks on the menu.
  S.net.on("receive_player_update", (m) => {
    let player = null;
    try { player = typeof m.json_string === "string" ? JSON.parse(m.json_string) : m.json_string; } catch {}
    if (!player) return;
    const patch = { player };
    // The first player_update after a match end carries the awarded AP — record the
    // delta on matchResult so the game-over modal can show "AP gained".
    if (S.matchResult && S.match && S.matchResult.apGain == null) {
      const before = S.match.apBefore != null ? S.match.apBefore : ((S.player && S.player.ap) || 0);
      const mr = Object.assign({}, S.matchResult, { apGain: (player.ap || 0) - before });
      patch.matchResult = mr;
    }
    // If an unlock bounty just completed — the character we're viewing on the Unlock tab is now
    // owned — move the view to that character's Mastery bounty instead of re-offering the (now
    // pointless) unlock bounty. Fetch the mastery card if it isn't cached yet.
    if (S.bountyTab === "unlock" && S.bountySel) {
      const u = player.unlocks || [], st = (S.bountyData && S.bountyData.starters) || [];
      const nowOwned = st.includes(S.bountySel) || u.includes(S.bountySel + "_unlock") || u.includes("all_unlock");
      if (nowOwned) {
        patch.bountyTab = "mastery";
        if (!S.bountyMissions[S.bountySel + MASTERY_SUFFIX]) S.net.send("bounty_missions", { path: S.bountySel, btype: "mastery" });
      }
    }
    set(patch);
  });

  // Nexus: full bucket snapshot, and live single-bucket updates after a donation.
  S.net.on("nexus_state", (m) => {
    const buckets = {}, bucketUni = {};
    // sets: [path_name, ap, universe]. The universe lets us group EVERY bucket (the server's
    // bucket roster is far larger than the playable roster.json the universe buttons came from).
    (m.sets || []).forEach((s) => { buckets[s[0]] = s[1]; if (s[2] != null) bucketUni[s[0]] = prettyUniverse(String(s[2])); });
    set({ nexusBuckets: buckets, nexusBucketUni: bucketUni, nexusMax: Math.max(1, m.max || 1), nexusPollOpen: m.poll_open !== false });
    if (_adminNexusPreview) _adminNexusPreview();   // repaint the admin "Close Round" preview if it's open
  });
  S.net.on("update_buckets", (m) => {
    S.nexusBuckets[m.path_name] = m.amount;
    set({ nexusMax: Math.max(S.nexusMax, m.current_max || 1) });
  });
  // Admin round-close result — the fresh nexus_state broadcast already refreshed the standings.
  S.net.on("nexus_round_closed", (m) => {
    const removed = m.removed || [];
    set({ msg: removed.length ? ("Round closed — removed: " + removed.map(nameFor).join(", ")) : "Round closed — nothing removed (AP halved)", msgKind: "ok" });
  });
  S.net.on("nexus_scaled", (m) => set({ msg: "Scaled " + (m.count || 0) + " characters' AP ×" + (m.multiplier != null ? m.multiplier : "?"), msgKind: "ok" }));
  S.net.on("ladder", (m) => set({ ladder: m.ladder || null }));
  S.net.on("player_profile", (m) => { _profileResetArm = false; set({ profile: (m && m.profile) || null }); });
  // Self-service W/L reset echo: server sends the freshly-zeroed profile back (plus a
  // receive_player_update for S.player). Refresh the view + confirm with a toast.
  S.net.on("record_reset", (m) => { _profileResetArm = false; set(Object.assign((m && m.profile) ? { profile: m.profile } : {}, { msg: "Win/loss record reset", msgKind: "ok" })); });
  S.net.on("bounty_missions", (m) => { if (m.key) { S.bountyMissions[m.key] = m.missions || []; set({}); } });

  function onMatch(m, kind) {
    _sfxWasMyTurn = null;          // fresh match — suppress the chime on the very first "my turn" (notify covers it)
    // A fresh REAL match always clears viewer state (e.g. a stale S.viewer left by a socket drop
    // mid-spectate, whose reconnect lands on the menu without passing through viewerExit).
    clearInterval(_replayTimer); _replayTimer = null; S.viewer = null;
    // Fresh match channel: drop any prior match's buffered chat + unread, then pull this match's history.
    S.chat.match = []; S.chat.unread.match = 0; _chatHistReq.delete("match");
    _chatHistReq.add("match"); S.net.send("chat_history", { channel: "match" });
    SFX.play("notify");            // battle-start / match-found alert (Godot: sharp_notification)
    set({
      queued: false, privateTarget: null, privatePrompt: null, railgunPlayed: false, mineBladePlayed: false,
      rankedResult: null,   // a previous ladder game's result must never bleed into this one
      // apBefore / streakBefore: the player's AP + win streak at match START, so the game-over
      // modal can show the AP gained (the post-match player_update doesn't reliably carry it —
      // see matchApGain). vsBot marks a queue-supplied bot opponent, which is what separates a
      // 250-AP ranked bot win from a 500-AP win over a human.
      match: { opponent: m.opponent || {}, first_turn: m.first_turn, seed: m.seed, canonical_role: m.canonical_role, kind: kind || "Match", ranked: kind === "Ladder Match", vsBot: !!m.vs_bot, apBefore: (S.player && S.player.ap) || 0, streakBefore: (S.player && S.player.streak) || 0 },
      screen: "battle",
      msg: "",
    });
  }
  // Bot matches ride the same channel as quick matches. A practice bot (explicit "Bot Match" queue)
  // carries practice:true → label it "Bot Match" so the game-over modal shows its flat 50/0 AP; a
  // non-practice bot is a quick-queue fallback (records W/L + Quick AP), so it stays a Quick Match.
  S.net.on("receive_quick_match", (m) => onMatch(m, m.practice ? "Bot Match" : "Quick Match"));
  // Channel name is the WIRE contract and must not change; only the label does.
  S.net.on("receive_ranked_match", (m) => onMatch(m, "Ladder Match"));
  S.net.on("receive_private_match", (m) => onMatch(m, "Private Match"));
  S.net.on("receive_campaign_match", (m) => onMatch(m, "Campaign Battle"));   // single-player PvE (Phase 1)
  // Server-authoritative campaign progression: every enter/travel/complete/choice intent is
  // validated + applied server-side; the authoritative state (and any reward unlocks) echoes back here.
  S.net.on("campaign_state", (m) => campaignApplyServerState(m, m && m.note));
  S.net.on("campaign_error", (m) => {
    campaignApplyServerState(m, "error");
    set({ campaignMoving: null, msg: (m && m.reason) || "Campaign action rejected", msgKind: "err" });
  });
  // Ladder movement for the match just finished (ranked only, one frame per human player).
  // Purely a display payload — the rating it reports is already applied server-side.
  S.net.on("ranked_result", (m) => { S.rankedResult = m; set({}); });
  // Ranked draft: server pushes the initial draft state, then per-change updates.
  S.net.on("draft_start", (m) => onDraftStart(m));
  S.net.on("draft_update", (m) => onDraftUpdate(m));
  // AP awarded for the match just finished.
  // Mirrors the server's _calculate_ap_gain table (server_connection.gd) so the game-over modal can
  // show the AP figure immediately instead of waiting on receive_player_update. Flat per queue —
  // there is no streak scaling any more. Change both together.
  // Ranked-ness is a FLAG, never a substring of the display label — the ladder label reads
  // "Ladder Match", so /ranked/i matched nothing and silently disabled every ranked-only branch.
  function isRankedMatch() { return !!(S.match && S.match.ranked); }
  function matchApGain(won) {
    const kind = (S.match && S.match.kind) || "";
    if (/private/i.test(kind)) return 0;
    // Practice "Bot Match" — the explicit bot queue. A quick-queue fallback bot is labelled
    // "Quick Match", so it correctly falls through to the Quick rate below.
    if (/bot/i.test(kind)) return won ? 50 : 0;
    // Ranked pays less when the opponent was the queue's own bot; vs_bot is the only thing on the
    // wire that reveals it (the bot is otherwise indistinguishable from a human).
    if (isRankedMatch()) {
      if (S.match && S.match.vsBot) return won ? 250 : 50;
      return won ? 500 : 50;
    }
    if (!/quick/i.test(kind)) return null;
    return won ? 100 : 50;
  }

  S.net.on("apply_turn_result", (m) => {
    clearTurnWatchdog();   // a turn result landed — the submit resolved, so cancel the recovery timer
    // No live context -> drop the frame. Every legitimate frame is preceded by a context-setter
    // (onMatch / reconnect / spectate_init all set S.match); without this, a spectator broadcast
    // still in flight when the user clicks Leave would repopulate the snapshot on the MENU.
    if (!S.match) return;
    maybePlayRailgun(m.events || []);   // one-shot Misaka VFX — reads the PRE-turn snapshot, so must fire before the set() below
    maybePlayMineBlade(m.events || []);  // same ordering requirement (resolves the caster from the PRE-turn snapshot)
    let result = S.matchResult;
    const ended = (m.events || []).find((e) => e.type === "MATCH_ENDED");
    if (ended && S.match) {
      // A spectator has no seat: the outcome is neutral (won:null) but keep winner_role so the
      // game-over modal can name the winner from the viewer display blobs.
      result = isViewer()
        ? { won: null, winner_role: ended.winner_role }
        : { won: ended.winner_role === (S.match.canonical_role === 0 ? "p1" : "p2") };
    } else if (m.snapshot && m.snapshot.match_over && !result) {
      result = { won: null };
    }
    // Derive the AP gain client-side the moment we know the outcome (the post-match
    // player_update doesn't reliably carry it). null = not derivable -> the delta fills in.
    if (result && result.won != null && result.apGain == null) {
      const ap = matchApGain(result.won);
      if (ap != null) result = Object.assign({}, result, { apGain: ap });
    }
    if (m.snapshot) {
      set({ snapshot: ingestSnapshot(m.snapshot), staged: [], execOrder: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, exchangeSetup: null, randomModal: false, targeting: null, acting: false, oppGone: false, msg: "", matchResult: result });
      playEventAnimations(m.events || []);
      // My-turn chime (Godot: myturn) on the OFF->ON transition. The very first "my turn" is suppressed
      // by the null seed set in onMatch — the battle-start notify already covered it. A viewer has no
      // turn (canonical_role 0 is just the camera seat), so never chime while watching.
      const nowMyTurn = !!(S.match && S.snapshot && !S.snapshot.match_over && isMyTurn() && !isViewer());
      if (nowMyTurn && _sfxWasMyTurn === false) SFX.play("turn");
      _sfxWasMyTurn = nowMyTurn;
    }
  });

  // ---- viewer wire: replays + spectating -----------------------------------
  // replay_data ships one replay as ordered chunks (the gateway's WS frames are the Godot-default
  // 64KB; a full replay can be >1MB). Accumulate per match_id, tolerate out-of-order/duplicate
  // parts, join + parse once every part landed. Keyed storage is a plain part->substring map so
  // 0- or 1-based part numbering both join correctly (numeric sort).
  const _replayParts = {};   // match_id -> { parts: {part:int -> data}, got: int, total: int }
  S.net.on("replay_data", (m) => {
    if (!m || m.match_id == null || !(Number(m.total) > 0)) return;
    const key = String(m.match_id);
    const acc = _replayParts[key] || (_replayParts[key] = { parts: {}, got: 0, total: Number(m.total) });
    const i = Number(m.part);
    if (!isFinite(i) || acc.parts[i] != null) return;   // malformed / duplicate part
    acc.parts[i] = String(m.data == null ? "" : m.data);
    acc.got++;
    if (acc.got < acc.total) return;
    delete _replayParts[key];
    // NEVER hijack a live context: if a real match or draft started while the chunks were in
    // flight, entering the replay would seize the battle screen mid-game. Drop it with a note.
    if ((S.match && !S.viewer) || S.screen === "draft") return showToast("Replay ready — finish your match first", "info");
    const joined = Object.keys(acc.parts).map(Number).sort((a, b) => a - b).map((k) => acc.parts[k]).join("");
    let rep;
    try { rep = JSON.parse(joined); } catch (e) { return showToast("Could not load replay (corrupt data)", "err"); }
    enterReplay(rep);
  });
  S.net.on("replay_result", (m) => {
    if (m && !m.ok) {
      for (const k in _replayParts) delete _replayParts[k];   // a failed fetch leaves no stale partial buffers
      showToast(m.note, "err");
    }
  });
  // ---- admin: bot-training dashboard wire ----------------------------------
  // Training replays arrive through the SAME replay_data chunk handler above
  // (keyed by a filename-derived match_id), so only status/tuning need wires.
  let _adminTraining = null;      // last admin_training_status payload
  let _adminTuning = null;        // last bot_tuning.json dict (server truth)
  let _adminTuningDraft = null;   // in-progress textarea edit (survives re-renders/tab switches)
  let _adminTuningPending = null; // parsed payload sent with the last Save, promoted to truth on ack
  S.net.on("admin_training_status", (m) => { _adminTraining = m; renderAdminTrainingBody(); });
  S.net.on("admin_bot_tuning", (m) => { _adminTuning = (m && m.tuning) || null; renderAdminTrainingBody(); });
  S.net.on("admin_bot_tuning_saved", () => {
    if (_adminTuningPending) _adminTuning = _adminTuningPending;   // Save succeeded: pending payload IS the file now
    _adminTuningPending = null;
    _adminTuningDraft = null;                                      // draft is committed — editor shows server truth again
    renderAdminTrainingBody();
    showToast("Bot tuning saved — live bots hot-reload it", "info");
  });
  // spectate_init: the server accepted the watch request and shipped the same snapshot-based
  // package as receive_session_reconnect ({"info": json}), plus both players' display blobs.
  // canonical_role 0 = the camera sits on p1's side; S.viewer disables all interactivity.
  S.net.on("spectate_init", (m) => {
    let info; try { info = typeof m.info === "string" ? JSON.parse(m.info) : m.info; } catch { return; }
    const snap = info && info.snapshot;
    if (!snap || !snap.sides) return;
    S.viewer = { mode: "spectate", p1_display: info.p1 || null, p2_display: info.p2 || null };
    S.prevHp = {};
    set({
      screen: "battle",
      match: { opponent: info.p2 || { username: "?" }, first_turn: false, seed: 0, canonical_role: 0, kind: "spectate", apBefore: 0, streakBefore: 0 },
      snapshot: ingestSnapshot(snap),
      staged: [], execOrder: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, exchangeSetup: null, randomModal: false, targeting: null, acting: false,
      matchResult: snap.match_over ? { won: null } : null,
      railgunPlayed: true, mineBladePlayed: true,   // never replay the one-shot VFX for a match joined mid-way
      queued: false, confirmSurrender: false, oppGone: false, msg: "",
    });
  });
  S.net.on("spectate_result", (m) => {
    if (m && !m.ok) {
      showToast(m.note, "err");
      // Mid-view rejection = we were EVICTED (e.g. the player tightened allow_spectators). Exit the
      // viewer without re-sending spectate_leave (the server already detached us).
      if (S.viewer && S.viewer.mode === "spectate") { S.viewer = null; returnToMenu(); }
    }
  });

  // ---- reconnect -----------------------------------------------------------
  // Mobile tabs get backgrounded → the socket drops. The server holds the match
  // for 120s (RECONNECT_TIMEOUT); we reconnect + silently re-login within that
  // window, and the server replays the live snapshot (receive_session_reconnect).
  function finishReconnect(patch) {
    clearTimeout(S._rcTimer); clearTimeout(S._rcGiveUp);
    set(Object.assign({ reconnecting: false }, patch));
  }
  async function attemptReconnect() {
    if (S.reconnecting || !S.creds) return;
    set({ reconnecting: true });
    clearTimeout(S._rcGiveUp);
    S._rcGiveUp = setTimeout(() => {   // safety net, kept under the server's 120s grace
      if (S.reconnecting) finishReconnect({ screen: "login", creds: null, msg: "Could not reconnect — log in again", msgKind: "err" });
    }, 112000);
    let delay = 500;                   // small first delay lets the server reap the dead peer (avoids Case-B reject)
    while (S.reconnecting) {
      let opened = false;
      try { if (S.conn !== "connected") await S.net.connect(S.creds.url); opened = true; }
      catch { opened = false; }
      if (!S.reconnecting) return;
      if (opened) {
        S.net.send("login", { username: S.creds.user, password: S.creds.pass });
        log("out", "reconnect login " + S.creds.user);
        return;                        // resolution comes via the login/reconnect handlers; _rcGiveUp is the backstop
      }
      await new Promise((r) => setTimeout(r, delay));
      delay = Math.min(delay * 2, 8000);
    }
  }
  function nudgeReconnect() {
    // Only the EJECTED phase owns the socket. During a warning play continues, so the ordinary
    // visibilitychange/online nudges must keep working or a backgrounded tab never recovers.
    if (S.maint && S.maint.phase !== "warn") { startMaintPoll(); return; }
    if (S.creds && S.screen !== "login" && S.conn !== "connected" && !S.reconnecting) attemptReconnect();
  }
  S.net.on("_close", () => {
    // The socket dying while we are waiting for an update IS the restart beginning. Hand off to the
    // maintenance poller instead of the normal reconnect-and-relogin path, which would only bounce
    // off the login lock.
    if (S.maint && S.maint.phase === "ejected") { startMaintPoll(); return; }
    if (S.creds && S.screen !== "login" && !S.reconnecting) attemptReconnect();
  });

  // ---- maintenance: eject, wait for the new server, reload -------------------
  // Drop everything and sit on the login screen. Creds are kept in memory only so a cancelled
  // update leaves the player able to log straight back in; the reconnect loop is stopped outright.
  function leaveForMaintenance() {
    S.reconnecting = false;
    clearTimeout(S._rcGiveUp);
    // Same teardown returnToMenu does: an armed turn watchdog would otherwise fire minutes later and
    // print "the server stopped responding" across the maintenance panel.
    clearTurnWatchdog();
    S.acting = false;
    S.queued = false;
    S.match = null; S.snapshot = null; S.staged = []; S.viewer = null;
    S.socialDockEnabled = false;
    renderMaintBanner();
    set({ screen: "login", msg: "", msgKind: "" });
    // Drop the socket so the server can reap the session. Kept open, that session stays ONLINE and
    // a later Cancel Update could not let the player back in — their own stale session would reject
    // the re-login. _close then hands straight off to the poller.
    try { S.net.close(); } catch (e) {}
    startMaintPoll();
  }
  let _maintTimer = null, _maintBusy = false;
  function stopMaintPoll() { if (_maintTimer) { clearInterval(_maintTimer); _maintTimer = null; } }
  // Poll the socket back open, then ASK who is answering. A successful connect on its own is not
  // proof of a restart — the old server may simply not have died yet — so the boot_id comparison in
  // the server_status handler is what actually decides.
  function startMaintPoll() {
    if (_maintTimer || !S.maint || S.maint.phase !== "ejected") return;
    const tick = async () => {
      if (_maintBusy || !S.maint || S.maint.phase !== "ejected") return;
      _maintBusy = true;
      try {
        if (S.conn !== "connected") await S.net.connect(defaultServerUrl());
        S.net.send("server_status", {});
      } catch (e) { /* still down — try again on the next tick */ }
      _maintBusy = false;
    };
    _maintTimer = setInterval(tick, 3000);
    tick();
  }
  // The page is still running the PREVIOUS frontend, so a state change is not enough — only a real
  // document reload picks up the new app.js/style.css. index.html cache-busts its own assets per
  // load, but the HTML itself can be cached, so go through a fresh URL to be certain.
  function bustedReload() {
    try {
      const qs = new URLSearchParams(location.search);
      qs.set("u", String(Date.now()));
      location.replace(location.origin + location.pathname + "?" + qs.toString() + location.hash);
    } catch (e) { location.reload(); }
  }
  function maintenanceReload() {
    stopMaintPoll();
    S.maint.phase = "back";
    renderMaintBanner();
    set({ msg: "Update complete — reloading…", msgKind: "ok" });
    setTimeout(bustedReload, 1200);
  }
  if (typeof document !== "undefined")
    document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") nudgeReconnect(); });
  if (typeof window !== "undefined") window.addEventListener("online", nudgeReconnect);

  // ---- actions -------------------------------------------------------------
  // "Keep me logged in" persistence. NOTE: stores the raw password in localStorage (same
  // password already held in memory for reconnect) — acceptable for this game, but a server
  // session token would be the hardened version since the password sits on disk.
  function loadSavedLogin() {
    try { const s = JSON.parse(localStorage.getItem("aa_login") || "null"); return (s && s.user && s.pass) ? s : null; } catch (e) { return null; }
  }
  function saveSavedLogin(user, pass) { try { localStorage.setItem("aa_login", JSON.stringify({ user: user, pass: pass })); } catch (e) {} }
  function clearSavedLogin() { try { localStorage.removeItem("aa_login"); } catch (e) {} }
  async function doLogin(url, user, pass, remember) {
    set({ msg: "Connecting…", msgKind: "" });
    try {
      if (S.conn !== "connected") await S.net.connect(url);
    } catch { set({ msg: "Could not connect to the server", msgKind: "err" }); return; }
    S.username = user;
    S.creds = { url, user, pass };   // kept in memory for silent reconnect re-login
    if (remember) saveSavedLogin(user, pass); else clearSavedLogin();
    S.net.send("login", { username: user, password: pass });
    log("out", "login " + user);
    set({ msg: "Authenticating…" });
  }
  async function doRegister(url, user, pass, remember) {
    if (!user || !pass) { set({ msg: "Enter a username and password to register", msgKind: "err" }); return; }
    set({ msg: "Connecting…", msgKind: "" });
    try {
      if (S.conn !== "connected") await S.net.connect(url);
    } catch { set({ msg: "Could not connect to the server", msgKind: "err" }); return; }
    S._regCreds = { url: url, user: user, pass: pass, remember: !!remember };   // used to auto-login on a successful register
    S.net.send("register", { username: user, password: pass });
    log("out", "register " + user);
    set({ msg: "Creating account…" });
  }
  function changePassword(current, newPass) {
    S._pwChange = { newPass: newPass };   // applied to the stored creds once the server confirms
    S.net.send("change_password", { current: current, new: newPass });
    log("out", "change_password");
    set({ msg: "Updating password…", msgKind: "" });
  }
  // Toga's passive lets her start a match disguised as another character. The disguise rides
  // along as an optional 4th element in the queue payload (the server reads index 3 in
  // match.gd _apply_disguise). Only appended when Toga is actually on the team.
  function queueTeamPayload() {
    const team = S.team.slice();
    if (team.includes("toga") && S.disguise && S.disguise !== "toga") team.push(S.disguise);
    // Jin-woo's equipped summon rides as a self-describing "form:<color>" token AFTER any disguise —
    // the server reads it in Match._apply_jinwoo_form (never recruited; recruit stops at 3).
    if (team.includes("jinwoo") && S.jinwooForm) team.push("form:" + S.jinwooForm);
    return team;
  }
  function queueQuick() {
    if (S.team.length !== 3) { set({ msg: "Pick exactly 3 characters", msgKind: "err" }); return; }
    S.net.send("queue_quick", { characters: queueTeamPayload() });
    log("out", "queue_quick " + S.team.join(","));
    set({ queued: true, msg: "In queue — waiting for an opponent…", msgKind: "" });
  }
  // Immediate bot game (no queue / fallback wait) for players who specifically want to fight a bot.
  function queueBot() {
    if (S.team.length !== 3) { set({ msg: "Pick exactly 3 characters", msgKind: "err" }); return; }
    S.net.send("queue_bot", { characters: queueTeamPayload() });
    log("out", "queue_bot " + S.team.join(","));
    set({ msg: "Starting a bot match…", msgKind: "" });   // the match arrives immediately via receive_quick_match
  }
  // A character is selectable if it's a starter (gate "always") or the player owns
  // its unlock token / "all_unlock" — mirrors character_component.unlocked(player).
  function charUnlocked(c) {
    if (!c.gate || c.gate === "always") return true;
    const unlocks = (S.player && S.player.unlocks) || [];
    return unlocks.includes(c.gate) || unlocks.includes("all_unlock");
  }
  // The last equipped team is persisted server-side as player.characters (the save_cosmetics blob).
  // Keep the live selection S.team and S.player.characters in lockstep: restore the selection on
  // login so a refresh doesn't wipe it, and push every change back so a later cosmetic save can't
  // overwrite the team with a stale roster.
  function teamFromPlayer(player) {
    const c = player && player.characters;
    return Array.isArray(c) ? c.filter((x) => typeof x === "string" && x).slice(0, 3) : [];
  }
  function persistTeam() {
    if (!S.player) return;
    S.player.characters = S.team.slice();
    saveCosmetics();
  }
  // Named saved teams, stored per-account in localStorage (this browser only). [{name, characters}]
  function savedTeamsKey() { return "aa_teams_" + ((S.player && S.player.username) || S.username || "guest"); }
  function loadSavedTeamsList() {
    try { const a = JSON.parse(localStorage.getItem(savedTeamsKey()) || "[]"); return Array.isArray(a) ? a : []; } catch (e) { return []; }
  }
  function writeSavedTeams(arr) { try { localStorage.setItem(savedTeamsKey(), JSON.stringify(arr)); } catch (e) {} }
  function saveCurrentTeam(name) {
    const list = loadSavedTeamsList().filter((t) => t.name !== name);   // same name overwrites
    // Store the pre-match selections alongside the roster so loading the team restores them too.
    list.push({ name: name, characters: S.team.slice(), disguise: S.disguise || "", jinwooForm: S.jinwooForm || "" });
    writeSavedTeams(list);
  }
  function loadSavedTeam(idx) {
    const t = loadSavedTeamsList()[idx];
    if (!t) return;
    const roster = S.roster || [];
    let chars = (t.characters || []).slice(0, 3);
    if (roster.length) chars = chars.filter((pn) => findSelectChar(pn));   // drop characters that are no longer on the roster
    S.team = chars;
    persistTeam();
    // Restore this team's saved pre-match selections (older entries lack these → default to none).
    S.disguise = t.disguise || ""; S.jinwooForm = t.jinwooForm || "";
    savePrematch();
    set({ msg: 'Loaded team "' + t.name + '"', msgKind: "ok" });
  }
  function deleteSavedTeam(idx) { const list = loadSavedTeamsList(); list.splice(idx, 1); writeSavedTeams(list); }
  // Pre-match per-character selections (Toga's disguise, Jin-woo's summon form) persist per-account in
  // localStorage so a refresh or re-login doesn't forget them. The team itself round-trips through the
  // server, but these are browser-scoped UI choices like the named saved teams above. They're re-sent in
  // queueTeamPayload every match, so a stale value is harmless — only applied when its character is present.
  function prematchKey(u) { return "aa_prematch_" + (u || (S.player && S.player.username) || S.username || "guest"); }
  function loadPrematch(u) {
    try { const d = JSON.parse(localStorage.getItem(prematchKey(u)) || "{}"); return { disguise: (d && d.disguise) || "", jinwooForm: (d && d.jinwooForm) || "" }; }
    catch (e) { return { disguise: "", jinwooForm: "" }; }
  }
  function savePrematch() { try { localStorage.setItem(prematchKey(), JSON.stringify({ disguise: S.disguise || "", jinwooForm: S.jinwooForm || "" })); } catch (e) {} }
  // Apply a disguise/form change AND persist it, so it survives a refresh or re-login.
  function commitPrematch(patch) { set(patch); savePrematch(); }
  function toggleChar(pn) {
    const c = (S.roster || []).find((x) => x.path_name === pn);
    if (c && !charUnlocked(c)) return;                 // can't pick a locked character
    const i = S.team.indexOf(pn);
    if (i >= 0) S.team.splice(i, 1);
    else if (S.team.length < 3) S.team.push(pn);
    else { set({ msg: "Team is full — remove one first", msgKind: "err" }); return; }
    persistTeam();
    set({ msg: "" });
  }
  function titleName(pn) {
    const c = (S.roster || []).find((x) => x.path_name === pn);
    return c ? c.name : titleCase(pn);
  }
  // Char-select character lookup by path_name.
  function findSelectChar(pn) {
    return (S.roster || []).find((r) => r.path_name === pn) || null;
  }
  // Portraits resolve through a manifest (portraits.json) parsed from the character
  // .tscn files — folder + filename are NOT derivable from path_name (display-name
  // folders; ~15% of defaults aren't "<pn>prof.png"; alts are arbitrary filenames).
  // Mirrors Godot active_portrait(): dead/banished override everything; disguise shows
  // the other character's DEFAULT portrait; portrait_alt indexes that char's alts[].
  function portraitRel(c) {
    if (c.dead) return "dead.png";
    if (c.banished) return "banished.png";
    const man = S.portraits;
    if (!man) return null;
    const entry = man[c.portrait_disguise || c.path_name];
    if (!entry) return null;
    if (!c.portrait_disguise && c.portrait_alt != null && c.portrait_alt >= 0 &&
        entry.alts && entry.alts[c.portrait_alt]) return entry.alts[c.portrait_alt];
    return entry.default || null;
  }
  function relToUrl(rel) {
    return rel ? assetBase() + "/" + rel.split("/").map(encodeURIComponent).join("/") + "?v=" + ASSET_VERSION : null;
  }
  function portraitUrl(c) {
    const rel = portraitRel(c);          // manifest hit (also dead/banished/disguise overrides)
    return rel ? relToUrl(rel) : null;   // a miss renders no <img> — callers fall back to the default avatar
  }
  function portraitUrlFor(pn) {          // default portrait; falls back to char_index for production-roster chars
    const e = S.portraits && S.portraits[pn];
    if (e && e.default) return relToUrl(e.default);
    const ci = S.charIndex && S.charIndex[pn];
    return ci && ci.default ? relToUrl(ci.default) : null;
  }
  // Emotion-tagged portrait: "<path_name>_portrait_<emotion>.png" lives in the SAME display-name
  // folder as the default (the folder isn't derivable from path_name, so take it from the manifest's
  // default path). Emotions: happy | serious | shocked. Returns null if we can't resolve a folder;
  // callers fall back to the default portrait (and an <img onerror> swaps to it if the file is absent).
  const PORTRAIT_EMOTIONS = ["happy", "serious", "shocked"];
  function emotionRel(pn, emotion) {
    if (!emotion || !PORTRAIT_EMOTIONS.includes(emotion)) return null;
    const e = (S.portraits && S.portraits[pn]) || (S.charIndex && S.charIndex[pn]);
    if (!e || !e.default) return null;
    const slash = e.default.lastIndexOf("/");
    const folder = slash >= 0 ? e.default.slice(0, slash) : "";
    return (folder ? folder + "/" : "") + pn + "_portrait_" + emotion + ".png";
  }
  function portraitUrlForEmotion(pn, emotion) {
    return relToUrl(emotionRel(pn, emotion)) || portraitUrlFor(pn);
  }
  // Display name for any character: dev roster → full production index → Title-cased path.
  function nameFor(pn) {
    const c = (S.roster || []).find((r) => r.path_name === pn);
    if (c) return c.name;
    const ci = S.charIndex && S.charIndex[pn];
    return (ci && ci.name) || titleCase(pn);
  }
  function loadCharIndex() {
    if (S.charIndex) return;
    fetch("char_index.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ charIndex: m })).catch(() => {});
  }
  function loadPortraits() {
    if (S.portraits) return;
    fetch("portraits.json" + DATA_BUST).then((r) => r.json()).then((man) => set({ portraits: man })).catch(() => {});
  }
  // Ability icons: source_basename -> "Folder/file.png" (from abilities_data.json image_path).
  function abilityIconUrl(basename) {
    const rel = S.abilityIcons && basename && S.abilityIcons[basename];
    return rel ? relToUrl(rel) : null;
  }
  // Icon for ONE wire ability entry. Every battle-side icon goes through here.
  function wireAbilityIcon(ab) {
    return ab ? abilityIconUrl(ab.source_basename) : null;
  }
  // Battle snapshots carry source_basename = the ability's SCRIPT basename. The server's
  // comment assumes that equals the JSON key, but a few abilities have a reassigned script
  // (e.g. Saitama's key "saitama2" lives in saitama5.gd), so script basename != key. Since
  // the client keys icon/description/info off the JSON key, look the real key up via the
  // alias map (script basename -> key, generated from abilities_data.json). Identity for
  // the common case where they match.
  function resolveAbilityKey(bn) { return (S.abilityAliases && S.abilityAliases[bn]) || bn; }
  // Normalize a freshly-received wire snapshot IN PLACE: rewrite each ability's
  // source_basename to its canonical JSON key, so every downstream display lookup (icon,
  // description, cooldown, full-kit matching) resolves the right ability. source_basename is
  // a pure client display field (never sent back to the server), so this rewrite is safe.
  // Each snapshot is ingested exactly once, so the non-idempotent alias map is never re-applied.
  function ingestSnapshot(snap) {
    if (snap && snap.sides) {
      for (const side of snap.sides) for (const ch of (side.team || [])) for (const a of (ch.abilities || [])) {
        if (a && a.source_basename) a.source_basename = resolveAbilityKey(a.source_basename);
      }
    }
    return snap;
  }
  // A res:// path (e.g. an effect's icon_path) -> servable URL. The asset root is
  // assetBase() minus its trailing /assets/images (works for the same-origin default,
  // a CDN, or the dev repo-root server).
  function resToUrl(resPath) {
    if (!resPath || resPath.indexOf("res://") !== 0) return null;
    const root = assetBase().replace(/\/assets\/images\/?$/, "");
    return root + "/" + resPath.slice(6).split("/").map(encodeURIComponent).join("/") + "?v=" + ASSET_VERSION;
  }
  // An avatar can arrive as an uploaded http(s) URL (real players) OR as a res:// path into the
  // bundled avatar set (server-side bots, which have no upload to point at). Resolve the res:// form
  // instead of handing it to <img src> raw, where it would simply 404 into the onerror fallback.
  const DEFAULT_AVATAR = "res://assets/avatars/toko_toda.png";
  function avatarSrc(url) {
    if (url && url.indexOf("res://") === 0) return resToUrl(url);
    return url || resToUrl(DEFAULT_AVATAR);
  }
  // Sound effects — ported from the retired Godot client: the same clips and the same triggers (UI
  // click/hover, character/action select, my-turn chime, battle-start notify). No music, matching the
  // Godot client. Playback is gated by mute (the volume row's speaker toggle, client-local + persisted)
  // and scaled by the client master volume (persisted; default below). A plain HTML5 Audio pool (clone
  // per play so rapid repeats overlap); the first user gesture unlocks autoplay.
  const SFX_DEFAULT_VOLUME = 0.375;   // 25% below the old fixed 0.5 — quieter by default
  let _sfxVolume = SFX_DEFAULT_VOLUME, _sfxMuted = false;
  try {
    const _sv = parseFloat(localStorage.getItem("aa_sfx_vol"));
    if (isFinite(_sv)) _sfxVolume = Math.max(0, Math.min(1, _sv));   // ignore missing/corrupt (NaN would break audio)
    _sfxMuted = localStorage.getItem("aa_sfx_muted") === "1";
  } catch (e) {}
  function saveSfxPrefs() { try { localStorage.setItem("aa_sfx_vol", String(_sfxVolume)); localStorage.setItem("aa_sfx_muted", _sfxMuted ? "1" : "0"); } catch (e) {} }
  const SFX = {
    _cache: {},
    _map: {
      click: "ability_click",         // UI / button / ability-button press
      hover: "soft_click",            // button hover
      select: "champ_select",         // character pick / action confirm ("big_click"/"character_click")
      undo: "undo_click",             // cancel / deselect
      turn: "myturn",                 // my-turn chime
      notify: "sharp_notification",   // battle start / match found
    },
    muted() { return _sfxMuted; },
    preload() {
      for (const k in this._map) {
        try { const a = new Audio(resToUrl("res://assets/sounds/" + this._map[k] + ".mp3")); a.preload = "auto"; this._cache[k] = a; } catch (e) {}
      }
    },
    play(name) {
      if (this.muted()) return;
      const base = this._cache[name];
      if (!base) return;
      try { const a = base.cloneNode(); a.volume = _sfxVolume; const p = a.play(); if (p && p.catch) p.catch(() => {}); } catch (e) {}
    },
  };
  let _sfxWasMyTurn = null;   // battle turn-chime edge detector (null = fresh match; see onMatch + apply_turn_result)
  function loadAbilityIcons() {
    if (S.abilityIcons) return;
    fetch("ability_icons.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ abilityIcons: m })).catch(() => {});
  }
  function loadAbilityInfo() {
    if (S.abilityInfo) return;
    fetch("ability_info.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ abilityInfo: m })).catch(() => {});
    fetch("skill_glossary.json" + DATA_BUST).then((r) => r.json()).then((m) => { GK.build(m); set({ glossary: m }); }).catch(() => {});
  }
  function loadAbilityAliases() {
    if (S.abilityAliases) return;
    fetch("ability_aliases.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ abilityAliases: m })).catch(() => set({ abilityAliases: {} }));
  }
  function loadRoster() {
    if (S.roster) return;
    fetch("roster.json" + DATA_BUST).then((r) => r.json()).then((list) => set({ roster: list }))
      .catch(() => set({ roster: [], msg: "Could not load roster.json", msgKind: "err" }));
  }
  // Roster sorted by DISPLAY NAME for the full-character list UIs (mastery / cosmetics / bounties),
  // so a character appended to roster.json slots into alphabetical place instead of the end. Returns
  // a COPY — S.roster is left in roster.json order (gridArea's CHAR_SELECT_RANK sort depends on that).
  function rosterByName() {
    return (S.roster || []).slice().sort((a, b) =>
      (a.name || "").localeCompare(b.name || "", undefined, { sensitivity: "base" })
      || (a.path_name || "").localeCompare(b.path_name || ""));
  }
  function loadTitles() {
    if (S.titles) return;
    fetch("titles.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ titles: m })).catch(() => {});
  }
  function loadBountyData() {
    if (S.bountyData) return;
    fetch("bounty_data.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ bountyData: m })).catch(() => {});
  }
  function loadShopCatalog() {
    if (S.shopCatalog) return;
    fetch("shop_catalog.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ shopCatalog: m })).catch(() => {});
  }
  // Searchable text for a character's skills (name + description + classes), so the grid
  // search matches ability content, not just the character. Memoized per character — the
  // ability info is static once loaded; returns "" (uncached) until it lands.
  let _abSearch = {};
  function charAbilitySearchText(pathName) {
    if (!S.abilityInfo) return "";
    if (_abSearch[pathName] != null) return _abSearch[pathName];
    const text = charAbilities(pathName).map((bn) => {
      const info = S.abilityInfo[bn] || {};
      let parts = [info.name || "", info.description || ""];
      if (info.desc && info.desc.length) parts = parts.concat(info.desc.map((s) => s.text || ""));
      if (info.classes && info.classes.length) parts = parts.concat(info.classes);
      return parts.join(" ");
    }).join(" ").toLowerCase();
    _abSearch[pathName] = text;
    return text;
  }
  function applyCharFilter(grid, q) {
    q = (q || "").toLowerCase();
    grid.querySelectorAll(".mg-cell").forEach((cell) => {
      cell.style.display = (!q || (cell.dataset.search || "").includes(q)) ? "" : "none";
    });
  }
  function cancelQueue() {
    S.net.send("cancel_queue", {});
    log("out", "cancel_queue");
    set({ queued: false, privateTarget: null, msg: "Left queue", msgKind: "" });
  }
  // Private match: a mutual invite. You enter your opponent's username; the server pairs you when
  // BOTH of you have invited each other (server_connection.receive_private_match_queue).
  function queuePrivate(target) {
    target = (target || "").trim();
    if (S.team.length !== 3) { set({ msg: "Pick exactly 3 characters", msgKind: "err" }); return; }
    if (!target) { set({ msg: "Enter your opponent's username", msgKind: "err" }); return; }
    // Immediate feedback only — the server rejects this too (receive_private_match_queue), and that
    // check is the authoritative one. Inviting yourself used to file an invite under your own name
    // and pair you against yourself on the second send.
    if (S.player && target === S.player.username) { set({ msg: "You can't challenge yourself", msgKind: "err" }); return; }
    S.net.send("queue_private", { characters: queueTeamPayload(), target_username: target });
    log("out", "queue_private " + target);
    set({ queued: true, privateTarget: target, privatePrompt: null, msg: "", msgKind: "" });
  }

  // ---- turn building -------------------------------------------------------
  function myRoleStr() { return S.match.canonical_role === 0 ? "p1" : "p2"; }
  function isMyTurn() {
    const snap = S.snapshot;
    if (!snap || !S.match) return false;
    return snap.acting_role === myRoleStr();
  }
  function abCost(cost, k) { return (cost && (cost[k] != null ? cost[k] : cost[String(k)])) || 0; }

  // --- turn-level energy model ------------------------------------------------
  // Staged actions carry their ability `cost` ({0..3 specific, 4 RANDOM}). Specific
  // pips are fixed per color; the turn's RANDOM pips are pooled and assigned to colors
  // via S.randomAssign (auto-filled greedily, then adjustable in the energy panel).
  function myPool() {
    const snap = S.snapshot;
    const side = snap.sides.find((s) => s.role === myRoleStr()) || snap.sides[0];
    const pool = (side.energy && side.energy.pool) || {};
    const p = {};
    for (let c = 0; c < 4; c++) p[c] = Number(pool[c] != null ? pool[c] : pool[String(c)]) || 0;
    // Fold in the pending 2-for-1 exchange (give -offer, get +1) so the panel,
    // affordability, and random allocation all see the post-trade pool — the server
    // applies the exchange before paying abilities, so a trade can fund a same-turn one.
    const ex = S.exchange;
    if (ex) {
      for (const k in ex.offer) p[Number(k)] = (p[Number(k)] || 0) - ex.offer[k];
      p[ex.request] = (p[ex.request] || 0) + 1;
    }
    return p;
  }
  function specificTotals() {
    const t = { 0: 0, 1: 0, 2: 0, 3: 0 };
    for (const a of S.staged) for (let c = 0; c < 4; c++) t[c] += abCost(a.cost, c);
    return t;
  }
  function randomTotal() { let r = 0; for (const a of S.staged) r += abCost(a.cost, 4); return r; }
  function randomAssigned() { const a = S.randomAssign; return (a[0] || 0) + (a[1] || 0) + (a[2] || 0) + (a[3] || 0); }
  function unassignedRandom() { return randomTotal() - randomAssigned(); }
  // Energy left this turn = pool - specific costs - assigned random.
  function remainingPool() {
    const pool = myPool(), spec = specificTotals(), a = S.randomAssign;
    const rem = {};
    for (let c = 0; c < 4; c++) rem[c] = pool[c] - spec[c] - (a[c] || 0);
    return rem;
  }
  // Can this ability join the turn? Specific pips must fit per color, and the total
  // random (existing + this ability's) must fit in the leftover capacity.
  function canAddAbility(ability) {
    const pool = myPool(), spec = specificTotals();
    let cap = 0;
    for (let c = 0; c < 4; c++) {
      const need = spec[c] + abCost(ability.cost, c);
      if (need > pool[c]) return false;
      cap += pool[c] - need;
    }
    return cap >= randomTotal() + abCost(ability.cost, 4);
  }
  // Keep the manual RANDOM assignment valid after a change (stage/unstage/exchange):
  // clamp each color to its current capacity and trim the total to the pips actually
  // needed. Never auto-fills — the player places every RANDOM pip themselves.
  function reconcileRandomAssign() {
    const pool = myPool(), spec = specificTotals(), a = S.randomAssign;
    for (let c = 0; c < 4; c++) a[c] = Math.max(0, Math.min(a[c] || 0, pool[c] - spec[c]));
    let over = (a[0] + a[1] + a[2] + a[3]) - randomTotal();
    for (let c = 3; c >= 0 && over > 0; c--) { const cut = Math.min(over, a[c]); a[c] -= cut; over -= cut; }
  }
  function adjustRandom(c, delta) {
    const pool = myPool(), spec = specificTotals(), a = S.randomAssign;
    if (delta > 0) {
      if (unassignedRandom() <= 0 || (a[c] || 0) >= pool[c] - spec[c]) return;
      a[c] = (a[c] || 0) + 1;
    } else {
      if ((a[c] || 0) <= 0) return;
      a[c]--;
    }
    set({ msg: "" });
  }

  // --- energy exchange (2-for-1 color conversion) -----------------------------
  // Port of can_exchange(): offerable only when some color has >=2 free this turn.
  // (No promised_pool on the web side; one exchange per turn.) S.exchange folds into
  // myPool() above, so a trade is reflected immediately and can fund a same-turn ability.
  function canExchange() {
    if (S.exchange) return false;
    const rem = remainingPool();                 // base pool minus staged spends (no exchange yet)
    return [0, 1, 2, 3].some((c) => rem[c] >= 2);
  }
  function startExchange() { set({ exchangeSetup: { give: null, get: null } }); }
  function setExchangeGive(c) { if (S.exchangeSetup) { S.exchangeSetup.give = c; set({}); } }
  function setExchangeGet(c) { if (S.exchangeSetup) { S.exchangeSetup.get = c; set({}); } }
  function confirmExchange() {
    const su = S.exchangeSetup;
    if (!su || su.give == null || su.get == null) return;
    S.exchange = { offer: { [su.give]: 2 }, request: su.get };   // give 2, get 1
    reconcileRandomAssign();                     // keep any placed pips valid against the new pool
    set({ exchangeSetup: null, msg: "" });
  }
  function clearExchange() {
    // Undoing the exchange returns the traded energy to the base pool. Any skills queued
    // this turn were allowed to spend that traded color, so if they stayed staged their
    // (now-unbacked) specific cost would drop that color's remaining pool to -1. Per design,
    // cancel every queued skill first, so an exchange undo can never leave the pool negative.
    S.staged = [];
    S.execOrder = null;
    S.randomAssign = { 0: 0, 1: 0, 2: 0, 3: 0 };
    S.targeting = null;
    S.exchange = null;
    S.exchangeSetup = null;
    set({});
  }

  function onAbilityTap(canonChar, abilityIdx, ability) {
    if (!isMyTurn() || S.acting) return;
    if (S.staged.some((a) => a.char_idx === canonChar)) return;        // one action per character
    if (!canAddAbility(ability)) { set({ msg: "Not enough energy for " + ability.ability_name, msgKind: "err" }); return; }
    const st = (ability.special_targets || []).map(Number);            // server-resolved valid target indices (target_type: 0 SINGLE 1 ALL_FACTION 2 ALL 3 COUNT 4 SELF)
    // Never auto-target: always enter target selection so AOE skills highlight
    // their valid targets and self-targets still require clicking the user.
    // No valid targets (e.g. every legal target is currently invulnerable) → refuse, don't
    // auto-stage a target-less action. This mirrors the desktop engine, which only commits an
    // ability when a flagged (.targeted) character is clicked (new_battle_scene.gd:1061); with
    // none flagged the ability is simply uncastable this turn. SELF / ally-buff abilities always
    // flag the caster (default_self_target_function), so a usable one never reaches this branch.
    if (!st.length) { set({ msg: "No valid targets for " + ability.ability_name, msgKind: "err" }); return; }
    set({ targeting: { char_idx: canonChar, ability_idx: abilityIdx, ability_name: ability.ability_name, special_targets: st, target_type: ability.target_type, cost: ability.cost }, msg: "" });
  }
  function pickTarget(canonTarget) {
    const t = S.targeting;
    if (!t || !t.special_targets.includes(canonTarget)) return;
    const tt = t.target_type;
    // THE CLICKED CHARACTER MUST LEAD THE LIST. The server walks target_idxs in order and
    // targeter_component.add_target makes the FIRST one it receives the main_target; nothing
    // downstream re-derives it. Abilities that treat the primary differently from the splash
    // (X-Burner's 25/10, ace3, gojo3, korra7, lizandpatty1/2, ganta3, ...) read exactly that.
    // special_targets arrives in the server's own ascending canonical order, so slicing it
    // wholesale made the lowest-indexed valid target the primary no matter who was clicked.
    var targets;
    if (tt === 2) targets = [canonTarget].concat(t.special_targets.filter((idx) => idx !== canonTarget));                                  // ALL: clicked first, then the rest
    else if (tt === 1) targets = [canonTarget].concat(t.special_targets.filter((idx) => idx !== canonTarget && (idx < 3) === (canonTarget < 3)));  // ALL_FACTION: clicked first, then the rest of that side
    else targets = [canonTarget];                                                                     // SINGLE / COUNT / SELF: just the clicked one
    stage(t.char_idx, t.ability_idx, t.ability_name, targets, t.cost);
  }
  function stage(charIdx, abilityIdx, name, targets, cost) {
    S.staged.push({ char_idx: charIdx, ability_idx: abilityIdx, target_idxs: targets, ability_name: name, cost: cost });
    reconcileRandomAssign();
    set({ targeting: null, msg: "" });
  }
  function unstage(charIdx) { S.staged = S.staged.filter((a) => a.char_idx !== charIdx); reconcileRandomAssign(); set({}); }
  // The turn's ticking-effect steps, baked into the snapshot by the server (authoritative
  // order_ids in the wire frame, >= 6). [{ order_id, label, source_ability_name, icon_path }]
  function tickingPreview() { return (S.snapshot && S.snapshot.execution_preview) || []; }
  // The default execution order shown in the End-Turn modal: staged skills (in click order,
  // order_id = canonical char_idx 0..5) followed by the server's ticking steps (order_id >= 6).
  // Mirrors the engine's turn_end_clicked default (abilities first, then ticking).
  function defaultExecOrder() {
    const skills = S.staged.map((a) => {
      const caster = snapChar(a.char_idx);
      const ab = caster && caster.abilities && caster.abilities[a.ability_idx];
      return {
        order_id: a.char_idx, kind: "skill",
        label: (caster ? titleName(caster.path_name) : "?") + " — " + a.ability_name,
        // Carry the wire entry, not just a resolved URL: this order is BAKED into
        // S.execOrder at End-Turn, so resolving the icon in execTile keeps it correct
        // even if the manifest lands after the modal was built.
        ab: ab || null,
        icon: ab && ab.source_basename ? abilityIconUrl(ab.source_basename) : null,
      };
    });
    const ticks = tickingPreview().map((t) => ({
      order_id: t.order_id, kind: "ticking",
      label: t.label || t.source_ability_name || "Ticking effect",
      icon: t.icon_path ? resToUrl(t.icon_path) : null,
    }));
    return skills.concat(ticks);
  }
  function endTurn() {
    if (S.acting || !S.snapshot) return;
    // Build the execution order (skills + ticking). Open the End-Turn modal when there's
    // random energy to place OR more than one step to (optionally) reorder; else submit now.
    const order = defaultExecOrder();
    S.execOrder = order;
    if (randomTotal() > 0 || order.length > 1) { set({ randomModal: true }); return; }
    submitTurn();
  }
  // The server silently drops a rejected turn (no reply — see _process_turn_input), which
  // would otherwise leave `acting` true forever: End-Turn stays disabled and skills can't be
  // targeted (onAbilityTap early-returns on acting). This watchdog re-enables the UI if no
  // turn result arrives, so a rejection is recoverable. Quick/bot matches resolve in seconds;
  // PvP can run a full turn timer, so wait much longer there before assuming a drop.
  let _turnWatchdog = null;
  function clearTurnWatchdog() { if (_turnWatchdog) { clearTimeout(_turnWatchdog); _turnWatchdog = null; } }
  function armTurnWatchdog() {
    clearTurnWatchdog();
    const ms = (S.match && /quick/i.test(S.match.kind || "")) ? 20000 : 130000;
    _turnWatchdog = setTimeout(() => {
      _turnWatchdog = null;
      if (S.acting) set({ acting: false, msg: "Turn wasn't accepted — check your energy and targets, then try again", msgKind: "err" });
    }, ms);
  }
  function submitTurn() {
    if (S.acting || !S.snapshot) return;
    if (unassignedRandom() > 0) { set({ msg: "Allocate all random energy first", msgKind: "err" }); return; }
    // Affordability guard: an exchange can pull a color below what the staged skills cost
    // (e.g. trading away energy you'd already queued), leaving the pool negative. The server
    // rejects such a turn silently, so block it here with a clear message instead of locking up.
    const rem = remainingPool();
    if (rem[0] < 0 || rem[1] < 0 || rem[2] < 0 || rem[3] < 0) {
      set({ msg: "Not enough energy for this turn — unstage a skill or clear the exchange", msgKind: "err" });
      return;
    }
    // energy_allocation / random_history is the FULL per-color drain for the turn:
    // specific costs + the (auto- or manually-) assigned RANDOM pips, as [[color, count], ...].
    // The server drains the pool solely from this, so it must cover every spend exactly.
    const spec = specificTotals(), assign = S.randomAssign;
    const energy_allocation = [];
    for (let c = 0; c < 4; c++) { const tot = spec[c] + (assign[c] || 0); if (tot > 0) energy_allocation.push([c, tot]); }
    // execution_order = the player-chosen resolution order: skill steps as canonical char_idx
    // (0..5), ticking steps as the server's wire ids (>= 6). Falls back to staged order.
    const order = (S.execOrder && S.execOrder.length) ? S.execOrder.map((o) => o.order_id) : S.staged.map((a) => a.char_idx);
    const input = {
      match_id: 0, turn_number: S.snapshot.current_turn,
      actions: S.staged.map((a) => ({ char_idx: a.char_idx, ability_idx: a.ability_idx, target_idxs: a.target_idxs })),
      execution_order: order,
      energy_allocation: energy_allocation, exchange: S.exchange, timeout: false,
    };
    S.net.send("submit_turn_input", { match_id: 0, input: input });
    log("out", "submit_turn_input (" + S.staged.length + " action" + (S.staged.length === 1 ? "" : "s") + ", energy " + JSON.stringify(energy_allocation) + (S.exchange ? ", exchange " + JSON.stringify(S.exchange) : "") + ")");
    set({ acting: true, randomModal: false, msg: "Submitting turn…" });
    armTurnWatchdog();
  }
  function surrender() {
    if (!S.confirmSurrender) { set({ confirmSurrender: true }); return; }   // two-tap confirm
    S.net.send("surrender", {});
    log("out", "surrender");
    set({ confirmSurrender: false, msg: "Surrendering…" });
  }
  function returnToMenu() {
    clearTurnWatchdog();
    // Defensive viewer teardown — EVERY exit path funnels here, so a stray replay interval or a
    // live spectate subscription can never outlive the battle screen. (viewerExit does the same
    // first and nulls S.viewer, so this never double-sends spectate_leave.)
    clearInterval(_replayTimer); _replayTimer = null;
    if (S.viewer && S.viewer.mode === "spectate") S.net.send("spectate_leave", {});
    S.viewer = null;
    set({ screen: "menu", match: null, snapshot: null, matchResult: null, rankedResult: null, staged: [], execOrder: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, exchangeSetup: null, randomModal: false, targeting: null, queued: false, confirmSurrender: false, oppGone: false, msg: "" });
  }

  // ---- viewer driver: replay playback + spectate exit ----------------------
  // A replay is a frame list: frame 0 = the pre-battle initial snapshot (no events), frame i>0 =
  // turn i's {events, snapshot}. Every frame's snapshot is ingested exactly ONCE here (ingestSnapshot
  // is non-idempotent); stepping just swaps the pre-normalized objects in.
  let _replayTimer = null;   // autoplay interval handle (module-scope so returnToMenu can kill it)
  // Save the currently-open replay to a local .replay file (so it survives the server's retention sweep).
  function downloadReplay() {
    const v = S.viewer, rep = v && v.raw;
    if (!rep) return showToast("Nothing to save", "err");
    try {
      const url = URL.createObjectURL(new Blob([JSON.stringify(rep)], { type: "application/json" }));
      const a = document.createElement("a");
      a.href = url; a.download = (rep.match_id || v.match_id || "replay") + ".replay";
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      showToast("Replay saved to your device", "ok");
    } catch (e) { showToast("Could not save replay", "err"); }
  }
  // Load a locally-saved .replay file and play it back (no server round-trip).
  function loadReplayFromFile() {
    if ((S.match && !S.viewer) || S.screen === "draft") return showToast("Finish your match first", "info");
    const inp = document.createElement("input");
    inp.type = "file"; inp.accept = ".replay,.json,application/json";
    inp.onchange = () => {
      const file = inp.files && inp.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => { let rep; try { rep = JSON.parse(reader.result); } catch (e) { return showToast("Not a valid replay file", "err"); } enterReplay(rep); };
      reader.onerror = () => showToast("Could not read that file", "err");
      reader.readAsText(file);
    };
    inp.click();
  }
  function enterReplay(rep) {
    if (!rep || !rep.initial_snapshot || !rep.initial_snapshot.sides) return showToast("Could not load replay (malformed file)", "err");
    // Pristine copy BEFORE ingestSnapshot mutates snapshots in place (non-idempotent) — this is what Save writes.
    let rawForSave = null; try { rawForSave = JSON.parse(JSON.stringify(rep)); } catch (e) {}
    const frames = [{ events: [], snapshot: rep.initial_snapshot }].concat(rep.turns || []);
    for (const f of frames) ingestSnapshot(f.snapshot);
    // Replays are participants-only: the local player IS one of the two seats. Watch from their side.
    const me = S.player && S.player.username;
    const role = (me === rep.p1_username) ? 0 : 1;
    clearInterval(_replayTimer); _replayTimer = null;
    S.viewer = {
      mode: "replay", frames, idx: 0, playing: false, speed: 1,
      p1_display: rep.p1_display || { username: rep.p1_username },
      p2_display: rep.p2_display || { username: rep.p2_username },
      winner_role: rep.winner_role, finished: frames.length <= 1,
      raw: rawForSave, match_id: rep.match_id,   // for the Save button (download the pristine replay)
    };
    S.prevHp = {};
    set({
      screen: "battle",
      match: { opponent: (role === 0 ? (rep.p2_display || { username: rep.p2_username }) : (rep.p1_display || { username: rep.p1_username })),
               first_turn: false, seed: 0, canonical_role: role, kind: "replay", apBefore: 0, streakBefore: 0 },
      snapshot: frames[0].snapshot,
      staged: [], execOrder: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, exchangeSetup: null, randomModal: false, targeting: null, acting: false,
      matchResult: null, railgunPlayed: false, mineBladePlayed: false,
      queued: false, confirmSurrender: false, oppGone: false, msg: "",
    });
  }
  function replayApplyFrame(i, animate) {
    const v = S.viewer;
    if (!v || v.mode !== "replay" || !v.frames || !v.frames.length) return;
    i = Math.max(0, Math.min(v.frames.length - 1, Math.round(Number(i) || 0)));
    const f = v.frames[i];
    v.idx = i;
    if (animate) maybePlayRailgun(f.events || []);   // BEFORE the snapshot swap — reads the PRE-turn snapshot (same order as the live handler)
    if (animate) maybePlayMineBlade(f.events || []);
    set({ snapshot: f.snapshot, staged: [], execOrder: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, exchangeSetup: null, randomModal: false, targeting: null, acting: false });
    if (animate) playEventAnimations(f.events || []);
    if (i >= v.frames.length - 1) { v.finished = true; replayPause(); }   // replayPause repaints (viewer-bar shows the winner)
  }
  function replayStep(d) { replayApplyFrame((S.viewer ? S.viewer.idx : 0) + d, d > 0); }   // seeking backward = no animations
  function replaySeek(i) { replayApplyFrame(i, false); }
  function replayPlay() {
    const v = S.viewer;
    if (!v || v.mode !== "replay") return;
    v.playing = true;
    clearInterval(_replayTimer);
    _replayTimer = setInterval(() => {
      if (!S.viewer || S.viewer.mode !== "replay" || !S.viewer.playing || S.screen !== "battle") return replayPause();
      if (S.viewer.idx >= S.viewer.frames.length - 1) return replayPause();
      replayStep(1);
    }, 2000 / (v.speed || 1));
    set({});
  }
  function replayPause() {
    if (S.viewer) S.viewer.playing = false;
    clearInterval(_replayTimer); _replayTimer = null;
    set({});
  }
  function replaySetSpeed() {
    const v = S.viewer;
    if (!v || v.mode !== "replay") return;
    const order = [0.5, 1, 2, 4];
    v.speed = order[(order.indexOf(v.speed) + 1) % order.length];   // unknown speed -> indexOf -1 -> cycles to 0.5
    if (v.playing) replayPlay(); else set({});   // restart the interval at the new cadence
  }
  function viewerExit() {
    clearInterval(_replayTimer); _replayTimer = null;
    if (S.viewer && S.viewer.mode === "spectate") S.net.send("spectate_leave", {});
    S.viewer = null;
    returnToMenu();
  }

  // ---- screens -------------------------------------------------------------
  // Community Discord invite. Rendered on the login screen (panel footer) and the character-select
  // topbar. External link → new tab with rel=noopener; the SVG is Discord's brand mark (currentColor
  // so it inherits the pill's white text). innerHTML is a fixed literal — no user input.
  const DISCORD_URL = "https://discord.gg/rRKf9fTge9";
  const DISCORD_SVG = '<svg class="discord-glyph" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path fill="currentColor" d="M20.317 4.3698a19.7913 19.7913 0 0 0-4.8851-1.5152.0741.0741 0 0 0-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2762-3.68-.2762-5.4868 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 0 0-.0785-.037 19.7363 19.7363 0 0 0-4.8852 1.515.0699.0699 0 0 0-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 0 0 .0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 0 0 .0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9942a.076.076 0 0 0-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 0 1-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 0 1 .0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 0 1 .0785.0095c.1202.099.246.1981.3728.2924a.077.077 0 0 1-.0066.1276 12.2986 12.2986 0 0 1-1.873.8914.0766.0766 0 0 0-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 0 0 .0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 0 0 .0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 0 0-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189Z"/></svg>';
  function discordLink(cls, label) {
    const a = el("a", {
      class: "discord-link" + (cls ? " " + cls : ""),
      href: DISCORD_URL, target: "_blank", rel: "noopener noreferrer",
      title: "Join the Anime Arena community on Discord",
    }, []);
    a.innerHTML = DISCORD_SVG + '<span class="discord-label"></span>';
    a.querySelector(".discord-label").textContent = label || "Join our Discord";
    return a;
  }

  function loginScreen() {
    // Ejected for an update: no form at all, so there is nothing to submit into a locked server.
    if (S.maint && S.maint.phase !== "warn") {
      startMaintPoll();
      return el("div", { class: "screen" }, [
        el("div", { class: "title" }, ["Anime Arena ", el("span", { class: "sub" }, ["web client"])]),
        maintenancePanel(),
        el("div", { class: "login-footer" }, [discordLink("login-discord", "Join our Discord")]),
        statusLine(),
      ]);
    }
    let userIn, passIn, rememberIn;
    const saved = loadSavedLogin();   // the deployed client targets the server itself (defaultServerUrl) — no Server field to expose
    const submit = () => doLogin(defaultServerUrl(), userIn.value.trim(), passIn.value, rememberIn.checked);
    const scr = el("div", { class: "screen" }, [
      el("div", { class: "title" }, ["Anime Arena ", el("span", { class: "sub" }, ["web client"])]),
      el("div", { class: "panel" }, [
        field("Username", userIn = el("input", { value: S.username || (saved && saved.user) || "", autocapitalize: "off", autocorrect: "off" })),
        field("Password", passIn = el("input", { type: "password" })),
        el("label", { class: "remember-row" }, [
          rememberIn = el("input", { type: "checkbox", checked: saved ? true : false }),
          el("span", {}, ["Keep me logged in"]),
        ]),
        el("div", { class: "login-actions" }, [
          el("button", { onclick: submit }, ["Log In"]),
          el("button", { class: "secondary", onclick: () => doRegister(defaultServerUrl(), userIn.value.trim(), passIn.value, rememberIn.checked) }, ["Register"]),
        ]),
        el("div", { class: "login-hint" }, ["New here? Pick a username & password, then Register."]),
      ]),
      el("div", { class: "login-footer" }, [discordLink("login-discord", "Join our Discord")]),
      statusLine(),
    ]);
    passIn.addEventListener("keydown", (e) => { if (e.key === "Enter") submit(); });
    return scr;
  }

  // Character-select screen mirroring the game: menu-button row fixed at the TOP, an
  // open MIDDLE area for panels (the character info panel), and a BOTTOM band (<=~33vh)
  // holding the queue buttons above [filter panel | character grid | player info panel].
  function menuScreen() {
    if (S.queued) {
      return el("div", { class: "screen menu", style: bgStyle((S.player || {}).charselect_background) }, [
        menuTopbar(),
        el("div", { class: "menu-middle" }, [el("div", { class: "menu-searching" }, [
          el("div", { class: "note" }, [(S.privateTarget
            ? "Waiting for " + S.privateTarget + " to invite you back…"
            : "Searching for an opponent…") + "  (" + S.team.map(titleName).join(", ") + ")"]),
          el("button", { class: "secondary", onclick: cancelQueue }, ["Cancel"]),
        ])]),
        statusLine(),
      ]);
    }
    return el("div", { class: "screen menu", style: bgStyle((S.player || {}).charselect_background) }, [
      menuTopbar(),
      el("div", { class: "menu-middle" }, [menuInfoPanel()]),
      el("div", { class: "menu-bottom" }, [
        menuQueueRow(),
        el("div", { class: "menu-main" }, [filterPanel(), gridArea(), playerPanel()]),
      ]),
      statusLine(),
    ]);
  }

  // Top menu buttons — stubs for now (textures + target menus to be supplied later).
  const TOP_MENUS = ["Profile", "Titles", "Bounties", "Cosmetics", "Shop", "Nexus", "Mastery", "Clan", "Social", "Settings", "Ladder"];
  const TOP_OVERLAYS = { Profile: "profile", Mastery: "mastery", Cosmetics: "cosmetics", Nexus: "nexus", Titles: "titles", Settings: "settings", Ladder: "ladder", Bounties: "bounties", Shop: "shop", Clan: "clan", Social: "social" };
  function openMenuOverlay(o) {
    if (o === "nexus") S.net.send("nexus_state", {});   // fetch fresh bucket snapshot on open
    if (o === "ladder") S.net.send("ladder", {});       // fetch fresh ranked ladder on open
    if (o === "titles") { loadTitles(); S.titleEdit = (((S.player && S.player.title) || "").split(" ").filter(Boolean)); }
    if (o === "bounties") { loadBountyData(); S.bountySel = null; S.btySearch = ""; }   // fresh, unfiltered list each open
    if (o === "shop") { loadShopCatalog(); S.shopBuy = null; }
    if (o === "clan") { S.net.send("clan_state", {}); S.clanSearchResults = null; _clanDisbandArm = false; _clanResetRecordArm = false; }   // fetch my clan / pending offers; disarm stale guards
    if (o === "social") { S.net.send("social_state", {}); _socialRemoveArm = {}; }   // fetch friends/requests/ignore; disarm stale per-username remove guards
    if (o === "profile") { S.profileQuery = ""; _profileResetArm = false; S.net.send("get_player_profile", { username: (S.player || {}).username }); }   // default to your own profile; disarm any stale reset guard
    set({ menuOverlay: o, msg: "" });
  }
  function menuTopbar() {
    const btns = TOP_MENUS.map((m) => {
      const overlay = TOP_OVERLAYS[m] || null;
      // Social carries BOTH pending friend requests and unread DMs: a DM is the thing a player
      // most wants to be told about, and the Social panel is where they answer it.
      const pending = m === "Social"
        ? ((S.social ? S.social.requests_in.length : 0) + chatDmUnread())
        : 0;
      const kids = [m, m === "Social" ? badgeChip(pending) : null];
      return el("button", { class: "menu-btn" + (pending > 0 ? " has-notify" : ""),
        onclick: overlay ? () => openMenuOverlay(overlay) : () => set({ msg: m + " — coming soon", msgKind: "" }) }, kids);
    });
    btns.push(el("button", { class: "menu-btn", onclick: () => set({ glossaryOpen: true, glossQuery: "" }) }, ["Glossary"]));   // term reference; also reachable in-battle
    btns.push(discordLink("topbar-discord", "Discord"));   // community invite, styled distinct from the game menus
    return el("div", { class: "menu-topbar" }, btns);
  }
  // Glossary modal — a searchable, category-grouped reference for every hover term (statuses, classes,
  // damage/energy types, mechanics, general terms). Opened from the char-select topbar and the in-battle
  // controls (S.glossaryOpen), so it renders on any screen. Colors reuse the GK category vars.
  function closeGlossary() { set({ glossaryOpen: false }); }
  const GLOSS_CATS = ["class", "damage_type", "energy", "status", "mechanic", "term"];
  function glossaryModal() {
    const dismiss = (e) => { if (e.target.classList.contains("modal-overlay")) closeGlossary(); };
    const g = S.glossary;
    if (!g || !g.terms) {
      return el("div", { class: "modal-overlay", onclick: dismiss }, [el("div", { class: "gloss-modal" }, [el("div", { class: "note" }, ["Loading glossary…"])])]);
    }
    const q = (S.glossQuery || "").trim().toLowerCase();
    const match = (t) => !q || ((t.display || "") + " " + t.term + " " + (t.aliases || []).join(" ") + " " + t.definition).toLowerCase().indexOf(q) >= 0;
    const all = Object.values(g.terms);
    let shown = 0;
    const sections = GLOSS_CATS.map((cat) => {
      const items = all.filter((t) => t.category === cat && match(t)).sort((a, b) => (a.display || a.term).localeCompare(b.display || b.term));
      if (!items.length) return null;
      shown += items.length;
      const label = (g.categories[cat] && g.categories[cat].label) || cat;
      return el("div", { class: "gloss-cat" }, [
        el("div", { class: "gloss-cat-h gk-cat-" + cat }, [label, el("span", { class: "gloss-cat-n" }, [String(items.length)])]),
        el("div", { class: "gloss-rows" }, items.map((t) => el("div", { class: "gloss-row" }, [
          el("div", { class: "gloss-term gk-" + cat }, [t.display || t.term]),
          el("div", { class: "gloss-def" }, [t.definition]),
        ]))),
      ]);
    }).filter(Boolean);
    const body = sections.length ? sections : [el("div", { class: "note gloss-empty" }, ["No terms match “" + (S.glossQuery || "") + "”."])];
    const search = el("input", { class: "gloss-search", type: "search", placeholder: "Search " + all.length + " terms…", value: S.glossQuery || "", "data-focus-id": "gloss-search",
      oninput: (e) => { S.glossQuery = e.target.value; set({}); } });
    return el("div", { class: "modal-overlay", onclick: dismiss }, [
      el("div", { class: "gloss-modal" }, [
        el("div", { class: "gloss-head" }, [
          el("div", { class: "gloss-title" }, ["Glossary", el("span", { class: "gloss-count" }, [q ? shown + " of " + all.length : String(all.length)])]),
          el("button", { class: "modal-close", title: "Close", onclick: closeGlossary }, ["✕"]),
        ]),
        search,
        el("div", { class: "gloss-body", "data-scrollkey": "gloss-body" }, body),
        el("div", { class: "gloss-foot" }, ["These terms also appear as colored, hoverable keywords in skill and effect descriptions."]),
      ]),
    ]);
  }
  // ===================== Campaign mode (Phase 0 + placeholder chapter X slice) =====================
  // Client-driven story: chapter maps of nodes; each node resolves content from story state
  // (stage + flags + completed activations) on every visit — the SAME node behaves differently at
  // different points in the story. Progress persists via the cosmetics save path (client-written,
  // like active_bounties); rewards/unlocks stay server-authoritative. See .claude/plans/campaign-mode.md.
  function loadCampaignData() {
    if (!S.campaignData) fetch("campaign_chapters.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ campaignData: m })).catch(() => {});
    if (!S.campaignDialogue) fetch("campaign_dialogue.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ campaignDialogue: m })).catch(() => {});
    if (!S.campaignEncounters) fetch("campaign_encounters.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ campaignEncounters: m })).catch(() => {});
  }
  function campaignChapter(id) { return ((S.campaignData && S.campaignData.chapters) || []).find((c) => c.id === id) || null; }
  function campaignNode(ch, nodeId) { return (ch && (ch.nodes || []).find((n) => n.id === nodeId)) || null; }
  // Story-state predicate — the heart of revisitable, time-aware nodes. Mirrored server-side in a
  // later hardening pass; for now the client evaluates and the server just persists the result.
  function campaignWhenPasses(when, prog) {
    if (!when) return true;
    const flags = prog.flags || {};
    if (when.stage != null) {
      if (Array.isArray(when.stage)) { if (!when.stage.includes(prog.stage)) return false; }
      else if (when.stage !== prog.stage) return false;
    }
    if (when.flags && !when.flags.every((f) => !!flags[f])) return false;
    if (when.not_flags && !when.not_flags.every((f) => !flags[f])) return false;
    return true;
  }
  function campaignNodeOpen(node, prog) { return campaignWhenPasses(node.open_when, prog); }
  // First activation whose `when` passes and (if one-shot) hasn't been consumed — that's what's
  // happening at this node RIGHT NOW.
  function campaignResolveActivation(node, prog) {
    const done = prog.completed || [];
    for (const a of (node.activations || [])) {
      if (a.once !== false && done.includes(a.id)) continue;
      if (campaignWhenPasses(a.when, prog)) return a;
    }
    return null;
  }
  // A node has a fresh, uncompleted MAIN-STORY beat available (drives the "!" map marker).
  function campaignHasBeat(node, prog) {
    const a = campaignResolveActivation(node, prog);
    return !!(a && a.once !== false && a.when && a.when.stage != null && !(prog.completed || []).includes(a.id));
  }
  function enterCampaign() {
    // Optimistically seed the map from the last state the login blob carried (avoids a loading flash);
    // the server's authoritative campaign_state echo (note "enter") reconciles + arrives at the node.
    const saved = (S.player && S.player.campaign_state) || {};
    S.campaign = (saved && saved.chapter) ? JSON.parse(JSON.stringify(saved)) : null;
    set({ campaignView: "map", campaignRun: null, campaignScene: null, campaignMoving: null, campaignLoadout: null, screen: "campaign", msg: "" });
    loadCampaignData();
    // the loadout editor needs these manifests (party grid + skill icons/descriptions)
    loadRoster(); loadPortraits(); loadCharIndex(); loadAbilityInfo(); loadAbilityIcons();
    S.net.send("campaign_enter", {});   // server inits a fresh chapter if none, then echoes campaign_state
  }
  function campaignWhenDataReady(cb) {
    loadCampaignData();
    if (S.campaignData && S.campaignDialogue && S.campaignEncounters) return cb();
    const t = setInterval(() => { if (S.campaignData && S.campaignDialogue && S.campaignEncounters) { clearInterval(t); cb(); } }, 30);
  }
  // Reconcile the client mirror to the server's authoritative campaign_state, then run the follow-up
  // the intent implies. campaign_state is NEVER written locally — the server owns stage/flags/node/
  // visited/completed and reward unlocks; this is the only place S.campaign is (re)assigned from data.
  function campaignApplyServerState(m, note) {
    if (m && m.state && typeof m.state === "object") {
      S.campaign = m.state;
      if (S.player) S.player.campaign_state = m.state;   // keep the re-entry mirror fresh
    }
    if (m && m.unlocks && S.player) S.player.unlocks = m.unlocks;   // reward grants (char unlocks)
    set({ campaignMoving: null });
    // The server decides when to auto-play the node's beat (arrive=true on travel, on a re-select via
    // campaign_arrive, and on enter only when a main beat is pending or an in-progress beat is being
    // resumed); complete/choice/abandon/error just reconcile the mirror + re-render the map.
    if (m && m.arrive && (note === "enter" || note === "travel" || note === "arrive") && S.campaign && S.campaign.node) {
      campaignWhenDataReady(() => campaignArrive(S.campaign.node));
    }
  }
  function exitCampaign() { set({ screen: "menu", campaignView: "map", campaignRun: null, campaignScene: null, campaignMoving: null, msg: "Campaign saved", msgKind: "ok" }); }
  function campaignTravel(nodeId) {
    const prog = S.campaign, ch = campaignChapter(prog.chapter);
    if (S.campaignMoving || S.campaignRun) return;
    const cur = campaignNode(ch, prog.node), target = campaignNode(ch, nodeId);
    if (!cur || !target || !(cur.edges || []).includes(nodeId)) return;   // local sanity; server re-validates
    if (!campaignNodeOpen(target, prog)) { set({ msg: "That path isn't open yet.", msgKind: "err" }); return; }
    set({ campaignMoving: { from: prog.node, to: nodeId } });   // CSS token glide; arrival driven by the server echo
    S.net.send("campaign_travel", { to: nodeId });
  }
  // Re-select the CURRENT node to (re)start its beat (e.g. retry after a battle loss). The server sets
  // `active` for the node and echoes note "arrive" (arrive:true), which drives campaignArrive → replay.
  function campaignReselect(nodeId) {
    if (S.campaignMoving || S.campaignRun) return;
    S.net.send("campaign_arrive", { node: nodeId });
  }
  function campaignActivationById(ch, nodeId, actId) {
    const n = campaignNode(ch, nodeId);
    return n ? ((n.activations || []).find((a) => a.id === actId) || null) : null;
  }
  function campaignArrive(nodeId) {
    const prog = S.campaign, ch = campaignChapter(prog.chapter);
    // Prefer the server's authoritative in-progress beat (deterministic across mid-sequence flag changes,
    // and on resume the same beat replays); fall back to a fresh resolve for a first arrival.
    let act = null;
    if (prog.active && prog.active.node === nodeId) act = campaignActivationById(ch, nodeId, prog.active.activation);
    if (!act) act = campaignResolveActivation(campaignNode(ch, nodeId), prog);
    if (!act) { set({ campaignView: "map" }); return; }
    set({ campaignRun: { nodeId: nodeId, activationId: act.id, once: act.once !== false, steps: (act.sequence || []).slice(), idx: 0, on_complete: act.on_complete || null } });
    campaignRunStep();
  }
  function campaignRunStep() {
    const run = S.campaignRun;
    if (!run) return;
    if (run.idx >= run.steps.length) { campaignFinishSequence(); return; }
    const step = run.steps[run.idx];
    if (step.talk) set({ campaignScene: { id: step.talk, line: 0 }, campaignView: "dialogue", msg: "" });
    else if (step.battle) {
      // On RESUME, a battle already banked in pending_wins FOR THIS BEAT is skipped (don't re-fight it);
      // otherwise fight. pending_wins entries are beat-scoped {activation, encounter}.
      const won = ((S.campaign && S.campaign.pending_wins) || []).some((w) => w && w.activation === run.activationId && w.encounter === step.battle);
      if (won) { run.idx++; campaignRunStep(); }
      else campaignLaunchBattle(step.battle);
    }
    else { run.idx++; campaignRunStep(); }
  }
  function campaignAdvanceStep() { const run = S.campaignRun; if (!run) return; run.idx++; campaignRunStep(); }
  function campaignFinishSequence() {
    const run = S.campaignRun;
    // Consuming the beat + applying on_complete (set_stage / set_flags / reward unlocks) is the SERVER's
    // job: it re-resolves the live activation, verifies any battle steps were won, and echoes the new state.
    S.net.send("campaign_activation_complete", { node: run.nodeId, activation: run.activationId });
    set({ campaignRun: null, campaignScene: null, campaignView: "map", msg: "" });
  }
  // Dialogue advance / choice
  function campaignDialogueNext() {
    const sc = S.campaignScene, scene = (S.campaignDialogue || {})[sc.id] || {};
    if (sc.line + 1 < (scene.lines || []).length) { sc.line++; set({}); }
    else campaignAdvanceStep();   // end of scene → next sequence step
  }
  function campaignChoice(c, ci) {
    // The server applies the choice's set_flags / unlocks (validated against reachable scenes); the client
    // just drives the local VN forward. `goto` handles any immediate branch; flags reconcile on the echo.
    const sc = S.campaignScene;
    S.net.send("campaign_choice", { scene: sc.id, line: sc.line, choice: ci });
    if (c.goto) { S.campaignScene = { id: c.goto, line: 0 }; set({}); }
    else campaignAdvanceStep();
  }
  // Battle handoff: launch a Phase-1 campaign battle; the sequence resumes in returnToCampaign().
  function campaignLaunchBattle(encId) {
    const enc = (S.campaignEncounters || {})[encId] || {};
    const ch = campaignChapter(S.campaign.chapter);
    const party = ((S.campaign.party && S.campaign.party.length ? S.campaign.party : (ch && ch.party)) || ["naruto", "sasuke", "sakura"]).slice(0, 3);
    S.campaignBattleReturn = true;
    S.net.send("campaign_start_battle", { player_team: party, enemy_team: (enc.enemy_team || []).slice(0, 3), encounter: encId, enemy_name: enc.enemy_name || "Enemy Forces" });
    set({ msg: "Entering battle…", msgKind: "" });
  }
  function returnToCampaign() {
    clearTurnWatchdog();
    const won = S.matchResult && S.matchResult.won;
    // A fresh-JS reconnect straight into a live campaign battle leaves S.campaign null (it's only set by
    // enterCampaign / the server echo). Reseed it from the login blob so we can derive the beat cursor and
    // never land on a permanent "Loading campaign…" screen.
    if (!S.campaign && S.player && S.player.campaign_state && S.player.campaign_state.chapter) {
      S.campaign = JSON.parse(JSON.stringify(S.player.campaign_state));
    }
    set({ screen: "campaign", match: null, snapshot: null, matchResult: null, staged: [], execOrder: null, randomAssign: { 0: 0, 1: 0, 2: 0, 3: 0 }, exchange: null, exchangeSetup: null, randomModal: false, targeting: null, queued: false, confirmSurrender: false, oppGone: false, campaignBattleReturn: false, msg: "" });
    // The local run cursor is null if we reconnected mid-battle — fall back to the server's `active` beat.
    const beat = S.campaignRun || (S.campaign && S.campaign.active ? { nodeId: S.campaign.active.node, activationId: S.campaign.active.activation } : null);
    if (won === false) {
      // Defeat: tell the server to ABANDON the beat (clears `active`, drops this beat's banked wins, does
      // NOT consume it). Back on the map, re-selecting the node restarts the whole beat, dialogue included.
      // If the beat cursor is unknown (reconnect edge), campaign_enter re-syncs so the screen isn't stuck.
      if (beat) S.net.send("campaign_abandon", { node: beat.nodeId, activation: beat.activationId });
      else S.net.send("campaign_enter", {});
      set({ campaignRun: null, campaignScene: null, campaignView: "map", msg: "Defeated — select the node to try again.", msgKind: "err" });
    } else if (S.campaignRun) {
      campaignAdvanceStep();   // victory/draw: continue the sequence past the battle step
    } else {
      // Won, but the run cursor was lost to a reconnect. campaign_enter lands on the map at the node (the
      // win is banked in pending_wins); the player re-selects the node to replay the beat — the already-won
      // battle step is skipped, so they see the post-battle dialogue and the beat completes.
      S.net.send("campaign_enter", {});
      set({ msg: "Select your node to continue the story.", msgKind: "" });
    }
  }
  // ---- campaign screen + sub-views ----
  function campaignScreen() {
    if (!S.campaign || !S.campaignData || !S.campaignDialogue || !S.campaignEncounters || !S.campaign.node) { loadCampaignData(); return el("div", { class: "screen campaign" }, [el("div", { class: "note" }, ["Loading campaign…"])]); }
    const ch = campaignChapter(S.campaign.chapter);
    if (!ch) return el("div", { class: "screen campaign" }, [el("div", { class: "note" }, ["Unknown chapter: " + S.campaign.chapter])]);
    const body = S.campaignView === "dialogue" ? campaignDialogueView() : campaignMapView();
    return el("div", { class: "screen campaign" }, [campaignTopbar(ch), body]);
  }
  function campaignTopbar(ch) {
    return el("div", { class: "cmp-topbar" }, [
      el("div", { class: "cmp-title" }, [ch.title || ch.id]),
      el("div", { class: "cmp-stage" }, ["Stage: " + (S.campaign.stage || "—") + (S.campaign.flags && S.campaign.flags.chapterX_done ? "  ✓ complete" : "")]),
      el("button", { class: "cmp-loadout", onclick: openCampaignLoadout, disabled: !!S.campaignRun, title: S.campaignRun ? "Finish the current scene first" : "" }, ["⚙ Party & Skills"]),
      el("button", { class: "cmp-exit", onclick: exitCampaign }, ["Exit to Menu"]),
    ]);
  }
  // ---- campaign loadout editor (team + Vessel skills) ----
  const VESSEL_SKILL_POOL = () => charAbilities("vessel").concat(((S.campaign && S.campaign.campaign_unlocked_abilities) || []).map(String));
  function campaignPartyPool() {
    const ch = campaignChapter(S.campaign.chapter) || {};
    const pool = ["vessel"].concat((ch.roster_grants || []).map(String));
    // also any PvP-unlocked character the client knows about
    (S.roster || []).forEach((r) => { if (charUnlocked(r) && !pool.includes(r.path_name)) pool.push(r.path_name); });
    return pool.filter((p, i) => pool.indexOf(p) === i);
  }
  function openCampaignLoadout() {
    if (S.campaignRun) return;
    let party = (S.campaign.party && S.campaign.party.length ? S.campaign.party.slice(0, 3) : []);
    if (!party.includes("vessel")) party = ["vessel"].concat(party).slice(0, 3);   // the Vessel is mandatory
    const skills = ((S.campaign.vessel_loadout && S.campaign.vessel_loadout.length ? S.campaign.vessel_loadout : charAbilities("vessel").slice(0, 4)));
    set({ campaignLoadout: { tab: "party", party: party.slice(), skills: skills.slice(), inspect: null } });
  }
  function closeCampaignLoadout() { set({ campaignLoadout: null }); }
  function clToggleParty(pn) {
    const lo = S.campaignLoadout, cur = lo.party.slice();
    const i = cur.indexOf(pn);
    if (i >= 0) { if (pn === "vessel") return; cur.splice(i, 1); }   // the Vessel can't be removed from the team
    else if (cur.length < 3) cur.push(pn);
    set({ campaignLoadout: Object.assign({}, lo, { party: cur, inspect: pn }) });
  }
  function clToggleSkill(key) {
    const lo = S.campaignLoadout, cur = lo.skills.slice();
    const i = cur.indexOf(key);
    if (i >= 0) cur.splice(i, 1);
    else if (cur.length < 4) cur.push(key);
    set({ campaignLoadout: Object.assign({}, lo, { skills: cur, inspect: key }) });
  }
  function clSaveParty() {
    const lo = S.campaignLoadout;
    if (lo.party.length !== 3) { set({ msg: "Pick exactly 3 characters.", msgKind: "err" }); return; }
    if (!lo.party.includes("vessel")) { set({ msg: "Your team must include the Vessel.", msgKind: "err" }); return; }
    S.net.send("campaign_set_party", { party: lo.party });
    set({ msg: "Team saved", msgKind: "ok" });
  }
  function clSaveSkills() {
    const lo = S.campaignLoadout;
    // The Vessel always fights with 4 skill slots — require exactly 4 (the server would otherwise pad
    // a shorter pick back up to 4 with defaults, which the UI wouldn't reflect).
    if (lo.skills.length !== 4) { set({ msg: "Pick exactly 4 skills for your Vessel.", msgKind: "err" }); return; }
    S.net.send("campaign_set_vessel_skills", { skills: lo.skills });
    set({ msg: "Vessel skills saved", msgKind: "ok" });
  }
  function campaignLoadoutModal() {
    const lo = S.campaignLoadout;
    const tabBtn = (id, label) => el("button", { class: "cl-tab" + (lo.tab === id ? " sel" : ""), onclick: () => set({ campaignLoadout: Object.assign({}, lo, { tab: id, inspect: null }) }) }, [label]);
    let body;
    if (lo.tab === "party") {
      const pool = campaignPartyPool();
      const grid = el("div", { class: "menu-grid cl-grid" }, pool.map((pn) => {
        const thumb = portraitUrlFor(pn), picked = lo.party.includes(pn), order = lo.party.indexOf(pn) + 1, fixed = pn === "vessel";
        const kids = thumb ? [el("img", { class: "mg-img", src: thumb, alt: "", onerror: (e) => e.target.remove() })] : [el("div", { class: "abn" }, [titleName(pn)])];
        if (picked) kids.push(el("div", { class: "cl-badge" }, [fixed ? "★" : String(order)]));
        return el("div", { class: "mg-cell" + (picked ? " sel" : "") + (fixed ? " cl-fixed" : "") + (lo.inspect === pn ? " focused" : ""), title: fixed ? "The Vessel (always on your team)" : titleName(pn), onclick: () => clToggleParty(pn) }, kids);
      }));
      body = el("div", { class: "cl-panel" }, [
        el("div", { class: "cl-hint" }, ["Choose your 3-character campaign team (" + lo.party.length + "/3). The Vessel (★) is always on your team; tap others to add or remove."]),
        grid,
        el("div", { class: "cl-picked" }, ["Team: ", el("b", {}, [lo.party.map(titleName).join(", ") || "—"])]),
        el("div", { class: "cl-actions" }, [
          el("button", { class: "cl-btn", onclick: clSaveParty }, ["Save Team"]),
          el("button", { class: "cl-btn secondary", onclick: () => { let rp = (S.campaign.party || []).slice(0, 3); if (!rp.includes("vessel")) rp = ["vessel"].concat(rp).slice(0, 3); set({ campaignLoadout: Object.assign({}, lo, { party: rp }) }); } }, ["Reset"]),
        ]),
      ]);
    } else if (!S.abilityInfo) {
      body = el("div", { class: "cl-panel" }, [el("div", { class: "note" }, ["Loading skills…"])]);
    } else {
      const info = S.abilityInfo;
      const pool = VESSEL_SKILL_POOL();
      const strip = el("div", { class: "cl-skillgrid" }, pool.map((key) => {
        const icon = abilityIconUrl(key), nm = (info[key] || {}).name || key, picked = lo.skills.includes(key), order = lo.skills.indexOf(key) + 1;
        const kids = [icon ? el("img", { class: "abimg", src: icon, alt: "", onerror: (e) => { const d = el("div", { class: "abn" }, [nm]); e.target.replaceWith(d); } }) : el("div", { class: "abn" }, [nm])];
        if (picked) kids.push(el("div", { class: "cl-badge" }, [String(order)]));
        return el("div", { class: "cl-skill" + (picked ? " sel" : "") + (lo.inspect === key ? " focused" : ""), title: nm, onclick: () => clToggleSkill(key) }, kids);
      }));
      const detail = lo.inspect && info[lo.inspect] ? abilityBody(lo.inspect) : el("div", { class: "note" }, ["Tap a skill to preview it, or to add/remove it from the Vessel's kit."]);
      body = el("div", { class: "cl-panel" }, [
        el("div", { class: "cl-hint" }, ["Choose 4 skills for your Vessel (" + lo.skills.length + "/4). Tap to add, remove, or preview."]),
        strip,
        el("div", { class: "cl-detail" }, [detail]),
        el("div", { class: "cl-actions" }, [
          el("button", { class: "cl-btn", onclick: clSaveSkills }, ["Save Skills"]),
          el("button", { class: "cl-btn secondary", onclick: () => set({ campaignLoadout: Object.assign({}, lo, { skills: charAbilities("vessel").slice(0, 4) }) }) }, ["Reset to Default"]),
        ]),
      ]);
    }
    return el("div", { class: "modal-overlay", onclick: (e) => { if (e.target.classList.contains("modal-overlay")) closeCampaignLoadout(); } }, [
      el("div", { class: "modal-panel cl-modal" }, [
        el("div", { class: "cl-head" }, [
          el("div", { class: "cl-title" }, ["Party & Vessel Skills"]),
          el("button", { class: "modal-close", onclick: closeCampaignLoadout }, ["✕"]),
        ]),
        el("div", { class: "cl-tabs" }, [tabBtn("party", "Team"), tabBtn("skills", "Vessel Skills")]),
        body,
      ]),
    ]);
  }
  function campaignEdge(a, b) {
    const x1 = a.x * 100, y1 = a.y * 100, x2 = b.x * 100, y2 = b.y * 100;
    const dx = x2 - x1, dy = y2 - y1, len = Math.sqrt(dx * dx + dy * dy);
    const ang = Math.atan2(dy, dx) * 180 / Math.PI;
    return el("div", { class: "cmap-edge", style: "left:" + x1 + "%;top:" + y1 + "%;width:" + len + "%;transform:rotate(" + ang + "deg)" }, []);
  }
  function campaignMapView() {
    const prog = S.campaign, ch = campaignChapter(prog.chapter);
    const bg = backgroundUrl(ch.map_background);
    const cur = campaignNode(ch, prog.node);
    const nodeById = {}; (ch.nodes || []).forEach((n) => (nodeById[n.id] = n));
    const seen = {}, edges = [];
    (ch.nodes || []).forEach((n) => (n.edges || []).forEach((e) => {
      const key = [n.id, e].sort().join("|"); if (seen[key] || !nodeById[e]) return; seen[key] = 1;
      edges.push(campaignEdge(n, nodeById[e]));
    }));
    const moving = S.campaignMoving;
    const nodes = (ch.nodes || []).map((n) => {
      const open = campaignNodeOpen(n, prog), isCur = n.id === prog.node;
      const adjacent = cur && (cur.edges || []).includes(n.id);
      const reachable = adjacent && open && !isCur && !moving && !S.campaignRun;
      // The current node is re-selectable to (re)start its beat — used to retry a beat after a battle
      // loss (its events, dialogue included, replay from the top) — whenever idle and a beat resolves.
      const restartable = isCur && !moving && !S.campaignRun && !!campaignResolveActivation(n, prog);
      const cls = "cmap-node" + (isCur ? " cur" : "") + (open ? "" : " locked") + (reachable ? " reachable" : "") + (restartable ? " restartable" : "") + ((prog.visited || []).includes(n.id) ? " visited" : "");
      const attrs = { class: cls, style: "left:" + (n.x * 100) + "%;top:" + (n.y * 100) + "%", title: n.label || n.id };
      if (reachable) attrs.onclick = () => campaignTravel(n.id);
      else if (restartable) attrs.onclick = () => campaignReselect(n.id);
      return el("div", attrs, [
        el("div", { class: "cmap-dot" }, []),
        el("div", { class: "cmap-label" }, [n.label || n.id]),
        (open && campaignHasBeat(n, prog)) ? el("div", { class: "cmap-beat" }, ["!"]) : null,
      ]);
    });
    let tokenStyle;
    if (moving) {
      const a = nodeById[moving.from], b = nodeById[moving.to];
      tokenStyle = "left:" + (b.x * 100) + "%;top:" + (b.y * 100) + "%;--fx:" + (a.x * 100) + "%;--fy:" + (a.y * 100) + "%;--tx:" + (b.x * 100) + "%;--ty:" + (b.y * 100) + "%;animation:cmapGlide .6s ease forwards";
    } else if (cur) {
      tokenStyle = "left:" + (cur.x * 100) + "%;top:" + (cur.y * 100) + "%";
    }
    const token = cur || moving ? el("div", { class: "cmap-token", style: tokenStyle }, []) : null;
    const hint = el("div", { class: "cmap-hint" }, [S.campaignRun ? "…" : "Click a glowing adjacent node to travel."]);
    return el("div", { class: "campaign-map", style: bg ? ("background-image:url('" + bg + "')") : "" }, [
      el("div", { class: "cmap-plane" }, edges.concat(nodes).concat(token ? [token] : [])), hint,
    ]);
  }
  function campaignDialogueView() {
    const sc = S.campaignScene, scene = (S.campaignDialogue || {})[sc && sc.id];
    if (!scene) return el("div", { class: "campaign-dialogue" }, [el("div", { class: "note" }, ["Missing scene: " + (sc && sc.id)]), el("button", { class: "cd-advance", onclick: campaignAdvanceStep }, ["▸ continue"])]);
    const lines = scene.lines || [], line = lines[sc.line] || {};
    // Cast = the last portrait shown at each position, up to the current line, so multiple speakers
    // can share the stage (classic VN); the active speaker is highlighted.
    // Each position keeps the last portrait shown there, plus that line's emotion tag (happy|serious|
    // shocked) so a character holds its expression until it emotes again.
    const cast = {};
    for (let i = 0; i <= sc.line && i < lines.length; i++) { const L = lines[i]; if (L && L.portrait && L.pos) cast[L.pos] = { portrait: L.portrait, emotion: L.emotion || null }; }
    const bg = backgroundUrl(scene.background);
    const stage = el("div", { class: "cd-stage" }, ["left", "center", "right"].map((pos) => {
      const c = cast[pos], active = line.pos === pos, pn = c && c.portrait;
      const url = pn ? portraitUrlForEmotion(pn, c.emotion) : null;
      const dflt = pn ? portraitUrlFor(pn) : null;
      // If an emotion-tagged file is missing, swap to the default portrait once; if that also fails, drop it.
      const onerr = (e) => { const img = e.target; if (dflt && dflt !== url && img.dataset.fb !== "1") { img.dataset.fb = "1"; img.src = dflt; } else img.remove(); };
      return el("div", { class: "cd-slot cd-" + pos + (active ? " active" : "") + (pn ? "" : " empty") }, url ? [el("img", { class: "cd-portrait", src: url, alt: "", onerror: onerr })] : []);
    }));
    const hasChoices = Array.isArray(line.choices) && line.choices.length;
    const panel = el("div", { class: "cd-panel" }, [
      el("div", { class: "cd-speaker" }, [line.speaker || ""]),
      el("div", { class: "cd-text" }, [line.text || ""]),
      hasChoices
        ? el("div", { class: "cd-choices" }, line.choices.map((c, ci) => el("button", { class: "cd-choice", onclick: () => campaignChoice(c, ci) }, [c.text])))
        : el("div", { class: "cd-advance", onclick: campaignDialogueNext }, [(sc.line + 1 < lines.length) ? "▸ continue" : "▸ end scene"]),
    ]);
    return el("div", { class: "campaign-dialogue", style: bg ? ("background-image:url('" + bg + "')") : "" }, [stage, panel]);
  }
  function menuQueueRow() {
    const ready = S.team.length === 3;
    return el("div", { class: "menu-queue" }, [
      el("button", { class: "queue-btn", disabled: !ready, onclick: queueQuick }, [ready ? "Quick Match" : "Quick Match (" + S.team.length + "/3)"]),
      el("button", { class: "queue-btn bot", disabled: !ready, onclick: queueBot, title: "Play against a bot right away — no waiting" }, [ready ? "Bot Match" : "Bot Match (" + S.team.length + "/3)"]),
      el("button", { class: "queue-btn ranked", disabled: !ready, onclick: queueRanked, title: "Ladder — blind pick, uses your selected team" }, [ready ? "Ladder Match" : "Ladder Match (" + S.team.length + "/3)"]),
      el("button", { class: "queue-btn", disabled: !ready, onclick: () => set({ privatePrompt: true, msg: "" }) }, ["Private Match"]),
      CAMPAIGN_ENABLED ? el("button", { class: "queue-btn campaign", title: "Story mode — no team needed to enter", onclick: enterCampaign }, ["⚔ Campaign"]) : null,
    ]);
  }
  function toggleColorFilter(c) {
    const i = S.colorFilters.indexOf(c);
    if (i >= 0) S.colorFilters.splice(i, 1); else S.colorFilters.push(c);
    set({ msg: "" });
  }
  function filterPanel() {
    return el("div", { class: "filter-panel" }, [
      el("button", { class: "fp-randomize", onclick: randomizeTeam }, ["⟳ Randomize Team"]),
      el("button", { class: "fp-hidelocked" + (S.hideLocked ? " on" : ""), title: "Hide characters you haven't unlocked", onclick: () => set({ hideLocked: !S.hideLocked, msg: "" }) }, ["🔒 Hide Locked"]),
      el("div", { class: "fp-label" }, ["Color Filter"]),
      el("div", { class: "fp-colors" }, [0, 1, 2, 3, 4].map((c) =>
        el("button", { class: "fp-color e" + c + (S.colorFilters.includes(c) ? " sel" : ""),
          title: c === 4 ? "Random — show only characters whose colors are EXACTLY those selected (with no color selected, only characters that use purely Random energy)" : ENERGY_NAMES[c],
          onclick: () => toggleColorFilter(c) }))),
    ]);
  }
  function randomizeTeam() {
    const avail = (S.roster || []).filter(charUnlocked);
    if (avail.length < 3) return;
    const pool = avail.slice(), picks = [];
    while (picks.length < 3 && pool.length) picks.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0].path_name);
    S.team = picks;
    persistTeam();
    set({ msg: "" });
  }
  function gridArea() {
    const roster = S.roster;
    if (!roster) loadRoster();
    if (!S.bountyData) loadBountyData();   // bounty categories feed the Category filter + grid badges
    // Match the Godot client's char select: only char_name_list characters, starter_squads
    // clustered to the front (see CHAR_SELECT_ORDER). Also drops any roster entry not in that list.
    const base = (roster || []).filter((r) => CHAR_SELECT_SET.has(r.path_name))
      .sort((a, b) => CHAR_SELECT_RANK.get(a.path_name) - CHAR_SELECT_RANK.get(b.path_name));
    const universes = roster ? Array.from(new Set(base.map((r) => r.universe).filter(Boolean))).sort() : [];
    let list = base.slice();
    if (S.colorFilters.length) {
      // Black (Random, index 4) is an EXCLUSIVITY toggle: with it selected, a char's non-random colors
      // must EXACTLY equal the selected colors (Black alone = only-Random chars; Black+Green = chars that
      // use only Green). Without Black it's the usual AND — a char must use ALL selected colors.
      const excl = S.colorFilters.includes(4);
      const sel = S.colorFilters.filter((c) => c !== 4);
      list = list.filter((r) => {
        const rc = r.colors || [];
        return excl ? (rc.length === sel.length && sel.every((c) => rc.includes(c)))
                    : sel.every((c) => rc.includes(c));
      });
    }
    if (S.animeFilter) list = list.filter((r) => r.universe === S.animeFilter);
    if (S.nexusRound && NEXUS_CLASH_ROUNDS[S.nexusRound]) {
      const pool = new Set(NEXUS_CLASH_ROUNDS[S.nexusRound]);
      list = list.filter((r) => pool.has(r.universe));
    }
    if (S.catFilter && S.bountyData) list = list.filter((r) => ((S.bountyData.categories || {})[S.catFilter] || []).includes(r.path_name));
    if (S.hideLocked) list = list.filter((r) => charUnlocked(r));   // "Hide Locked" filter (filterPanel toggle)
    const grid = el("div", { class: "menu-grid" }, list.map((c) => {
      const locked = !charUnlocked(c);
      const thumb = portraitUrlFor(c.path_name);
      const kids = [];
      if (thumb) kids.push(el("img", { class: "mg-img", src: thumb, alt: "", onerror: (e) => e.target.remove() }));
      if (locked) kids.push(el("div", { class: "pclock" }, ["🔒"]));
      const attrs = {
        class: "mg-cell" + (S.team.includes(c.path_name) ? " sel" : "") + (S.menuInspect && S.menuInspect.path_name === c.path_name ? " focused" : "") + (locked ? " locked" : ""),
        title: c.name, "data-search": (c.name + " " + (c.universe || "") + " " + c.path_name).toLowerCase() + " " + charAbilitySearchText(c.path_name),
      };
      attrs.onclick = () => selectAndInspect(c.path_name);   // locked chars are still clickable — to view info (adding is blocked in toggleTeamMember)
      return el("div", attrs, kids);
    }));
    if (S.charSearch) applyCharFilter(grid, S.charSearch);   // search filters in place (keeps input focus)
    const animeSel = el("select", { class: "filter-sel", onchange: (e) => set({ animeFilter: e.target.value, msg: "" }) },
      [el("option", { value: "" }, ["All"])].concat(universes.map((u) => {
        const o = el("option", { value: u }, [u]); if (u === S.animeFilter) o.selected = true; return o;
      })));
    const roundSel = el("select", { class: "filter-sel", title: "Nexus Clash tournament pool — restrict the grid to a round's anime", onchange: (e) => set({ nexusRound: Number(e.target.value) || 0, msg: "" }) },
      [el("option", { value: "0" }, ["All"])].concat([1, 2, 3, 4].map((n) => {
        const o = el("option", { value: String(n) }, ["Round " + n]); if (n === S.nexusRound) o.selected = true; return o;
      })));
    const categories = (S.bountyData && S.bountyData.categories) ? Object.keys(S.bountyData.categories).sort() : [];
    const catSel = el("select", { class: "filter-sel", onchange: (e) => set({ catFilter: e.target.value, msg: "" }) },
      [el("option", { value: "" }, ["Any"])].concat(categories.map((cat) => {
        const o = el("option", { value: cat }, [titleCase(cat)]); if (cat === S.catFilter) o.selected = true; return o;
      })));
    const search = el("input", { class: "grid-search", placeholder: "Search…", value: S.charSearch || "",
      oninput: (e) => { S.charSearch = e.target.value; applyCharFilter(grid, e.target.value); } });
    return el("div", { class: "grid-area" }, [
      el("div", { class: "grid-filters" }, [
        el("span", { class: "gf-label" }, ["Anime"]), animeSel,
        el("span", { class: "gf-label" }, ["Nexus Clash"]), roundSel,
        el("span", { class: "gf-label" }, ["Category"]), catSel,
        search,
      ]),
      roster ? grid : el("div", { class: "note" }, ["Loading roster…"]),
    ]);
  }
  function savedTeamsSection() {
    const teams = loadSavedTeamsList();
    const nameIn = el("input", { class: "st-name", placeholder: "Name this team", maxlength: "24" });
    const doSave = () => {
      const name = (nameIn.value || "").trim();
      if (!name) { set({ msg: "Enter a name for the team", msgKind: "err" }); return; }
      if (!S.team.length) { set({ msg: "Pick some characters first", msgKind: "err" }); return; }
      saveCurrentTeam(name);
      set({ msg: 'Saved team "' + name + '"', msgKind: "ok" });
    };
    nameIn.addEventListener("keydown", (e) => { if (e.key === "Enter") doSave(); });
    return el("div", { class: "saved-teams" }, [
      el("div", { class: "st-label" }, ["Saved Teams"]),
      el("div", { class: "st-list" }, teams.length ? teams.map((t, i) =>
        el("div", { class: "st-item" }, [
          el("button", { class: "st-load", title: "Load: " + (t.characters || []).map(titleName).join(", "), onclick: () => loadSavedTeam(i) }, [t.name]),
          el("button", { class: "st-del", title: "Delete", onclick: () => { deleteSavedTeam(i); set({}); } }, ["×"]),
        ])) : [el("div", { class: "st-empty" }, ["No saved teams yet."])]),
      el("div", { class: "st-save-row" }, [nameIn, el("button", { class: "st-save-btn", onclick: doSave }, ["Save"])]),
    ]);
  }
  // Avatar URL editor: click the player-panel avatar → this modal. On submit we load the URL as an
  // image; if it resolves, save it, otherwise notify + reset to the default avatar (per request).
  function applyAvatar(url) {
    if (!S.player) return;
    url = (url || "").trim();
    if (!url) {   // empty = reset to default
      S.player.avatar_url = "";
      saveCosmetics();
      set({ avatarEdit: null, msg: "Avatar reset to default", msgKind: "ok" });
      return;
    }
    set({ msg: "Checking image…", msgKind: "" });
    let done = false;
    const finish = (okUrl, message, kind) => {
      if (done) return; done = true;
      S.player.avatar_url = okUrl;
      saveCosmetics();
      set({ avatarEdit: null, msg: message, msgKind: kind });
    };
    const img = new Image();
    const timer = setTimeout(() => finish("", "That image took too long to load — avatar reset to default", "err"), 8000);
    img.onload = () => { clearTimeout(timer); finish(url, "Avatar updated", "ok"); };
    img.onerror = () => { clearTimeout(timer); finish("", "That image couldn't be loaded — avatar reset to default", "err"); };
    img.src = url;
  }
  function avatarModal() {
    const cur = (S.player && S.player.avatar_url) || "";
    const close = () => set({ avatarEdit: null });
    const urlIn = el("input", { class: "av-url", type: "url", placeholder: "https://example.com/avatar.png", value: cur, autocapitalize: "off", autocorrect: "off", spellcheck: "false" });
    const submit = () => applyAvatar(urlIn.value);
    urlIn.addEventListener("keydown", (e) => { if (e.key === "Enter") submit(); });
    return el("div", { class: "modal-overlay", onclick: (e) => { if (e.target.classList.contains("modal-overlay")) close(); } }, [
      el("div", { class: "modal-panel av-modal" }, [
        el("div", { class: "av-title" }, ["Set Avatar"]),
        el("img", { class: "av-preview", src: cur || resToUrl("res://assets/avatars/toko_toda.png"), alt: "", onerror: (e) => (e.target.style.visibility = "hidden") }),
        el("div", { class: "av-note" }, ["Paste a direct image URL. If it can't be loaded, your avatar resets to the default."]),
        urlIn,
        el("div", { class: "av-actions" }, [
          el("button", { class: "av-btn", onclick: submit }, ["Set Avatar"]),
          el("button", { class: "av-btn secondary", onclick: () => applyAvatar("") }, ["Reset to Default"]),
          el("button", { class: "av-btn secondary", onclick: close }, ["Cancel"]),
        ]),
      ]),
    ]);
  }
  function privateModal() {
    const close = () => set({ privatePrompt: null });
    const nameIn = el("input", { class: "pm-in", placeholder: "Opponent's username", autocapitalize: "off", autocorrect: "off", spellcheck: "false" });
    const submit = () => queuePrivate(nameIn.value);
    nameIn.addEventListener("keydown", (e) => { if (e.key === "Enter") submit(); });
    return el("div", { class: "modal-overlay", onclick: (e) => { if (e.target.classList.contains("modal-overlay")) close(); } }, [
      el("div", { class: "modal-panel pm-modal" }, [
        el("div", { class: "pm-title" }, ["Private Match"]),
        el("div", { class: "pm-note" }, ["Enter your opponent's username. You'll each need to invite the other — the match starts once you both have."]),
        nameIn,
        el("div", { class: "pm-actions" }, [
          el("button", { class: "pm-btn", onclick: submit }, ["Send Invite"]),
          el("button", { class: "pm-btn secondary", onclick: close }, ["Cancel"]),
        ]),
      ]),
    ]);
  }
  function playerPanel() {
    const p = S.player || {};
    const streak = p.streak || 0;
    const ratio = "Ratio: " + (p.wins || 0) + " - " + (p.losses || 0) + " (" + (streak >= 0 ? "+" : "") + streak + ")";
    const teamSlots = [0, 1, 2].map((i) => {
      const pn = S.team[i], url = pn ? portraitUrlFor(pn) : null;
      const focused = pn && S.menuInspect && S.menuInspect.mode === "character" && S.menuInspect.path_name === pn;
      const kids = url ? [el("img", { class: "pt-img", src: url, alt: "", onerror: (e) => e.target.remove() })] : [];
      const attrs = { class: "pt-slot" + (pn ? " filled" : "") + (focused ? " focused" : ""), title: pn ? titleName(pn) + " — click to view, click again to remove" : "" };
      if (pn) attrs.onclick = () => selectAndInspect(pn);   // two-click: first shows info, second removes (mirrors the grid)
      return el("div", attrs, kids);
    });
    const avSrc = avatarSrc(p.avatar_url);   // http(s) upload, res:// bundled avatar, or the default
    const avatarKids = [el("img", { class: "pp-avatar-img", src: avSrc, alt: "", onerror: (e) => e.target.remove() })];
    return el("div", { class: "player-panel" }, [
      el("div", { class: "pp-top" }, [
        el("div", { class: "pp-details" }, [
          el("div", { class: "pp-name" }, [p.username || S.username || "Player"]),
          el("div", { class: "pp-title" }, [p.title || ""]),
          el("div", { class: "pp-meta" }, ["Clan: " + (p.clan || "Clanless")]),
          el("div", { class: "pp-meta" }, ["Rating: " + (p.rating != null ? Math.round(p.rating) : "?")]),
          el("div", { class: "pp-meta" }, [ratio]),
          el("div", { class: "pp-ap" }, ["AP " + (p.ap != null ? p.ap : 0)]),
        ]),
        el("div", { class: "pp-avatar", title: "Click to change your avatar", onclick: () => set({ avatarEdit: true }) }, avatarKids),
      ]),
      el("div", { class: "pp-team-label" }, ["Your Team (" + S.team.length + "/3)"]),
      el("div", { class: "pp-team" }, teamSlots),
      savedTeamsSection(),
    ]);
  }

  // A character's skills, derived from ability_info.json keys (<path_name><number>),
  // sorted by number — no separate manifest needed.
  function charAbilities(pathName) {
    if (!S.abilityInfo) return [];
    return Object.keys(S.abilityInfo)
      .filter((k) => k.startsWith(pathName) && /^\d+$/.test(k.slice(pathName.length)))
      .sort((a, b) => parseInt(a.slice(pathName.length)) - parseInt(b.slice(pathName.length)));
  }
  // abilities_data.json flags certain skills "important" (merged into ability_info.json). New
  // players get a gold "!" on these so a character's key skills stand out at a glance.
  // The significant-ability "!" marker is gated by the player's "Mark significant abilities"
  // setting. It defaults ON (matches the Godot client's mark_significant default of true), so it
  // shows unless the player has explicitly turned it off.
  function markSignificantOn() { return !(S.player && S.player.mark_significant === false); }
  function isImportant(basename) { return markSignificantOn() && !!(S.abilityInfo && S.abilityInfo[basename] && S.abilityInfo[basename].important); }
  function impTileBadge() { return el("span", { class: "skill-imp", title: "Important skill — worth knowing" }, ["!"]); }
  function impInline(cond) { return cond ? [el("span", { class: "desc-imp", title: "Important skill — worth knowing" }, ["!"]), " "] : []; }
  function inspectChar(pathName) { set({ menuInspect: { path_name: pathName, mode: "character" } }); }
  function inspectAbility(pathName, basename) { set({ menuInspect: { path_name: pathName, mode: "ability", basename: basename } }); }
  // Add/remove a character from the team (used by the info-panel button and the grid's second click).
  function toggleTeamMember(pn) {
    const c = findSelectChar(pn);
    if (c && !charUnlocked(c)) { set({ msg: "Unlock " + (c.name || "this character") + " to add them to your team", msgKind: "err" }); return; }
    const i = S.team.indexOf(pn);
    if (i >= 0) { S.team.splice(i, 1); persistTeam(); set({ msg: "" }); return; }
    if (S.team.length >= 3) { set({ msg: "Team is full — remove one first", msgKind: "err" }); return; }
    S.team.push(pn); persistTeam(); set({ msg: "" });
  }
  // Two-click grid selection: the first click focuses the character and shows its info; a second
  // click on the already-focused character adds it to the team (or removes it if already on it).
  // Locked characters CAN be focused (to read their info) — toggleTeamMember blocks actually adding.
  function selectAndInspect(pn) {
    const focused = S.menuInspect && S.menuInspect.mode === "character" && S.menuInspect.path_name === pn;
    if (!focused) { set({ menuInspect: { path_name: pn, mode: "character" }, msg: "" }); return; }
    toggleTeamMember(pn);
  }

  // Bounty categories (archetypes) a character belongs to + their icons. bounty_data.json
  // is loaded at startup; returns [] until it lands (the icons just don't show yet).
  function categoriesFor(pathName) {
    const cats = (S.bountyData && S.bountyData.categories) || {};
    return Object.keys(cats).filter((cat) => (cats[cat] || []).includes(pathName)).sort();
  }
  function categoryIcons(pathName, cls) {
    const cats = categoriesFor(pathName);
    if (!cats.length) return null;
    return el("div", { class: "cat-icons" + (cls ? " " + cls : "") }, cats.map((cat) =>
      el("img", { class: "cat-icon", src: resToUrl("res://assets/bounty/" + cat + ".png"), alt: titleCase(cat), title: titleCase(cat), onerror: (e) => e.target.remove() })));
  }
  // The middle-area info panel: char portrait + a clickable skill strip on top, and a
  // body that is the character bio (character mode) or the skill's full description
  // (ability mode — clicking a skill swaps the bio for it).
  function menuInfoPanel() {
    const ins = S.menuInspect;
    if (!ins) return el("div", { class: "menu-info empty" }, []);   // open middle area until a character is picked
    const pn = ins.path_name;
    const c = findSelectChar(pn);
    const purl = portraitUrlFor(pn);
    // Jin-woo shows only the equipped form's kit: each form is its own ability-key prefix
    // ("jinwoo" | "jinwoored" | …), and charAbilities' digit-suffix guard keeps the prefixes distinct.
    const abilities = charAbilities(pn === "jinwoo" && S.jinwooForm ? "jinwoo" + S.jinwooForm : pn);
    const topKids = [];
    // Clicking the portrait returns the panel to character/bio mode — otherwise, once a skill is
    // clicked (ability mode) there's no way back to the bio. inspectChar re-selects character mode.
    if (purl) topKids.push(el("img", { class: "mi-portrait", src: purl, alt: "", title: "View bio", onclick: () => inspectChar(pn), onerror: (e) => e.target.remove() }));
    topKids.push(el("div", { class: "mi-skills" }, abilities.map((bn) => {
      const icon = abilityIconUrl(bn), nm = (S.abilityInfo[bn] || {}).name || bn;
      const sel = ins.mode === "ability" && ins.basename === bn;
      const tile = el("div", { class: "mi-skill" + (sel ? " sel" : ""), title: nm },
        [icon ? el("img", { class: "abimg", src: icon, alt: "", onerror: (e) => { const dd = el("div", { class: "abn" }, [nm]); e.target.replaceWith(dd); } }) : el("div", { class: "abn" }, [nm])]);
      if (isImportant(bn)) tile.appendChild(impTileBadge());
      tile.addEventListener("click", () => inspectAbility(pn, bn));
      return tile;
    })));
    let body;
    if (ins.mode === "ability") {
      body = abilityBody(ins.basename);
    } else {
      const onTeam = S.team.indexOf(pn) >= 0;
      const locked = c && !charUnlocked(c);
      const teamFull = !onTeam && S.team.length >= 3;
      body = el("div", { class: "mi-body" }, [
        el("div", { class: "mi-name" }, [c ? c.name : titleCase(pn)]),
        categoryIcons(pn, "mi-cats"),
        el("div", { class: "mi-bio" }, [c && c.bio ? c.bio : "(no bio available)"]),
        el("button", { class: "mi-team-btn" + (onTeam ? " on" : ""), disabled: locked || teamFull, onclick: () => toggleTeamMember(pn) },
          [locked ? "🔒 Locked" : (onTeam ? "Remove from Team" : (teamFull ? "Team Full (3/3)" : "Add to Team"))]),
        pn === "toga" ? disguiseButton() : null,   // Toga passive: pick a character to start the match disguised as
        pn === "jinwoo" ? jinwooFormButton() : null,   // Jin-woo: equip one of 4 summons before the match
      ]);
    }
    // Close button dismisses the panel (clears the inspection + un-focuses the grid cell). On mobile the
    // panel is pinned to the top of the viewport as a pop-up (see .menu-info:not(.empty) in the mobile
    // media query), so this ✕ is how you put it away without scrolling.
    const closeBtn = el("button", { class: "mi-close", title: "Close", "aria-label": "Close skills panel", onclick: () => set({ menuInspect: null, msg: "" }) }, ["✕"]);
    // The content (skills + bio) lives in .mi-scroll so that when the panel is a fixed pop-up on mobile
    // and the content is taller than the viewport, only the content scrolls — the ✕ stays pinned.
    return el("div", { class: "menu-info" }, [closeBtn, el("div", { class: "mi-scroll" }, [el("div", { class: "mi-top" }, topKids), body])]);
  }

  // Toga-only control on her info panel. Opens the roster picker; the chosen character is
  // shown on the button and applied at match start via queueTeamPayload (4th queue element).
  function disguiseButton() {
    const dn = S.disguise;
    const set_ = dn && dn !== "toga";
    return el("div", { class: "mi-disguise" }, [
      el("button", { class: "mi-disguise-btn" + (set_ ? " set" : ""), title: "Pick a character to start the match disguised as",
        onclick: () => set({ disguisePicker: true, disguiseSel: S.disguise || "" }) },
        [set_ ? "Disguise: " + titleName(dn) : "Disguise"]),
      set_ ? el("button", { class: "mi-disguise-clear", title: "Clear disguise", onclick: () => commitPrematch({ disguise: "" }) }, ["×"]) : null,
    ]);
  }
  // Roster picker for Toga's disguise. Mirrors the char-select grid (same playable set + order);
  // click a tile to select, Confirm commits it to S.disguise (session-only, sent at queue time).
  function disguiseModal() {
    const close = () => set({ disguisePicker: false, disguiseSel: null });
    const base = (S.roster || []).filter((r) => CHAR_SELECT_SET.has(r.path_name) && r.path_name !== "toga")
      .sort((a, b) => CHAR_SELECT_RANK.get(a.path_name) - CHAR_SELECT_RANK.get(b.path_name));
    const sel = S.disguiseSel;
    const grid = el("div", { class: "menu-grid dg-grid" }, base.map((c) => {
      const thumb = portraitUrlFor(c.path_name);
      const kids = thumb ? [el("img", { class: "mg-img", src: thumb, alt: "", onerror: (e) => e.target.remove() })] : [];
      return el("div", { class: "mg-cell" + (sel === c.path_name ? " sel focused" : ""), title: c.name,
        onclick: () => set({ disguiseSel: c.path_name }) }, kids);
    }));
    const selName = sel && sel !== "toga" ? titleName(sel) : "None (no disguise)";
    const commit = () => commitPrematch({ disguise: sel && sel !== "toga" ? sel : "", disguisePicker: false, disguiseSel: null });
    return el("div", { class: "modal-overlay", onclick: (e) => { if (e.target.classList.contains("modal-overlay")) close(); } }, [
      el("div", { class: "modal-panel dg-modal" }, [
        el("div", { class: "dg-title" }, ["Choose a Disguise"]),
        el("div", { class: "dg-note" }, ["Toga starts the match disguised as this character. The disguise ends if she takes damage or uses a skill other than Thirsting Knife."]),
        el("div", { class: "dg-sel" }, ["Selected: ", el("b", {}, [selName])]),
        S.roster ? grid : el("div", { class: "note" }, ["Loading roster…"]),
        el("div", { class: "dg-actions" }, [
          el("button", { class: "dg-btn", onclick: commit }, ["Confirm"]),
          el("button", { class: "dg-btn secondary", onclick: () => set({ disguiseSel: "" }) }, ["No Disguise"]),
          el("button", { class: "dg-btn secondary", onclick: close }, ["Cancel"]),
        ]),
      ]),
    ]);
  }

  // Sung Jin-woo's 4 major summons. Equipping one swaps his kit to that color's variant (its ability
  // keys share the "jinwoo<color>" prefix); "" = basic all-Random Jin-woo. The choice is session-only
  // and rides queueTeamPayload as a "form:<color>" token.
  const JINWOO_SUMMONS = [
    { form: "red", name: "Igris", label: "Red" },
    { form: "green", name: "Beru", label: "Green" },
    { form: "white", name: "Tank", label: "White" },
    { form: "blue", name: "Tusk", label: "Blue" },
  ];
  const JINWOO_SUMMON_NAME = { red: "Igris", green: "Beru", white: "Tank", blue: "Tusk" };
  // Jin-woo-only control on his info panel. Opens the summon picker; the equipped summon shows on the
  // button and re-scopes the kit strip above (menuInfoPanel reads S.jinwooForm).
  function jinwooFormButton() {
    const f = S.jinwooForm;
    return el("div", { class: "mi-disguise" }, [
      el("button", { class: "mi-disguise-btn" + (f ? " set" : ""), title: "Equip a summon to change Jin-woo's kit before the match",
        onclick: () => set({ jinwooPicker: true }) },
        [f ? "Summon: " + JINWOO_SUMMON_NAME[f] + " (" + titleCase(f) + ")" : "Choose Summon"]),
      f ? el("button", { class: "mi-disguise-clear", title: "Return to basic Jin-woo", onclick: () => commitPrematch({ jinwooForm: "" }) }, ["×"]) : null,
    ]);
  }
  // Image-button picker: each summon tile shows <color>_section_image.png and swaps to
  // <color>_section_background.png on hover (stacked <img> + CSS). Clicking a tile commits immediately;
  // "Basic" returns to the all-Random default.
  function jinwooFormModal() {
    const close = () => set({ jinwooPicker: false });
    const pick = (form) => commitPrematch({ jinwooForm: form, jinwooPicker: false });
    const cur = S.jinwooForm;
    const tiles = JINWOO_SUMMONS.map((s) =>
      el("div", { class: "jw-form-tile jw-" + s.form + (cur === s.form ? " sel" : ""), title: s.name + " (" + s.label + ")", onclick: () => pick(s.form) }, [
        el("img", { class: "jw-form-img base", src: relToUrl("Sung Jin-woo/" + s.form + "_section_image.png"), alt: "", onerror: (e) => e.target.remove() }),
        el("img", { class: "jw-form-img hover", src: relToUrl("Sung Jin-woo/" + s.form + "_section_background.png"), alt: "", onerror: (e) => e.target.remove() }),
        el("div", { class: "jw-form-cap" }, [s.name]),
      ]));
    return el("div", { class: "modal-overlay", onclick: (e) => { if (e.target.classList.contains("modal-overlay")) close(); } }, [
      el("div", { class: "modal-panel jw-form-modal" }, [
        el("div", { class: "dg-title" }, ["Choose a Summon"]),
        el("div", { class: "dg-note" }, ["Equip one of Jin-woo's shadow soldiers to reshape his kit. Hover a summon to preview its color."]),
        el("div", { class: "jw-form-grid" }, tiles),
        el("div", { class: "dg-actions" }, [
          el("button", { class: "dg-btn" + (cur ? " secondary" : ""), onclick: () => pick("") }, ["Basic (no summon)"]),
          el("button", { class: "dg-btn secondary", onclick: close }, ["Cancel"]),
        ]),
      ]),
    ]);
  }

  // ---- Ranked draft --------------------------------------------------------
  // An ability's full-description body (icon, name, cost/cooldown, colored desc,
  // classes). Shared by the char-select info panel and the draft info panel.
  function abilityBody(basename) {
    const info = S.abilityInfo[basename] || {};
    const icon = abilityIconUrl(basename);
    let desc;
    const owner = basename.replace(/\d+$/, "");   // character path for skill-name disambiguation in hover keywords
    if (info.desc && info.desc.length) desc = el("div", { class: "desc-segs" }, info.desc.map((seg, i) => el("div", { class: "desc-seg" + (i === 0 ? " head" : "") }, GK.frag(seg.text, owner, { key: basename }))));
    else desc = el("div", { class: "desc-body" + (info.description ? "" : " muted") }, info.description ? GK.frag(info.description, owner, { key: basename }) : ["(description unavailable)"]);
    const main = [];
    if (icon) main.push(el("img", { class: "desc-img", src: icon, alt: "", onerror: (e) => e.target.remove() }));
    main.push(el("div", { class: "desc-text" }, [desc]));
    const bodyKids = [
      el("div", { class: "desc-header" }, [
        el("span", { class: "desc-name" }, impInline(isImportant(basename)).concat([info.name || basename])),
        isPassive(info) ? null : el("span", { class: "desc-meta" }, [
          el("span", { class: "desc-cost" }, costPips(info.cost || {})),
          el("span", { class: "desc-cd" }, ["Cooldown: " + (info.cooldown || 0)]),
        ]),
      ]),
      el("div", { class: "desc-main" }, main),
    ];
    if (info.classes && info.classes.length) bodyKids.push(el("div", { class: "desc-classes" }, ["Classes: " + info.classes.join(", ")]));
    return el("div", { class: "mi-body" }, bodyKids);
  }
  function charName(path) { const c = (S.roster || []).find((r) => r.path_name === path); return c ? c.name : titleCase(path); }
  function truncName(n) { return n && n.length > 12 ? n.slice(0, 11) + "…" : n; }
  // Mirrors the server's _can_pick: a starter, or the character's "<path>_unlock" gate is owned.
  function pathUnlocked(path) {
    const st = (S.bountyData && S.bountyData.starters) || [];
    if (st.includes(path)) return true;
    const unlocks = (S.player && S.player.unlocks) || [];
    return unlocks.includes(path + "_unlock") || unlocks.includes("all_unlock");
  }
  function queueRanked() {
    // Ranked is now a blind-pick ladder match (no draft) — it uses your selected team, like Quick.
    if (S.team.length !== 3) return set({ msg: "Pick a team of 3 to queue Ladder", msgKind: "err" });
    S.net.send("queue_ranked", { characters: queueTeamPayload() });
    set({ queued: true, msg: "In ladder queue…", msgKind: "ok" });
  }
  function onDraftStart(m) {
    set({
      screen: "draft", queued: false, privatePrompt: null, draftInspect: null,
      draft: {
        role: m.my_role, opponent: m.opponent || {}, pool: m.pool || [],
        firstPickerRole: m.first_picker_role, maxBans: m.max_bans || 3,
        phase: m.phase || "BAN", step: 0, actingRole: -1,
        picks: { p1: [], p2: [] }, bans: { p1: [], p2: [] }, bansRevealed: false,
        myBans: [], myBansLocked: false, oppBanCount: 0, deadline: m.deadline_unix || 0, selected: null,
      }, msg: "",
    });
  }
  function onDraftUpdate(m) {
    if (!S.draft) return;
    const d = Object.assign({}, S.draft, {
      phase: m.phase, step: m.step, actingRole: m.acting_role,
      picks: m.picks || S.draft.picks, bansRevealed: !!m.bans_revealed,
      myBans: m.my_bans || S.draft.myBans, myBansLocked: !!m.my_bans_locked,
      deadline: m.deadline_unix || S.draft.deadline, selected: null,
    });
    if (m.bans_revealed && m.bans) d.bans = m.bans;
    if (m.opp_ban_count != null) d.oppBanCount = m.opp_ban_count;
    set({ draft: d });
  }
  function draftIsMyTurn() {
    const d = S.draft; if (!d) return false;
    if (d.phase === "BAN") return !d.myBansLocked;
    if (d.phase === "PICK") return d.actingRole === d.role;
    return false;
  }
  function draftTileStatusFor(d, path) {
    const allPicks = ((d.picks && d.picks.p1) || []).concat((d.picks && d.picks.p2) || []);
    if (allPicks.includes(path)) return "picked";
    const myBansArr = d.myBans || [];
    if (d.phase === "BAN") return myBansArr.includes(path) ? "banned" : "available";
    const allBans = d.bansRevealed ? ((d.bans && d.bans.p1) || []).concat((d.bans && d.bans.p2) || []) : myBansArr;
    if (allBans.includes(path)) return "banned";
    if (!pathUnlocked(path)) return "locked";
    return "available";
  }
  function draftTileClick(path) {
    const d = S.draft; if (!d) return;
    const st = draftTileStatusFor(d, path);
    const canAct = (d.phase === "BAN" && !d.myBansLocked && st === "available") || (d.phase === "PICK" && draftIsMyTurn() && st === "available");
    const patch = { draftInspect: { path_name: path, mode: "character" } };
    if (canAct) { patch.draft = Object.assign({}, d, { selected: path }); S.net.send("draft_hover", { character: path }); }
    // Clicking an unavailable character (banned/picked/locked) clears the pending
    // selection so the Confirm button grays out instead of keeping the last pick.
    else if (d.selected != null) { patch.draft = Object.assign({}, d, { selected: null }); }
    set(patch);
  }
  function draftConfirm() {
    const d = S.draft; if (!d || !d.selected) return;
    if (d.phase === "BAN") { if (d.myBansLocked) return; S.net.send("submit_ban", { character: d.selected }); }
    else if (d.phase === "PICK") { if (!draftIsMyTurn()) return; S.net.send("submit_pick", { character: d.selected }); }
    set({ draft: Object.assign({}, d, { selected: null }) });
  }
  function draftLockBans() {
    const d = S.draft; if (!d || d.phase !== "BAN" || d.myBansLocked) return;
    S.net.send("lock_bans", {});
  }
  // Filter the draft pool by name directly in the DOM (no re-render) so typing keeps focus.
  function applyDraftFilter(q) {
    const grid = document.querySelector(".draft-pool");
    if (!grid) return;
    q = (q || "").toLowerCase();
    grid.querySelectorAll(".dp-cell").forEach((cell) => {
      cell.style.display = (!q || (cell.dataset.search || "").includes(q)) ? "" : "none";
    });
  }
  function draftInfoPanel() {
    const ins = S.draftInspect;
    if (!ins) return el("div", { class: "menu-info draft-info empty" }, [el("div", { class: "di-hint" }, ["Click a character to review their kit"])]);
    const pn = ins.path_name;
    const c = (S.roster || []).find((r) => r.path_name === pn);
    const purl = portraitUrlFor(pn);
    const abilities = charAbilities(pn);
    const topKids = [];
    if (purl) topKids.push(el("img", { class: "mi-portrait", src: purl, alt: "", title: "View bio", onclick: () => set({ draftInspect: { path_name: pn, mode: "character" } }), onerror: (e) => e.target.remove() }));
    topKids.push(el("div", { class: "mi-skills" }, abilities.map((bn) => {
      const icon = abilityIconUrl(bn), nm = (S.abilityInfo[bn] || {}).name || bn;
      const sel = ins.mode === "ability" && ins.basename === bn;
      const tile = el("div", { class: "mi-skill" + (sel ? " sel" : ""), title: nm },
        [icon ? el("img", { class: "abimg", src: icon, alt: "", onerror: (e) => { const dd = el("div", { class: "abn" }, [nm]); e.target.replaceWith(dd); } }) : el("div", { class: "abn" }, [nm])]);
      if (isImportant(bn)) tile.appendChild(impTileBadge());
      tile.addEventListener("click", () => set({ draftInspect: { path_name: pn, mode: "ability", basename: bn } }));
      return tile;
    })));
    let body;
    if (ins.mode === "ability") body = abilityBody(ins.basename);
    else body = el("div", { class: "mi-body" }, [
      el("div", { class: "mi-name" }, [c ? c.name : titleCase(pn)]),
      categoryIcons(pn, "mi-cats"),
      el("div", { class: "mi-bio" }, [c && c.bio ? c.bio : "(no bio available)"]),
    ]);
    return el("div", { class: "menu-info draft-info" }, [el("div", { class: "mi-top" }, topKids), body]);
  }
  function draftTimerBar() {
    const d = S.draft;
    const total = d && d.phase === "BAN" ? 60 : 30;
    const left = d ? Math.max(0, d.deadline - Date.now() / 1000) : 0;
    return el("div", { class: "draft-timer" }, [
      el("div", { class: "timer-bar mine" }, [el("i", { class: "timer-fill draft-timer-fill", style: "width:" + Math.min(100, (left / total) * 100) + "%" })]),
      el("span", { class: "draft-timer-txt" }, [Math.ceil(left) + "s"]),
    ]);
  }
  function draftScreen() {
    const d = S.draft;
    if (!d) return el("div", { class: "screen draft" }, ["Loading draft…"]);
    const myKey = d.role === 0 ? "p1" : "p2", oppKey = d.role === 0 ? "p2" : "p1";
    const myPicks = (d.picks && d.picks[myKey]) || [], oppPicks = (d.picks && d.picks[oppKey]) || [];
    const oppBans = d.bansRevealed ? ((d.bans && d.bans[oppKey]) || []) : null;

    function draftSlot(path, kind) {
      const kids = [];
      if (path) { const u = portraitUrlFor(path); if (u) kids.push(el("img", { class: "ds-img", src: u, alt: "", onerror: (e) => e.target.remove() })); }
      return el("div", { class: "draft-slot " + kind + (path ? " filled" : " empty"), title: path ? charName(path) : "", onclick: path ? (() => set({ draftInspect: { path_name: path, mode: "character" } })) : null }, kids);
    }
    function pickSlots(picks) { const o = []; for (let i = 0; i < 3; i++) o.push(draftSlot(picks[i] || null, "pick")); return o; }
    function banSlots(bans, hidden) {
      const o = [];
      for (let i = 0; i < 3; i++) {
        if (bans && bans[i]) o.push(draftSlot(bans[i], "ban"));
        else if (bans == null && i < hidden) o.push(el("div", { class: "draft-slot ban hidden" }, ["?"]));
        else o.push(draftSlot(null, "ban"));
      }
      return o;
    }
    function playerStrip(blob, picks, bans, hidden, mine) {
      return el("div", { class: "draft-player" + (mine ? " mine" : " enemy") }, [
        infoCard(blob, mine ? "You" : "Opponent", mine),
        el("div", { class: "draft-rating" }, ["★ " + (blob.rating != null ? blob.rating : "—")]),
        el("div", { class: "draft-slots" }, pickSlots(picks)),
        el("div", { class: "draft-bans" }, [el("span", { class: "db-label" }, ["BANS"]), el("div", { class: "draft-slots small" }, banSlots(bans, hidden))]),
      ]);
    }

    const ordered = (d.pool || []).slice().sort((a, b) => (CHAR_SELECT_RANK.has(a) ? CHAR_SELECT_RANK.get(a) : 999) - (CHAR_SELECT_RANK.has(b) ? CHAR_SELECT_RANK.get(b) : 999));
    const grid = el("div", { class: "draft-pool" }, ordered.map((path) => {
      const st = draftTileStatusFor(d, path);
      const kids = [];
      const u = portraitUrlFor(path);
      if (u) kids.push(el("img", { class: "dp-img", src: u, alt: "", onerror: (e) => e.target.remove() }));
      if (st === "banned") kids.push(el("div", { class: "dp-badge x" }, ["✕"]));
      else if (st === "picked") kids.push(el("div", { class: "dp-badge ok" }, ["✓"]));
      else if (st === "locked") kids.push(el("div", { class: "dp-badge lock" }, ["🔒"]));
      return el("div", { class: "dp-cell st-" + st + (d.selected === path ? " sel" : "") + (S.draftInspect && S.draftInspect.path_name === path ? " focused" : ""), title: charName(path), "data-search": (charName(path) + " " + path).toLowerCase(), onclick: () => draftTileClick(path) }, kids);
    }));

    const myTurn = draftIsMyTurn();
    let status;
    if (d.phase === "BAN") status = d.myBansLocked ? "Bans locked — waiting for opponent…" : "Ban Phase — ban up to " + (d.maxBans || 3);
    else if (d.phase === "PICK") status = myTurn ? "Your pick" : "Opponent is picking…";
    else status = "Starting battle…";
    const canConfirm = !!d.selected && ((d.phase === "BAN" && !d.myBansLocked) || (d.phase === "PICK" && myTurn));
    const confirmLabel = (d.phase === "PICK" && !myTurn) ? "Waiting…"
      : (d.phase === "BAN" ? "Ban" : "Pick") + (d.selected ? " " + truncName(charName(d.selected)) : "");

    return el("div", { class: "screen draft" }, [
      playerStrip(d.opponent || {}, oppPicks, oppBans, d.oppBanCount || 0, false),
      el("div", { class: "draft-mid" }, [
        el("div", { class: "draft-pool-wrap" }, [
          el("input", { class: "draft-search", placeholder: "Search characters…", value: S.draftSearch || "", spellcheck: "false", autocapitalize: "off",
            oninput: (e) => { S.draftSearch = e.target.value; applyDraftFilter(e.target.value); } }),
          grid,
        ]),
        draftInfoPanel(),
      ]),
      playerStrip(S.player || {}, myPicks, d.myBans || [], 0, true),
      el("div", { class: "draft-footer" }, [
        el("div", { class: "draft-status" + (myTurn ? " active" : "") }, [status]),
        draftTimerBar(),
        el("div", { class: "draft-actions" }, [
          (d.phase === "BAN" && !d.myBansLocked) ? el("button", { class: "queue-btn secondary", onclick: draftLockBans }, ["Lock Bans"]) : null,
          el("button", { class: "queue-btn", disabled: !canConfirm, onclick: draftConfirm }, [confirmLabel]),
        ]),
      ]),
    ]);
  }

  // Desktop layout mirroring the Godot battle scene: a 3-zone grid — top bar
  // (player card | center cluster | enemy card), arena (my column | status | enemy
  // column), bottom bar (controls | description panel). Collapses to one column on
  // narrow screens via CSS.
  function battleScreen() {
    const snap = S.snapshot;
    if (!snap) {
      return el("div", { class: "screen battle", style: bgStyle((S.player || {}).ingame_background) }, [
        el("div", { class: "arena-center" }, [el("div", { class: "note" }, ["Match found — waiting for the first snapshot…"])]),
      ]);
    }
    const myRole = S.match.canonical_role === 0 ? "p1" : "p2";
    const mySide = snap.sides.find((s) => s.role === myRole) || snap.sides[0];
    const oppSide = snap.sides.find((s) => s.role !== myRole) || snap.sides[1];
    const myBase = myRole === "p1" ? 0 : 3;
    const oppBase = myRole === "p1" ? 3 : 0;
    const myTurn = snap.acting_role === myRole;
    const over = !!S.matchResult;
    const interactive = myTurn && !over && !isViewer();   // viewer mode (replay/spectate) is read-only
    const rem = remainingPool();

    // Viewer mode: the cards show the two REPLAYED/WATCHED players, not the local account —
    // the "mine"-side card is whichever seat canonical_role points the camera at.
    const topbar = el("div", { class: "topbar" }, [
      infoCard(isViewer() ? (S.match.canonical_role === 0 ? S.viewer.p1_display : S.viewer.p2_display) : S.player, mySide.username, true),
      centerCluster(myTurn, over),
      infoCard(isViewer() ? (S.match.canonical_role === 0 ? S.viewer.p2_display : S.viewer.p1_display) : S.match.opponent, oppSide.username, false),
    ]);

    // Game over no longer renders inline (it bumped the board around); it pops as a
    // modal (gameOverModal) overlaid on the screen. arena-center only carries the
    // opponent-disconnected note now.
    const arena = el("div", { class: "arena" }, [
      el("div", { class: "team-col mine" }, mySide.team.map((c, i) => charCard(c, myBase + i, true, interactive, rem, i))),
      el("div", { class: "arena-center" }, S.oppGone && !over ? [el("div", { class: "note oppgone" }, ["⚠ Opponent disconnected — waiting…"])] : []),
      el("div", { class: "team-col enemy" }, oppSide.team.map((c, i) => charCard(c, oppBase + i, false, interactive, rem, i))),
    ]);

    const controls = [];
    controls.push(volumeBubble());   // audio volume — bottom-left bubble near Surrender (battle only)
    if (!over && !isViewer()) {      // a viewer has nothing to surrender
      controls.push(S.confirmSurrender
        ? el("div", { class: "surrender-confirm" }, [
            el("span", {}, ["Surrender? "]),
            el("a", { href: "#", class: "danger", onclick: (e) => { e.preventDefault(); surrender(); } }, ["Yes"]),
            el("span", {}, [" · "]),
            el("a", { href: "#", onclick: (e) => { e.preventDefault(); set({ confirmSurrender: false }); } }, ["Cancel"]),
          ])
        : el("a", { href: "#", class: "surrender-link", onclick: (e) => { e.preventDefault(); surrender(); } }, ["Surrender"]));
    }
    controls.push(el("a", { href: "#", class: "gloss-link", onclick: (e) => { e.preventDefault(); set({ glossaryOpen: true, glossQuery: "" }); } }, ["Glossary"]));   // term reference, available to players and viewers
    const bottombar = el("div", { class: "bottombar" }, [
      el("div", { class: "bottom-left" }, controls),
      descriptionPanel(),
    ]);

    return el("div", { class: "screen battle", style: bgStyle((S.player || {}).ingame_background) }, [topbar, arena, bottombar, over ? gameOverModal() : null]);
  }
  // Game-over popup: result banner + match details (type, AP gained) + return button.
  // Overlaid so it never reflows the board. AP gain is derived at match end (matchApGain);
  // "…" only shows for an outcome we can't derive (e.g. reconnect into a finished match).
  function gameOverModal() {
    // Viewer endings: a replay never pops the modal (the viewer-bar shows the winner); a live
    // spectate shows a neutral "Match Over" naming the winner — no AP/Rating (a viewer has no stake).
    if (isViewer()) {
      if (S.viewer.mode === "replay") return null;
      const wr = (S.matchResult || {}).winner_role;
      const wd = (wr === "p1" || wr === 0) ? S.viewer.p1_display : (wr === "p2" || wr === 1) ? S.viewer.p2_display : null;
      return el("div", { class: "modal-overlay" }, [
        el("div", { class: "modal-panel go-modal" }, [
          el("div", { class: "go-banner" }, ["Match Over"]),
          el("div", { class: "go-body" }, [
            el("div", { class: "go-rows" }, wd ? [el("div", { class: "go-row" }, [el("span", { class: "go-k" }, ["Winner"]), el("span", { class: "go-v" }, [wd.username || "?"])])] : []),
            el("button", { class: "endturn go-btn", onclick: viewerExit }, ["Return to Menu"]),
          ]),
        ]),
      ]);
    }
    const r = S.matchResult || {};
    const won = r.won;
    const title = won === true ? "★ Victory!" : won === false ? "Defeat" : "Match Over";
    const kind = won === true ? "win" : won === false ? "lose" : "";
    const rows = [];
    if (S.match && S.match.kind) rows.push(el("div", { class: "go-row" }, [el("span", { class: "go-k" }, ["Match type"]), el("span", { class: "go-v" }, [S.match.kind])]));
    rows.push(el("div", { class: "go-row" }, [el("span", { class: "go-k" }, ["AP gained"]),
      el("span", { class: "go-v go-ap" }, [r.apGain == null ? "…" : (r.apGain >= 0 ? "+" : "") + r.apGain])]));
    const rr = S.rankedResult;
    if (isRankedMatch() && rr && rr.delta != null) {
      const up = rr.delta >= 0;
      rows.push(el("div", { class: "go-row" }, [el("span", { class: "go-k" }, ["Rating"]),
        el("span", { class: "go-v go-rating " + (up ? "up" : "down") },
          [(up ? "+" : "") + rr.delta + " → " + rr.rating_after])]));
      rows.push(el("div", { class: "go-row" }, [el("span", { class: "go-k" }, ["Division"]),
        el("span", { class: "go-v go-divv" }, [rankBadge(rr.rank_after), divisionName(rr.rank_after, rr.tier_after)])]));
    }
    return el("div", { class: "modal-overlay" }, [   // no backdrop dismiss — must use the button
      el("div", { class: "modal-panel go-modal" }, [
        el("div", { class: "go-banner " + kind }, [title]),
        el("div", { class: "go-body" }, [
          el("div", { class: "go-rows" }, rows),
          divisionChangeBanner(),
          /campaign/i.test((S.match && S.match.kind) || "")
            ? el("button", { class: "endturn go-btn", onclick: returnToCampaign }, ["Continue"])
            : el("button", { class: "endturn go-btn", onclick: returnToMenu }, ["Return to Menu"]),
        ]),
      ]),
    ]);
  }

  // Rank badge art. assets/ui/badges ships "<rank> small.png" — note "masters small.png" (plural)
  // serves BOTH Master and Grandmaster, as there is no Grandmaster art; Rank.rank_emblem makes the
  // same substitution. A "<rank> badge.png" is preferred when present, so dropping new art into the
  // same directory picks it up with no code change; the onerror chain falls back to the shipped
  // small art, and removes the image entirely if neither resolves (never a broken-image icon).
  const BADGE_SMALL = ["iron", "bronze", "silver", "gold", "platinum", "diamond", "masters", "masters", "masters"];
  function rankBadge(rankIdx, cls) {
    if (RANKS[rankIdx] == null) return null;
    const preferred = resToUrl("res://assets/ui/badges/" + RANKS[rankIdx].toLowerCase() + " badge.png");
    const fallback = resToUrl("res://assets/ui/badges/" + BADGE_SMALL[rankIdx] + " small.png");
    return el("img", {
      // NOT loading="lazy": a deferred load defers the error too, so the fallback below would not
      // fire until the browser decided to fetch. These are two ~1KB images in an open modal.
      class: "rank-badge" + (cls ? " " + cls : ""), src: preferred, alt: "",
      onerror: (e) => {
        const t = e.target;
        if (t.dataset.fellBack) { t.remove(); return; }   // fallback missing too — drop it silently
        t.dataset.fellBack = "1";
        t.src = fallback;
      },
    });
  }

  // "Gold 3". Division 1 is the LOWEST inside a rank and 4 the highest (Rank.DIVISIONS).
  // Challenger is the open-ended top rank and carries NO division number (the server pins its tier
  // to 1 only so the ranked-queue bucket resolves), so it always renders as bare "Challenger".
  function divisionName(rankIdx, tier) {
    const name = RANKS[rankIdx] != null ? RANKS[rankIdx] : "?";
    if (name === "Challenger") return name;
    return tier != null ? name + " " + tier : name;
  }
  // The optional promotion/demotion callout. Only rendered when this match actually moved the
  // player across a division line — a normal ladder game shows nothing here.
  function divisionChangeBanner() {
    const rr = S.rankedResult;
    if (!isRankedMatch() || !rr || (!rr.promoted && !rr.demoted)) return null;
    const up = !!rr.promoted;
    // Crossing a whole RANK (Silver -> Gold) is the bigger moment and gets the louder treatment.
    const headline = rr.rank_changed
      ? (up ? "RANK UP!" : "Rank Lost")
      : (up ? "Promoted!" : "Demoted");
    return el("div", { class: "go-div " + (up ? "up" : "down") + (rr.rank_changed ? " major" : "") }, [
      el("div", { class: "go-div-head" }, [(up ? "▲ " : "▼ ") + headline]),
      el("div", { class: "go-div-move" }, [
        el("span", { class: "go-div-from" }, [rankBadge(rr.rank_before, "big"), divisionName(rr.rank_before, rr.tier_before)]),
        el("span", { class: "go-div-arrow" }, ["→"]),
        el("span", { class: "go-div-to" }, [rankBadge(rr.rank_after, "big"), divisionName(rr.rank_after, rr.tier_after)]),
      ]),
    ]);
  }

  // Top-left/right player cards: name, title, clan, rank+tier ("Bronze 1"), W-L.
  // Data comes from the display blobs (S.player / S.match.opponent), not the snapshot.
  function infoCard(blob, fallbackName, mine) {
    blob = blob || {};
    // 305x75 card background; the player's OWN card is mirrored (Godot convention).
    // Fall back to playercard_color_default when nothing specific is equipped.
    const cardId = (blob.player_card && blob.player_card !== "playercard_color_default") ? blob.player_card : "playercard_color_default";
    const cardImg = el("img", { class: "ic-card", src: cosmeticUrl("playercards", cardId), alt: "", onerror: (e) => e.target.remove() });
    const avSrc = avatarSrc(blob.avatar_url);   // same logic as the login/profile avatar
    const rankTxt = (blob.rank != null && RANKS[blob.rank] != null) ? divisionName(blob.rank, blob.tier) : "";
    const recTxt = (blob.wins != null || blob.losses != null) ? (blob.wins || 0) + " - " + (blob.losses || 0) : "";
    // Text block (name/title/clan/rank) is justified toward the avatar; the
    // avatar + win-loss record sit together on the inner (center-facing) edge.
    const textCol = el("div", { class: "ic-text" }, [
      el("div", { class: "ic-name" }, [blob.username || fallbackName || (mine ? "You" : "Opponent")]),
      el("div", { class: "ic-title" }, [blob.title || " "]),   // always present (nbsp) so the row keeps its space
      el("div", { class: "ic-clan" }, [blob.clan || "Clanless"]),
      rankTxt ? el("div", { class: "ic-rank" }, [rankTxt]) : null,
    ]);
    const sideCol = el("div", { class: "ic-side" }, [
      el("img", { class: "ic-avatar", src: avSrc, alt: "", onerror: (e) => e.target.remove() }),
      recTxt ? el("div", { class: "ic-record" }, [recTxt]) : null,
    ]);
    return el("div", { class: "infocard" + (mine ? " mine" : " enemy") }, [cardImg, textCol, sideCol]);
  }

  // Top-center: End Turn button, timer bar, energy pool + exchange (the energy panel).
  // Viewer mode swaps the End-Turn/"Waiting…" control AND the timer bar for the viewer-bar
  // (a viewer has no turn and no authoritative timer to mirror); the energy panel stays,
  // read-only, showing the watched seat's pool.
  function centerCluster(myTurn, over) {
    if (isViewer()) return el("div", { class: "cluster" }, [viewerBar(), energyPanel(false)]);
    const kids = [];
    if (!over) {
      if (myTurn) {
        kids.push(el("button", { class: "endturn", onclick: endTurn, disabled: S.acting },
          [S.staged.length ? ("End Turn (" + S.staged.length + ")") : "End Turn"]));
      } else {
        kids.push(el("div", { class: "endturn waiting" }, ["Waiting…"]));
      }
    }
    kids.push(timerBar(myTurn, over));
    kids.push(energyPanel(myTurn && !over));
    return el("div", { class: "cluster" }, kids);
  }
  // The viewer's control strip (replaces End Turn + timer). Replay: transport controls + scrubber +
  // turn counter + Exit, and the winner line once finished. Spectate: a badge + Leave.
  function viewerBar() {
    const v = S.viewer;
    if (!v) return el("span");   // renderer resilience: never throw without viewer state
    if (v.mode === "spectate") {
      // Clear "whose turn it is" indicator (the acting side), beyond the energy pools.
      const acting = S.snapshot && S.snapshot.acting_role;
      const actName = (acting === "p1" || acting === 0) ? (v.p1_display && v.p1_display.username)
        : (acting === "p2" || acting === 1) ? (v.p2_display && v.p2_display.username) : null;
      const over = S.snapshot && S.snapshot.match_over;
      return el("div", { class: "viewer-bar" }, [
        el("span", { class: "viewer-badge" }, ["SPECTATING"]),
        over ? el("span", { class: "viewer-turn" }, ["Match over"])
             : (actName ? el("span", { class: "viewer-turn" }, ["● " + actName + "'s turn"]) : null),
        el("button", { class: "viewer-btn", onclick: viewerExit }, ["Leave"]),
      ]);
    }
    const n = (v.frames || []).length, last = Math.max(0, n - 1);
    // "change" (not "input") so a drag isn't killed by the full re-render replacing the slider
    // under the pointer — the seek lands once on release.
    const scrub = el("input", { class: "viewer-scrub", type: "range", min: "0", max: String(last), value: String(v.idx || 0),
      onchange: (e) => replaySeek(Number(e.target.value)) });
    const kids = [
      el("button", { class: "viewer-btn", title: "Back one turn", onclick: () => replayStep(-1) }, ["⏮"]),
      el("button", { class: "viewer-btn", title: v.playing ? "Pause" : "Play", onclick: () => (v.playing ? replayPause() : replayPlay()) }, [v.playing ? "⏸" : "▶"]),
      el("button", { class: "viewer-btn", title: "Forward one turn", onclick: () => replayStep(1) }, ["⏭"]),
      el("button", { class: "viewer-btn", title: "Playback speed", onclick: replaySetSpeed }, [(v.speed || 1) + "x"]),
      scrub,
      el("span", {}, [(v.idx || 0) + "/" + last]),   // turn counter (styled via .viewer-bar span)
      v.raw ? el("button", { class: "viewer-btn", title: "Save this replay to your device", onclick: downloadReplay }, ["💾 Save"]) : null,
      el("button", { class: "viewer-btn", onclick: viewerExit }, ["Exit"]),
    ];
    if (v.finished) {
      const wr = v.winner_role;
      const wd = (wr === "p1" || wr === 0) ? v.p1_display : (wr === "p2" || wr === 1) ? v.p2_display : null;
      kids.push(el("div", { class: "viewer-winner" }, ["Winner: " + ((wd && wd.username) || "?")]));
    }
    return el("div", { class: "viewer-bar" }, kids);
  }

  // Cosmetic per-turn timer: depletes over 120s, reset on each turn/acting change.
  // The bar element renders full; a low-frequency interval (see bottom) drains it.
  // The turn's duration in ms. The server ships it as snapshot.turn_timer (seconds) so the cosmetic
  // bar matches the authoritative timer — including the shortened AFK-penalty timer for a player who
  // timed out and hasn't recovered with a manual turn. Falls back to the normal 120s.
  const DEFAULT_TURN_MS = 120000;
  function turnTimerMs() {
    const t = S.snapshot && Number(S.snapshot.turn_timer);
    return t && t > 0 ? t * 1000 : DEFAULT_TURN_MS;
  }
  function timerBar(myTurn, over) {
    if (over || !S.snapshot) return el("span");
    const key = S.snapshot.current_turn + ":" + S.snapshot.acting_role;
    if (key !== _timerKey) { _timerKey = key; _timerStart = Date.now(); }
    // Render at the true remaining level (not the CSS-default 100%) so a re-render — e.g.
    // clicking a skill — doesn't snap the bar to full and visibly transition back down.
    const durMs = turnTimerMs();
    const pct = Math.max(0, 1 - (Date.now() - _timerStart) / durMs) * 100;
    return el("div", { class: "timer-bar" + (myTurn ? " mine" : "") + (durMs < DEFAULT_TURN_MS ? " penalty" : "") }, [el("i", { class: "timer-fill", style: "width:" + pct + "%" })]);
  }

  // Bottom-right: shows a clicked skill's name/description/classes/cooldown.
  // The panel has two modes: "character" (a portrait + a scrollable skill strip — how
  // you inspect a character, incl. the enemy, whose skills aren't shown on the board)
  // and "ability" (one skill's image + description + classes + cooldown).
  function descriptionPanel() {
    const d = S.described;
    if (!d) return el("div", { class: "descpanel empty" }, [el("div", { class: "desc-hint" }, ["Click a character to see their skills, or a skill for its details."])]);
    return d.mode === "character" ? characterDescPanel(d.char_idx) : abilityDescPanel(d.ability, d.char_idx);
  }
  function abilityDescPanel(a, charIdx) {
    const info = (S.abilityInfo && S.abilityInfo[a.source_basename]) || {};
    // Always the skill's TRUE base cooldown (what it'll be when used) — never the live
    // remaining. Remaining shows only in the big tile overlay (abilityBar's .cd).
    const cd = info.cooldown || 0;
    const icon = wireAbilityIcon(a);
    let body;
    const owner = (a.source_basename || "").replace(/\d+$/, "");   // character path for skill-name hover disambiguation
    const self = { key: a.source_basename };                       // a skill's own name in its own text isn't a link
    if (info.desc && info.desc.length) {
      // split_desc segments (the source of truth): headline + colored sub-effects.
      body = el("div", { class: "desc-segs" }, info.desc.map((seg, i) =>
        el("div", { class: "desc-seg" + (i === 0 ? " head" : "") }, GK.frag(seg.text, owner, self))));
    } else {
      body = el("div", { class: "desc-body" + (info.description ? "" : " muted") }, info.description ? GK.frag(info.description, owner, self) : ["(description unavailable)"]);
    }
    const main = [];
    if (icon) main.push(el("img", { class: "desc-img", src: icon, alt: "", onerror: (e) => e.target.remove() }));
    main.push(el("div", { class: "desc-text" }, [body]));
    const kids = [];
    // Quick-nav strip: the character's whole kit, current skill highlighted — click to jump
    // between abilities without going back to the character view.
    if (charIdx != null) kids.push(el("div", { class: "desc-nav" }, descSkillTiles(charIdx, "desc-nav-skill", a.source_basename)));
    kids.push(el("div", { class: "desc-header" }, [
      el("span", { class: "desc-name" }, impInline(isImportant(a.source_basename)).concat([a.ability_name || info.name || "Skill"])),
      isPassive(info) ? null : el("span", { class: "desc-meta" }, [
        el("span", { class: "desc-cost" }, costPips(a.cost || info.cost || {})),
        el("span", { class: "desc-cd" }, ["Cooldown: " + cd]),
      ]),
    ]));
    kids.push(el("div", { class: "desc-main" }, main));
    if (info.classes && info.classes.length) kids.push(el("div", { class: "desc-classes" }, ["Classes: " + info.classes.join(", ")]));
    return el("div", { class: "descpanel" }, kids);
  }
  // The character's full kit as clickable skill tiles — shared by the character view (large tiles)
  // and the ability view's top nav strip (compact, `activeBasename` highlighted). Full kit = every
  // ability in the moveset (charAbilities), not just the 4 active slots; active skills reuse their
  // live snapshot object, the rest are built from static ability info, extras appended.
  function descSkillTiles(charIdx, cls, activeBasename) {
    const c = snapChar(charIdx);
    if (!c) return [];
    // Disguised (Toga): show the disguise's kit built from static ability info, and DROP the real
    // live slots (c.abilities) so her actual skills / cooldowns can't leak. Once the disguise ends,
    // portrait_disguise clears and this reverts to her real live kit.
    const active = c.portrait_disguise ? [] : (c.abilities || []);
    // Jin-woo's hidden/full kit is the equipped form's prefix (the summon swap-in lives there); the
    // wire snapshot carries summon_form so the opponent browses the right form, not the default kit.
    const kit = charAbilities(c.portrait_disguise || (c.path_name === "jinwoo" && c.summon_form ? "jinwoo" + c.summon_form : c.path_name));
    const extra = active.map((x) => x.source_basename).filter((bn) => kit.indexOf(bn) < 0);
    const bases = (kit.length ? kit : active.map((x) => x.source_basename)).concat(kit.length ? extra : []);
    return bases.map((bn, j) => {
      const info = (S.abilityInfo && S.abilityInfo[bn]) || {};
      const a = active.find((x) => x.source_basename === bn)
        || { source_basename: bn, ability_name: info.name || bn, cost: info.cost || {}, cooldown_remaining: null };
      const icon = wireAbilityIcon(a);
      const sel = bn === activeBasename;
      const tile = el("div", { class: cls + (sel ? " sel" : ""), title: a.ability_name },
        [icon ? el("img", { class: "abimg", src: icon, alt: "", onerror: (e) => { const dd = el("div", { class: "abn" }, [a.ability_name]); e.target.replaceWith(dd); } }) : el("div", { class: "abn" }, [a.ability_name])]);
      if (isImportant(bn)) tile.appendChild(impTileBadge());
      tile.addEventListener("click", () => describe(charIdx, j, a));
      return tile;
    });
  }
  function characterDescPanel(charIdx) {
    const c = snapChar(charIdx);
    if (!c) return el("div", { class: "descpanel empty" }, [el("div", { class: "desc-hint" }, ["—"])]);
    const purl = portraitUrl(c);
    const headKids = [];
    if (purl) headKids.push(el("img", { class: "desc-char-portrait", src: purl, alt: "", onerror: (e) => e.target.remove() }));
    // While Toga's disguise is active the wire carries portrait_disguise (the disguised-as path_name).
    // Present THAT character's name/categories/skills, matching the portrait, so she can't be trivially
    // unmasked from the info panel. Reverts to her real identity the moment the disguise ends.
    const path = c.portrait_disguise || c.path_name;
    // Append the equipped summon so the opponent can see which Jin-woo they're facing ("Sung Jin-woo (Red)").
    const dispName = titleName(path) + (c.path_name === "jinwoo" && c.summon_form ? " (" + titleCase(c.summon_form) + ")" : "");
    const nameCol = [el("div", { class: "desc-name" }, [dispName])];
    const catsRow = categoryIcons(path, "desc-cats");
    if (catsRow) nameCol.push(catsRow);
    const uni = (findSelectChar(path) || {}).universe;   // universe label on the in-battle character-info panel
    if (uni) nameCol.push(el("div", { class: "desc-universe" }, [uni]));
    headKids.push(el("div", { class: "desc-namecol" }, nameCol));
    const skills = el("div", { class: "desc-skills" }, descSkillTiles(charIdx, "desc-skill", null));
    return el("div", { class: "descpanel" }, [el("div", { class: "desc-char-head" }, headKids), skills]);
  }
  function snapChar(idx) {
    const snap = S.snapshot; if (!snap) return null;
    const p1 = snap.sides.find((s) => s.role === "p1"), p2 = snap.sides.find((s) => s.role === "p2");
    return idx < 3 ? (p1 && p1.team[idx]) : (p2 && p2.team[idx - 3]);
  }
  function describe(charIdx, abilityIdx, a) { set({ described: { mode: "ability", char_idx: charIdx, ability_idx: abilityIdx, ability: a } }); }
  function describeCharacter(charIdx) { set({ described: { mode: "character", char_idx: charIdx } }); }

  // ---- battle pieces -------------------------------------------------------
  // ===== Glossary keyword hover system ======================================================
  // Colored, hoverable keywords inside ability descriptions and effect panels. Terms + skill
  // names come from skill_glossary.json (compiled by GK.build). Hovering a keyword opens a
  // popover; that popover's own keywords are hoverable too, forming a CHAIN that stays open
  // while the mouse is anywhere in it. Click a popover to PIN it (persists after the mouse
  // leaves, until closed with ×). All popovers live at <body> so they escape the board's
  // clipping, and are torn down on every re-render (their anchors go stale). See [[skill-glossary]].
  const GK = (function () {
    let TERMS = {}, SKILLS = {}, CATS = {}, LOOK = new Map(), NAME2SLUG = new Map(), RE = null;
    const reEsc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

    // Compile the matcher: one case-insensitive regex over every term alias + skill name, longest
    // phrase first (so "Damage over time" beats "damage"), terms winning ties over skills.
    function build(g) {
      if (!g || !g.terms) return;
      TERMS = g.terms; SKILLS = g.skills || {}; CATS = g.categories || {};
      LOOK = new Map(); NAME2SLUG = new Map();
      const phrases = [];
      for (const slug in TERMS) {
        const t = TERMS[slug];
        NAME2SLUG.set(String(t.term || "").toLowerCase(), slug);
        if (t.display) NAME2SLUG.set(String(t.display).toLowerCase(), slug);
        for (const a of (t.aliases || [t.term])) {
          if (!a || a.indexOf("…") >= 0) continue;              // skip display placeholders ("Swaps to …")
          const k = a.toLowerCase();
          if (!NAME2SLUG.has(k)) NAME2SLUG.set(k, slug);        // still reachable via see-also / class chips / search
          if (t.match === false) continue;                     // generic filler ("turn") — not auto-highlighted in prose
          if (!LOOK.has(k)) { LOOK.set(k, { kind: "term", slug: slug }); phrases.push({ p: a, len: a.length, kind: 0 }); }
        }
      }
      for (const name in SKILLS) {                                    // term aliases win over a same-string skill name
        if (!name) continue;
        const k = name.toLowerCase();
        if (!LOOK.has(k)) { LOOK.set(k, { kind: "skill", name: name }); phrases.push({ p: name, len: name.length, kind: 1 }); }
      }
      phrases.sort((a, b) => b.len - a.len || a.kind - b.kind || a.p.localeCompare(b.p));
      const alt = phrases.map((x) => reEsc(x.p)).join("|");
      try { RE = alt ? new RegExp("(?<![A-Za-z0-9])(?:" + alt + ")(?![A-Za-z0-9])", "gi") : null; }
      catch (e) { RE = null; }                                        // no lookbehind support → degrade to plain text
    }

    function skillKey(name, ownerChar) {
      const arr = SKILLS[name]; if (!arr || !arr.length) return null;
      if (ownerChar) { const m = arr.find((e) => e.char === ownerChar); if (m) return m.key; }
      return arr[0].key;                                              // collisions: fall back to the first character
    }

    // Turn a plain string into a node list: text nodes + keyword <span>s. ownerChar disambiguates
    // a skill-name reference to the character whose description we're rendering. `self` (a {slug} or
    // {key}) is the entry THIS text belongs to — a keyword that resolves to it is left un-highlighted
    // so a panel never links back to a fresh copy of itself.
    function frag(text, ownerChar, self) {
      const out = [];
      if (text == null) return out;
      text = String(text);
      if (!RE || S.gkKeywords === false) { out.push(document.createTextNode(text)); return out; }   // keyword highlighting off -> plain text (effect-tooltip hover is separate)
      RE.lastIndex = 0;
      let last = 0, m;
      while ((m = RE.exec(text))) {
        const s = m.index, e = s + m[0].length;
        if (s > last) out.push(document.createTextNode(text.slice(last, s)));
        out.push(kw(m[0], ownerChar, self) || document.createTextNode(m[0]));
        last = e;
        if (RE.lastIndex <= s) RE.lastIndex = s + 1;                  // zero-width guard
      }
      if (last < text.length) out.push(document.createTextNode(text.slice(last)));
      return out;
    }

    function kw(matched, ownerChar, self) {
      const info = LOOK.get(matched.toLowerCase()); if (!info) return null;
      let cat, gk;
      if (info.kind === "term") {
        if (self && self.slug === info.slug) return null;            // don't link a term to its own panel
        const t = TERMS[info.slug]; if (!t) return null; cat = t.category; gk = { kind: "term", slug: info.slug };
      } else {
        const key = skillKey(info.name, ownerChar); if (!key) return null;
        if (self && self.key === key) return null;                  // don't link a skill to itself
        cat = "skill"; gk = { kind: "skill", key: key };
      }
      const span = el("span", { class: gkClass(cat), tabindex: "0", role: "button", "aria-haspopup": "dialog" }, [matched]);
      span.__gk = gk; wireAnchor(span); return span;
    }
    // "gk gk-<cat>" normally; one uniform class when the player has turned off per-category colors.
    function gkClass(cat) { return S.gkColors === false ? "gk gk-mono" : "gk gk-" + cat; }
    // A pre-bound anchor for see-also / class chips (opens a specific term or skill).
    function anchor(label, gk, cat) { const span = el("span", { class: gkClass(cat), tabindex: "0", role: "button", "aria-haspopup": "dialog" }, [label]); span.__gk = gk; wireAnchor(span); return span; }
    function termChip(label) {
      const slug = NAME2SLUG.get(String(label).toLowerCase());
      if (!slug || !TERMS[slug]) return document.createTextNode(label);
      return anchor(label, { kind: "term", slug: slug }, TERMS[slug].category);
    }
    function wireAnchor(span) {
      span.addEventListener("pointerenter", (ev) => {
        if (ev.pointerType && ev.pointerType !== "mouse") return;
        hoverAdd(span);
        const host = containing(span);
        if (host && nowMs() < host._armAt) return;   // host panel just spawned under the cursor — don't chain-open until it arms
        openFor(span, false);
      });
      span.addEventListener("pointerleave", (ev) => { if (ev.pointerType && ev.pointerType !== "mouse") return; hoverDel(span); scheduleSweep(); });
      // Tap / click opens AND pins — the only way to explore the chain without a hovering mouse (touch).
      span.addEventListener("click", (ev) => { ev.stopPropagation(); ev.preventDefault(); const p = openFor(span, true); if (p) togglePin(p, true); });
      // Keyboard: the span is focusable (tabindex/role button), so Enter/Space must open + pin it too.
      span.addEventListener("keydown", (ev) => { if (ev.key === "Enter" || ev.key === " ") { ev.preventDefault(); const p = openFor(span, true); if (p) togglePin(p, true); } });
    }

    // ---- panel chain manager ----
    // A panel stays open while it is pinned, hovered, its anchor is hovered, or any child is retained.
    // A short grace timer bridges the mouse moving from anchor → panel → nested keyword → child panel.
    const panels = [];
    const hover = new Set();
    // A freshly-spawned panel's own keywords are NOT hoverable for this long. Without it, dragging the cursor
    // down-and-right paints a diagonal chain: each panel pops up under the moving mouse, which immediately
    // hovers a keyword on it and spawns the next. The delay lets the cursor pass over a just-appeared panel
    // without chaining; a deliberate (slower) hover still opens after the brief arm. Clicks are never gated.
    const GK_ARM_MS = 650;
    const nowMs = () => (window.performance && performance.now ? performance.now() : Date.now());
    let sweepT = null;
    function hoverAdd(x) { hover.add(x); if (sweepT) { clearTimeout(sweepT); sweepT = null; } }
    function hoverDel(x) { hover.delete(x); }
    function scheduleSweep() { if (sweepT) clearTimeout(sweepT); sweepT = setTimeout(sweep, 60); }   // short grace: just bridges the ~6px anchor→panel gap
    const childrenOf = (p) => panels.filter((q) => q.parent === p);
    function retained(p) { return p.pinned || hover.has(p.el) || (p.anchor && hover.has(p.anchor)) || childrenOf(p).some(retained); }
    function sweep() {
      sweepT = null;
      let changed = true;
      while (changed) { changed = false; for (let i = panels.length - 1; i >= 0; i--) { if (!retained(panels[i])) { closePanel(panels[i]); changed = true; } } }
    }
    function closePanel(p) {
      if (panels.indexOf(p) < 0) return;
      childrenOf(p).slice().forEach(closePanel);
      const i = panels.indexOf(p); if (i >= 0) panels.splice(i, 1);
      if (p.anchor && p.anchor.__panel === p) p.anchor.__panel = null;
      hover.delete(p.el);
      if (p.el && p.el.parentNode) p.el.parentNode.removeChild(p.el);
      if (p.onClose) p.onClose();
    }
    function closeAll() { while (panels.length) closePanel(panels[panels.length - 1]); hover.clear(); if (sweepT) { clearTimeout(sweepT); sweepT = null; } }
    function closeByEl(elm) { const p = panels.find((q) => q.el === elm); if (p) closePanel(p); }
    function closeUnpinned() {                                         // keep pinned panels + their ancestors/descendants
      const keep = new Set();
      panels.forEach((p) => { if (p.pinned) { let a = p; while (a) { keep.add(a); a = a.parent; } (function md(x) { childrenOf(x).forEach((c) => { keep.add(c); md(c); }); })(p); } });
      panels.slice().forEach((p) => { if (!keep.has(p)) closePanel(p); });
    }
    // Called when #app is rebuilt (render()): every anchor is about to be detached. Drop the unpinned
    // popovers, but KEEP pinned ones (the pin contract = persists until closed) — severing their now-dead
    // anchor so they float as standalone cards (still retained via .pinned) and a freshly-rendered
    // keyword can't collide with a stale __panel back-reference.
    function onRerender() {
      closeUnpinned();
      panels.forEach((p) => { if (p.anchor) { if (p.anchor.__panel === p) p.anchor.__panel = null; p.anchor = null; } });
      hover.clear(); if (sweepT) { clearTimeout(sweepT); sweepT = null; }
    }
    function register(elm, anchorEl, parent, onClose) {
      const p = { el: elm, anchor: anchorEl || null, parent: parent || null, pinned: false, onClose: onClose || null, _close: null, _armAt: nowMs() + GK_ARM_MS };
      panels.push(p);
      if (anchorEl) anchorEl.__panel = p;
      elm.addEventListener("pointerenter", (ev) => { if (ev.pointerType && ev.pointerType !== "mouse") return; hoverAdd(elm); });
      elm.addEventListener("pointerleave", (ev) => { if (ev.pointerType && ev.pointerType !== "mouse") return; hoverDel(elm); scheduleSweep(); });
      elm.addEventListener("click", (ev) => { if (ev.target.closest && ev.target.closest(".gk, .gk-close")) return; ev.stopPropagation(); togglePin(p); });
      return p;
    }
    function togglePin(p, forceOn) {
      p.pinned = forceOn ? true : !p.pinned;
      p.el.classList.toggle("pinned", p.pinned);
      if (p.pinned && !p._close) { p._close = el("button", { class: "gk-close", title: "Close", onclick: (e) => { e.stopPropagation(); closePanel(p); scheduleSweep(); } }, ["×"]); p.el.appendChild(p._close); }   // sweep clears any ancestor left un-retained
      else if (!p.pinned && p._close) { p._close.remove(); p._close = null; }
    }
    const containing = (node) => { for (const p of panels) if (p.el.contains(node)) return p; return null; };
    function position(panel, anchorEl) {
      const r = anchorEl.getBoundingClientRect(), pw = panel.offsetWidth, ph = panel.offsetHeight;
      let left = r.left, top = r.bottom + 6;
      if (left + pw > window.innerWidth - 8) left = window.innerWidth - pw - 8;
      if (top + ph > window.innerHeight - 8) top = r.top - ph - 6;    // flip above if it would run off the bottom
      panel.style.left = Math.max(8, left) + "px";
      panel.style.top = Math.max(8, top) + "px";
    }
    function openFor(anchorEl, forcePin) {
      if (anchorEl.__panel) { if (forcePin) togglePin(anchorEl.__panel, true); return anchorEl.__panel; }
      const gk = anchorEl.__gk; if (!gk) return null;
      const content = gk.kind === "term" ? termContent(gk.slug) : skillContent(gk.key);
      if (!content) return null;
      const panel = el("div", { class: "gk-panel gk-panel-" + content.cat }, content.nodes);
      document.body.appendChild(panel);
      position(panel, anchorEl);
      const p = register(panel, anchorEl, containing(anchorEl), null);
      if (forcePin) togglePin(p, true);   // pin first so a click/keyboard open survives the prune below
      // A panel stays only while it, its anchor, or a descendant is hovered (or it's pinned). hoverAdd()
      // on the new anchor just cancelled the pending grace sweep, so run it NOW: this closes whatever you
      // hopped away from at ANY depth — a sibling keyword's panel on the same source panel included.
      sweep();
      return p;
    }

    const catLabel = (cat) => (CATS[cat] && CATS[cat].label) || cat;
    const head = (cat, title) => el("div", { class: "gk-head" }, [el("span", { class: "gk-cat gk-cat-" + cat }, [catLabel(cat)]), el("span", { class: "gk-title" }, [title])]);
    function chipRow(labelText, items) {
      const row = [el("span", { class: "gk-see-lbl" }, [labelText])];
      items.forEach((n, i) => { if (i) row.push(document.createTextNode(", ")); row.push(termChip(n)); });
      return row;
    }
    function termContent(slug) {
      const t = TERMS[slug]; if (!t) return null;
      const nodes = [head(t.category, t.display || t.term), el("div", { class: "gk-def" }, frag(t.definition, null, { slug: slug }))];
      if (t.see_also && t.see_also.length) nodes.push(el("div", { class: "gk-see" }, chipRow("See also: ", t.see_also)));
      return { cat: t.category, nodes: nodes };
    }
    function skillContent(key) {
      const info = S.abilityInfo && S.abilityInfo[key]; if (!info) return null;
      const ownerChar = key.replace(/\d+$/, "");
      const nodes = [head("skill", info.name || key)];
      const isPass = info.classes && info.classes.indexOf("Passive") >= 0;
      if (!isPass) nodes.push(el("div", { class: "gk-meta" }, ["Cooldown: " + (info.cooldown || 0)]));
      if (info.desc && info.desc.length) {
        nodes.push(el("div", { class: "gk-segs" }, info.desc.map((seg, i) =>
          el("div", { class: "gk-seg" + (i === 0 ? " head" : "") }, frag(seg.text, ownerChar, { key: key })))));
      } else if (info.description) {
        nodes.push(el("div", { class: "gk-def" }, frag(info.description, ownerChar, { key: key })));
      }
      if (info.classes && info.classes.length) nodes.push(el("div", { class: "gk-classes" }, chipRow("Classes: ", info.classes)));
      return { cat: "skill", nodes: nodes };
    }

    return { build: build, frag: frag, position: position, register: register, containing: containing,
             hoverAdd: hoverAdd, hoverDel: hoverDel, scheduleSweep: scheduleSweep, prune: sweep,
             closeAll: closeAll, closeByEl: closeByEl, closeUnpinned: closeUnpinned, onRerender: onRerender };
  })();

  // ---- effect tooltips -----------------------------------------------------
  // Group a character's wire effects into clusters keyed by (name, unique_render_id) — one
  // icon tooltip per cluster, mirroring the game's effect_storage_component clustering. Effects
  // with the same name but different unique_render_id get separate clusters (same image, own panel).
  // --- invisibility sensing (ported from effect_storage_component.get_effect_clusters) ---------
  // Some kits let the local player see the OPPONENT's invisible effects: Toph's passive senses
  // invisible *Physical* enemy effects, and Kurotsuchi Mayuri's "Data Collection" mark reveals
  // *every* invisible enemy effect. The server ships all invisible effects on the wire (it filters
  // nothing but system effects), so this reveal is decided client-side exactly as the Godot client
  // did. character_in_team() requires the sensor ALIVE, so a dead/banished Toph or Mayuri senses
  // nothing.
  const MARK_EFFECT_TYPE = 25;   // EffectType.Type.MARK ordinal — scripts/types/effect_type.gd (append-only enum)
  // The viewer's own (canonical-role) team from the snapshot — independent of which card we render.
  function viewerTeam() {
    const snap = S.snapshot;
    if (!snap || !snap.sides) return [];
    const myRole = (S.match && S.match.canonical_role === 1) ? "p2" : "p1";
    const side = snap.sides.find((s) => s.role === myRole);
    return (side && side.team) || [];
  }
  function charHasEffect(ch, name, effectType) {
    return (ch.effects || []).some((e) => e.name === name && e.effect_type === effectType);
  }
  // Which enemy-invisibility senses the viewer's team currently has active. Mirrors the two
  // hard-coded cases in get_effect_clusters (Toph physical-sense, Kurotsuchi Data-Collection).
  function viewerRevealCaps() {
    let toph = false, kurotsuchi = false;
    for (const ch of viewerTeam()) {
      if (ch.dead || ch.banished) continue;
      if (ch.path_name === "toph") toph = true;
      else if (ch.path_name === "kurotsuchi" && charHasEffect(ch, "Data Collection", MARK_EFFECT_TYPE)) kurotsuchi = true;
    }
    return { toph, kurotsuchi };
  }
  // Data Collection reveals every invisible enemy effect; Toph reveals only invisible *Physical* ones.
  function canSenseInvisibleEffect(e, caps) {
    return caps.kurotsuchi || (caps.toph && !!e.is_physical);
  }

  function effectClusters(effects, mine) {
    const map = new Map();
    // An "invisible" effect (visibility != "all") is visible ONLY to the side that CAST it — decide
    // by the caster (e.user, a canonical 0-5 index) relative to the viewer, NOT by which character
    // the effect sits on. Keying on the host character (the old `!mine` check) leaked an enemy's
    // invisible debuff applied to MY character (e.g. Yubel's hidden taunt) and conversely hid my own
    // invisible effect on an enemy from me, its caster. Mirrors effectTooltip's eff-ally/eff-enemy logic.
    // EXCEPTION: an invisibility-sensing kit on the viewer's team (Toph / Kurotsuchi) reveals the
    // opponent's invisible effects — see viewerRevealCaps / canSenseInvisibleEffect above.
    const myBase = (S.match && S.match.canonical_role === 1) ? 3 : 0;
    const caps = viewerRevealCaps();
    for (const e of effects) {
      // system = engine machinery, not rendered. display_system opts an effect out of that while
      // keeping system's cleanse-survival semantics server-side (Effect.display_system) — those ARE
      // player-facing and must render like any other effect.
      if (e.system && !e.display_system) continue;
      if (e.visibility !== "all") {                    // invisible: only its caster's side may see it…
        // A live spectator is NEUTRAL: no invisible effect from either side (belt+braces with the
        // server-side strip). A replay keeps the participant's real seat — existing logic is correct.
        if (S.viewer && S.viewer.mode === "spectate") continue;
        const u = e.user;
        const casterIsMine = (u != null && u >= myBase && u < myBase + 3);
        if (!casterIsMine && !canSenseInvisibleEffect(e, caps)) continue;   // …unless the viewer senses it
      }
      const key = e.name + "@" + e.unique_render_id;
      if (!map.has(key)) map.set(key, []);
      map.get(key).push(e);
    }
    return Array.from(map.values());
  }
  // Wire durations are doubled (2 ticks/turn); -1 = permanent. Mirrors EffectTooltipHoverPanel.
  function effDurationText(d) {
    if (d > 0) d = Math.floor(d / 2);
    if (d === -1) return "Permanent";
    if (d < 1) return "Ends this turn";
    return d + " turn" + (d === 1 ? "" : "s") + " left";
  }
  function hideEffPanel() { if (_effPanel) GK.closeByEl(_effPanel); }   // onClose (below) clears _effPanel/_effAnchor
  function showEffPanel(cluster, anchor) {
    hideEffPanel();
    // Drop any stale keyword popover BEFORE opening this panel — prune runs a hover-based sweep, and on
    // TOUCH the anchor is never in GK's hover set (pointerenter is mouse-gated), so pruning AFTER register
    // would immediately sweep the just-opened panel and nothing would show on tap. Pruning first cleans up
    // stale popovers without touching the new panel; on desktop the panel is hover-retained regardless.
    GK.prune();
    // Consolidate the cluster: one block per distinct description, listing the durations under it.
    const byDesc = new Map();
    for (const e of cluster) { const d = e.description || ""; if (!byDesc.has(d)) byDesc.set(d, []); byDesc.get(d).push(e.duration); }
    const kids = [el("div", { class: "efp-name" }, [cluster[0].name])];
    for (const [desc, durs] of byDesc) {
      if (desc) kids.push(el("div", { class: "efp-desc" }, GK.frag(desc, null)));   // effect desc: same hoverable keywords
      kids.push(el("div", { class: "efp-durs" }, durs.map((d) => el("span", { class: "efp-dur" }, [effDurationText(d)]))));
    }
    const panel = el("div", { class: "eff-panel" }, kids);
    document.body.appendChild(panel);
    GK.position(panel, anchor);
    _effPanel = panel; _effAnchor = anchor;
    // Join the glossary popover chain as a root so it persists while hovered / while a spawned
    // keyword popover is alive, and is torn down through the same sweep + on re-render.
    GK.register(panel, anchor, null, () => { if (_effPanel === panel) { _effPanel = null; _effAnchor = null; } });
  }
  function effectTooltip(cluster) {
    const e0 = cluster[0], ic = resToUrl(e0.icon_path);
    let num = null;   // mag (e.g. Shield value) takes precedence over stack_count; last in cluster wins (matches the game)
    for (const e of cluster) { if (e.display_mag) num = e.mag; else if (e.display_stacks) num = e.stack_count; }
    const inner = [];
    if (ic) inner.push(el("img", { class: "effimg", src: ic, alt: "", onerror: (ev) => (ev.target.style.visibility = "hidden") }));
    if (num != null) inner.push(el("div", { class: "eff-num" }, [String(num)]));
    // Border by CREATOR (effect.user, canonical idx): green if an ally made it, red if an
    // enemy did, from the viewing player's seat. Unknown source (-1) keeps the neutral border.
    const myBase = (S.match && S.match.canonical_role === 1) ? 3 : 0;
    const u = e0.user;
    const side = (u == null || u < 0) ? "" : ((u >= myBase && u < myBase + 3) ? " eff-ally" : " eff-enemy");
    const tip = el("span", { class: "eff " + effKind(e0) + side }, inner);   // no native title tooltip — the in-app hover panel (showEffPanel) is the label
    // Gate hover show/hide to a REAL mouse. On touch, a single tap synthesizes the whole mouse
    // chain (mouseenter then click); the mouseenter would open the panel and set _effAnchor=tip,
    // then the synthesized click's toggle would immediately close it (open-then-close = nothing
    // shows, two taps needed). Filtering to pointerType==="mouse" means touch never fires the hover
    // path, so a single tap is handled by the click toggle below (else-branch -> show). Desktop
    // mouse still hovers normally. pointerenter/pointerleave don't bubble, matching mouseenter/leave.
    // The icon is the panel's anchor in the glossary chain: while the mouse is on it (or the panel,
    // or a spawned keyword popover) the panel stays; leaving schedules the shared sweep so you can
    // slide from icon → panel → nested keyword without it vanishing. Mouse-only (touch uses click).
    tip.addEventListener("pointerenter", (ev) => { if (ev.pointerType === "mouse") { GK.hoverAdd(tip); if (_effAnchor !== tip) showEffPanel(cluster, tip); } });   // re-entry keeps the open panel + its pinned children
    tip.addEventListener("pointerleave", (ev) => { if (ev.pointerType === "mouse") { GK.hoverDel(tip); GK.scheduleSweep(); } });
    tip.addEventListener("click", (ev) => { ev.stopPropagation(); if (_effAnchor === tip) hideEffPanel(); else showEffPanel(cluster, tip); });
    return tip;
  }

  // A character strip: portrait + HP on one side, effects + ability row on the other
  // (horizontal, like the game). Stacks into a vertical team column.
  function charCard(c, canonIdx, mine, myTurn, rem, slot) {
    const pct = c.max_hp ? Math.max(0, Math.round((c.hp / c.max_hp) * 100)) : 0;
    const hue = Math.round((pct / 100) * 120); // red->green
    const oldPct = S.prevHp[canonIdx] != null ? S.prevHp[canonIdx] : pct;  // HP bar glides from last render
    S.prevHp[canonIdx] = pct;
    const isTarget = !!(S.targeting && S.targeting.special_targets.includes(canonIdx));
    const staged = mine ? S.staged.find((a) => a.char_idx === canonIdx) : null;
    const purl = portraitUrl(c);
    // Equipped cosmetics for this character: my side from S.player, enemy from the opponent display
    // package; indexed by TEAM SLOT (not canonIdx). Missing/default ids skip the layer.
    // Viewer modes: cosmetics come from the WATCHED players' display blobs by seat — otherwise a
    // spectator's own hats/panels would render on the camera-side team.
    const camP1 = S.match && S.match.canonical_role === 0;
    const cosBlob = isViewer()
      ? (((mine ? camP1 : !camP1) ? S.viewer.p1_display : S.viewer.p2_display) || {})
      : (mine ? (S.player || {}) : ((S.match && S.match.opponent) || {}));

    const portKids = [];
    if (purl) portKids.push(el("img", { class: "portrait", src: purl, alt: "", onerror: (e) => e.target.remove() }));
    const hatId = cosBlob.hats && cosBlob.hats[slot];   // 181x181 pre-positioned overlay over the portrait
    if (hatId && String(hatId).toLowerCase() !== "none")
      portKids.push(el("img", { class: "cc-hat" + (mine ? "" : " enemy"), src: cosmeticUrl("character_baubles", hatId), alt: "", onerror: (e) => e.target.remove() }));
    // Each staged skill that targets this character shows ITS skill icon on the
    // portrait, so the player can see which queued skills are aimed here.
    const stagedOn = (S.staged || []).filter((a) => (a.target_idxs || []).includes(canonIdx));
    if (stagedOn.length)
      portKids.push(el("div", { class: "tgt-icons" }, stagedOn.map((a) => {
        const caster = snapChar(a.char_idx);
        const ab = caster && caster.abilities && caster.abilities[a.ability_idx];
        const url = wireAbilityIcon(ab);
        return el("div", { class: "tgt-icon", title: a.ability_name },
          url ? [el("img", { src: url, alt: "", onerror: (e) => e.target.remove() })] : [el("span", { class: "tgt-x" }, ["◎"])]);
      })));
    const pkids = [el("div", { class: "cc-pwrap" + (stagedOn.length ? " is-targeted" : "") + (isTarget ? " valid-target" : "") }, portKids)];
    // HP sits below the portrait but OUT of the column's flow height, so the row
    // centers on the portrait (not portrait+hp) and the panel lines up with it.
    pkids.push(el("div", { class: "cc-stats" }, [
      el("div", { class: "hp" }, [el("i", { style: "width:" + oldPct + "%;background:hsl(" + hue + ",60%,45%)", "data-target-w": pct + "%" })]),
      el("div", { class: "hp-num" }, [c.hp + " / " + c.max_hp]),
    ]));

    const skids = [el("div", { class: "effects" }, effectClusters(c.effects || [], mine).slice(0, 12).map(effectTooltip))];
    // Only MY characters show skill tiles on the board (for staging). Enemy skills are
    // hidden — inspect them by clicking the portrait (→ character mode in the panel).
    if (mine) {
      if (staged) {
        const tgtNames = (staged.target_idxs || []).map((idx) => { const tc = snapChar(idx); return tc ? titleName(tc.portrait_disguise || tc.path_name) : "?"; });
        const stagedAb = (c.abilities || [])[staged.ability_idx];
        const stagedIcon = wireAbilityIcon(stagedAb);
        // Click ANYWHERE on the panel to cancel (stopPropagation so it doesn't also inspect the
        // character). Hover turns the border red + fades in a large translucent CANCEL overlay
        // (absolute, so it never resizes the panel or shoves the board).
        skids.push(el("div", { class: "staged", title: "Click to cancel", onclick: (e) => { e.stopPropagation(); unstage(canonIdx); } }, [
          stagedIcon ? el("img", { class: "stn-img", src: stagedIcon, alt: "", onerror: (e) => e.target.remove() }) : null,
          el("div", { class: "stn" }, [
            el("span", { class: "stn-name" }, ["▶ " + staged.ability_name]),
            tgtNames.length ? el("span", { class: "stn-tgt" }, [": targeting " + tgtNames.join(", ")]) : null,
          ]),
          el("div", { class: "stn-cancel" }, ["CANCEL"]),
        ]));
      } else {
        // Game/elite panel behind the ability tiles; fall back to the default panel
        // when nothing specific is equipped. Always rendered — even for dead or
        // ability-less characters (then with no bar) — so the 113px panel footprint
        // is reserved and the rows below never reflow.
        const rawPanel = cosBlob.action_frames && cosBlob.action_frames[slot];
        const panelId = (rawPanel && rawPanel !== "gamepanel_color_default") ? rawPanel : "gamepanel_color_default";
        const wrapKids = [el("img", { class: "ab-panel", src: cosmeticUrl("game_panels", panelId), alt: "", onerror: (e) => e.target.remove() })];
        if (!c.dead && (c.abilities || []).length) wrapKids.push(abilityBar(c.abilities || [], canonIdx, true, myTurn, rem));
        skids.push(el("div", { class: "ab-wrap" }, wrapKids));
      }
    }

    const describedChar = !!(S.described && S.described.char_idx === canonIdx);
    const attrs = { class: "char" + (c.dead ? " dead" : "") + (isTarget ? " target" : "") + (describedChar ? " inspecting" : ""), "data-canon": canonIdx };
    if (S.targeting) attrs.onclick = isTarget ? (() => pickTarget(canonIdx)) : (() => set({ targeting: null }));   // targeting: pick a target, or click a non-target to cancel
    else attrs.onclick = () => describeCharacter(canonIdx);                          // otherwise: inspect skills
    return el("div", attrs, [el("div", { class: "cc-portrait" }, pkids), el("div", { class: "cc-side" }, skids)]);
  }

  // Ability row. Clicking ANY tile (yours or the enemy's) shows its description in the
  // bottom-right panel; your usable tiles additionally stage/target. Enemy tiles are
  // describe-only (no cost-affordance styling).
  function abilityBar(abilities, canonChar, mine, myTurn, rem) {
    return el("div", { class: "abilities" + (mine ? "" : " enemy-ab") }, abilities.slice(0, 8).map((a, j) => {
      const offCd = a.cooldown_remaining <= 0;
      // Server ships the resolved valid-target set per ability (excludes invulnerable / isolated /
      // dead targets). A present-but-empty set means the skill has no legal target this turn — the
      // click handler already refuses it (onAbilityTap), so surface it as unusable up front too.
      // Only restrict when the field is actually present, so an absent set never greys everything out.
      const noTargets = Array.isArray(a.special_targets) && a.special_targets.length === 0;
      const ready = mine && myTurn && a.usable && offCd && canAddAbility(a) && !noTargets;
      const described = !!(S.described && S.described.char_idx === canonChar && S.described.ability_idx === j);
      const cls = "ab" + (mine ? (ready ? " tappable" : (a.usable && offCd && !noTargets ? " unaffordable" : " unusable")) : " enemy-tile") + (described ? " described" : "");
      const icon = wireAbilityIcon(a);
      const top = icon
        ? el("img", { class: "abimg", src: icon, alt: "", onerror: (e) => { const d = el("div", { class: "abn" }, [a.ability_name]); e.target.replaceWith(d); } })
        : el("div", { class: "abn" }, [a.ability_name]);
      const passive = isPassive((S.abilityInfo && S.abilityInfo[a.source_basename]) || {});
      const node = el("div", { class: cls, title: a.ability_name + (mine && noTargets && offCd && a.usable ? " — no valid targets" : "") }, [
        top,
        a.cooldown_remaining > 0
          ? el("div", { class: "cd" }, [String(a.cooldown_remaining)])
          : (passive ? null : el("div", { class: "cost" }, costPips(a.cost))),
      ]);
      node.addEventListener("click", (e) => { e.stopPropagation(); describe(canonChar, j, a); if (ready) onAbilityTap(canonChar, j, a); else if (S.targeting) set({ targeting: null }); });   // clicking a non-usable skill cancels target selection
      return node;
    }));
  }
  // Energy symbols use the game's own orb PNGs (assets/images/<color>_energy.png) rather than a
  // CSS-tinted dot. Index → enum color: 0 GREEN 1 BLUE 2 WHITE 3 RED 4 RANDOM (random_energy.png is
  // pure black, so it can never be mistaken for White the way a tinted pip was). The pool "total"
  // reuses the RANDOM orb (just labeled "Total") — total_energy.png is a distinct 'T' tile we don't want.
  function energyImgUrl(k) { return resToUrl("res://assets/images/" + String(ENERGY_NAMES[k] || "random").toLowerCase() + "_energy.png"); }
  function energyPip(k, total) {
    const url = energyImgUrl(total ? 4 : k);   // total uses the Random orb image, labeled "Total"
    return el("i", { class: "epx", title: total ? "Total" : ENERGY_NAMES[k], style: url ? "background-image:url('" + url + "')" : "" });
  }
  function costPips(cost) {
    const pips = [];
    for (let k = 0; k <= 4; k++) {
      const n = (cost && (cost[k] != null ? cost[k] : cost[String(k)])) || 0;
      for (let i = 0; i < n; i++) pips.push(energyPip(k));
    }
    return pips.length ? pips : [el("span", { class: "sub" }, ["No Cost"])];
  }
  // Passives are always-on (no cost, no cooldown) — callers hide BOTH labels for them.
  function isPassive(info) { return !!(info && info.classes && info.classes.indexOf("Passive") >= 0); }
  // The energy panel doubles as the manual RANDOM-allocation editor. The top row is
  // the remaining pool (pool - specific - assigned); when the turn has RANDOM pips it
  // adds a per-color +/- editor (auto-filled, user-adjustable) so a player can steer
  // which colors a RANDOM pip spends — e.g. to preserve a scarce color.
  function energyPanel(interactive) {
    const rem = remainingPool();
    const pips = [0, 1, 2, 3].map((k) => el("div", { class: "epip" }, [energyPip(k), String(rem[k])]));
    // Random/total pip = ALL non-allocated energy left this turn: the remaining specific pool
    // minus the random still owed (which will be drawn from it). Drops the moment you stage a
    // RANDOM-cost skill, not only once you allocate it — so it tracks "energy left to spend".
    pips.push(el("div", { class: "epip total" }, [energyPip(4, true), String(Math.max(0, (rem[0] + rem[1] + rem[2] + rem[3]) - unassignedRandom()))]));
    const rows = [el("div", { class: "energy" }, pips)];
    // 2-for-1 exchange row — ALWAYS present so the panel height is constant across turn
    // flips (an active trade is cleared each turn, so on a flip it's always the link). The
    // link is interactive only on your turn when a color has 2+ free; otherwise grayed.
    // (Picking give/get happens in a popup modal, not inline.)
    if (S.exchange) {
      const giveC = Number(Object.keys(S.exchange.offer)[0]);
      rows.push(el("div", { class: "alloc xchg" }, [
        el("div", { class: "xchg-line" }, [
          "Exchange: give 2 ", energyPip(giveC),
          " → get 1 ", energyPip(S.exchange.request),
          el("a", { href: "#", class: "xchg-clear", onclick: (ev) => { ev.preventDefault(); clearExchange(); } }, [" ✕"]),
        ]),
      ]));
    } else {
      const can = interactive && canExchange();
      rows.push(el("a", { href: "#", class: "xchg-open" + (can ? "" : " off"), title: can ? "" : "Need 2+ of one color free to exchange", onclick: (ev) => { ev.preventDefault(); if (can) startExchange(); } }, ["⇄ Exchange energy (2 → 1)"]));
    }
    return el("div", { class: "energy-panel" }, rows);
  }

  // --- execution-order reorder strip (drag to reorder) ----------------------
  // Tiles reorder by direct DOM manipulation during a drag (no re-render mid-gesture);
  // on drop we read the DOM order back into S.execOrder. The 1-based position number
  // shows resolution order (left -> right).
  // Reorder via Pointer Events so it works for BOTH mouse and touch — HTML5 drag-and-drop
  // never fires for touch on mobile. The tile is moved directly in the DOM as the pointer
  // crosses others; on release we read the DOM order back into S.execOrder. Move/up listen on
  // the document so the gesture survives the pointer leaving the tile, and `.exec-tile`'s
  // touch-action:none (CSS) stops a touch-drag from scrolling the modal instead.
  let _execDrag = null;   // { el, strip, moved }
  function execAfterEl(strip, x) {
    let best = null, bestOff = -Infinity;
    strip.querySelectorAll(".exec-tile:not(.dragging)").forEach((t) => {
      const box = t.getBoundingClientRect();
      const off = x - box.left - box.width / 2;
      if (off < 0 && off > bestOff) { bestOff = off; best = t; }
    });
    return best;
  }
  function commitExecOrder(strip) {
    const oids = Array.from(strip.querySelectorAll(".exec-tile")).map((t) => Number(t.getAttribute("data-oid")));
    S.execOrder = oids.map((oid) => S.execOrder.find((o) => o.order_id === oid)).filter(Boolean);
    set({});   // re-render to refresh the position numbers
  }
  function execPointerMove(e) {
    if (!_execDrag) return;
    e.preventDefault();
    _execDrag.moved = true;
    const dragEl = _execDrag.el, strip = _execDrag.strip;
    const after = execAfterEl(strip, e.clientX);
    if (after == null) { if (strip.lastElementChild !== dragEl) strip.appendChild(dragEl); }
    else if (after !== dragEl) strip.insertBefore(dragEl, after);
  }
  function execPointerEnd() {
    if (!_execDrag) return;
    const dragEl = _execDrag.el, strip = _execDrag.strip, moved = _execDrag.moved;
    dragEl.classList.remove("dragging");
    document.removeEventListener("pointermove", execPointerMove);
    document.removeEventListener("pointerup", execPointerEnd);
    document.removeEventListener("pointercancel", execPointerEnd);
    _execDrag = null;
    if (moved) commitExecOrder(strip);   // re-render (refresh position numbers) only if the order changed
  }
  function execTile(o, i) {
    const kids = [];
    const icon = o.ab ? wireAbilityIcon(o.ab) : o.icon;
    if (icon) kids.push(el("img", { class: "exec-ic", src: icon, alt: "", draggable: "false", onerror: (e) => e.target.remove() }));
    kids.push(el("span", { class: "exec-pos" }, [String(i + 1)]));
    return el("div", {
      class: "exec-tile k-" + o.kind, title: o.label, "data-oid": String(o.order_id),
      onpointerdown: (e) => {
        if (e.button != null && e.button > 0) return;   // primary button / touch only
        const tile = e.currentTarget, strip = tile.parentNode;
        if (!strip) return;
        e.preventDefault();
        _execDrag = { el: tile, strip: strip, moved: false };
        tile.classList.add("dragging");
        document.addEventListener("pointermove", execPointerMove);
        document.addEventListener("pointerup", execPointerEnd);
        document.addEventListener("pointercancel", execPointerEnd);
      },
    }, kids);
  }
  function execStrip() {
    return el("div", { class: "exec-strip" }, (S.execOrder || []).map((o, i) => execTile(o, i)));
  }

  // Energy exchange (2-for-1): a floating modal (like the random-allocation one) so
  // picking give/get colors never reflows the board. Opened from the energy panel's
  // "Exchange energy" link (sets S.exchangeSetup); Confirm folds the trade into the pool.
  function exchangeModal() {
    const su = S.exchangeSetup, base = remainingPool();
    const swatch = (c, sel, ok, fn) => el("button", { class: "xchg-sw e" + c + (sel ? " sel" : ""), title: ENERGY_NAMES[c], disabled: !ok, onclick: fn });
    return el("div", { class: "modal-overlay", onclick: (e) => { if (e.target.classList.contains("modal-overlay")) clearExchange(); } }, [
      el("div", { class: "modal-panel xchg-modal" }, [
        el("div", { class: "modal-head" }, [
          el("div", { class: "modal-title" }, ["Exchange Energy"]),
          el("button", { class: "modal-close", onclick: () => clearExchange() }, ["✕"]),
        ]),
        el("div", { class: "xchg-body" }, [
          el("div", { class: "alloc-label" }, ["Give 2 of one color, get 1 of another"]),
          el("div", { class: "xchg-row" }, ["Give ", el("div", { class: "xchg-colors" }, [0, 1, 2, 3].map((c) => swatch(c, su.give === c, base[c] >= 2, () => setExchangeGive(c))))]),
          el("div", { class: "xchg-row" }, ["Get ", el("div", { class: "xchg-colors" }, [0, 1, 2, 3].map((c) => swatch(c, su.get === c, true, () => setExchangeGet(c))))]),
          el("div", { class: "xchg-actions" }, [
            el("a", { href: "#", class: "rnd-cancel", onclick: (e) => { e.preventDefault(); clearExchange(); } }, ["Cancel"]),
            el("button", { class: "endturn xchg-confirm", disabled: su.give == null || su.get == null, onclick: confirmExchange }, ["Confirm"]),
          ]),
        ]),
      ]),
    ]);
  }

  // Random-energy placement: a floating modal opened from End Turn when the staged
  // turn spent RANDOM pips. Confirm (only once everything is placed) ends the turn.
  function randomAllocModal() {
    const pool = myPool(), spec = specificTotals(), a = S.randomAssign;
    const left = unassignedRandom();
    const showOrder = (S.execOrder || []).length > 1;
    const showRandom = randomTotal() > 0;
    return el("div", { class: "modal-overlay", onclick: (e) => { if (e.target.classList.contains("modal-overlay")) set({ randomModal: false }); } }, [
      el("div", { class: "modal-panel rnd-modal" }, [
        el("div", { class: "modal-head" }, [
          el("div", { class: "modal-title" }, ["End Turn"]),
          el("button", { class: "modal-close", onclick: () => set({ randomModal: false }) }, ["✕"]),
        ]),
        showOrder ? el("div", { class: "exec-order" }, [
          el("div", { class: "alloc-label" }, ["Execution order — drag to reorder (resolves left → right)"]),
          execStrip(),
        ]) : null,
        el("div", { class: "rnd-body" }, [
          showRandom ? el("div", { class: "rnd-need" + (left > 0 ? "" : " done") },
            left > 0 ? ["Allocate", el("span", { class: "rnd-need-n" }, [String(left)]), "random energy"] : ["✓ All random energy allocated"]) : null,
          showRandom ? el("div", { class: "rnd-rows" }, [0, 1, 2, 3].map((c) => {
            const avail = (pool[c] || 0) - (spec[c] || 0);
            const canMinus = (a[c] || 0) > 0;
            const canPlus = left > 0 && (a[c] || 0) < avail;
            return el("div", { class: "rnd-row" }, [
              el("span", { class: "rnd-have" }, [String(avail - (a[c] || 0))]),
              el("button", { class: "alloc-btn", disabled: !canMinus, onclick: () => adjustRandom(c, -1) }, ["–"]),
              el("i", { class: "rnd-dot e" + c }),
              el("button", { class: "alloc-btn", disabled: !canPlus, onclick: () => adjustRandom(c, 1) }, ["+"]),
              el("span", { class: "rnd-placed" }, [String(a[c] || 0)]),
            ]);
          })) : null,
          el("div", { class: "rnd-actions" }, [
            el("a", { href: "#", class: "rnd-cancel", onclick: (e) => { e.preventDefault(); set({ randomModal: false }); } }, ["Cancel"]),
            el("button", { class: "endturn rnd-confirm", disabled: left > 0 || S.acting, onclick: submitTurn }, ["Confirm & End Turn"]),
          ]),
        ]),
      ]),
    ]);
  }
  function effKind(e) {
    // crude: damage/affliction-ish names lean debuff; shields/heals lean buff. Display only.
    const n = (e.name || "").toLowerCase();
    if (/shield|heal|invuln|barrier|reduction|regen|nullify/.test(n)) return "buff";
    if (/stun|burn|bleed|poison|mark|silence|isolate|blind|vuln|drain|curse/.test(n)) return "debuff";
    return "";
  }

  // ---- chrome --------------------------------------------------------------
  function field(label, input) { return el("div", { class: "field" }, [el("label", {}, [label]), input]); }
  function statusLine() {
    return el("div", { class: "status " + (S.msgKind || "") },
      [el("span", { class: "dot " + S.conn }), S.msg || S.conn]);
  }
  function logPanel() { const box = el("div", { class: "log", id: "log" }); renderLog(box); return box; }
  function renderLog(box) {
    box.innerHTML = "";
    S.logLines.slice(-30).forEach((l) => box.appendChild(el("div", { class: "l-" + l.kind }, [(l.kind === "out" ? "→ " : l.kind === "in" ? "← " : "") + l.text])));
  }

  // ---- render --------------------------------------------------------------
  // ---- turn animations -----------------------------------------------------
  // apply_turn_result ships the post-turn snapshot + an event list. We snap to the
  // snapshot (HP bars glide via CSS from their previous width) and overlay floating
  // damage/heal numbers + cast/hit/death flashes, lightly staggered so a multi-action
  // turn reads as a sequence rather than one instant jump.
  function cardByCanon(idx) { return document.querySelector('.char[data-canon="' + idx + '"]'); }
  function spawnFloat(idx, text, cls, delay) {
    const card = cardByCanon(idx); if (!card) return;
    setTimeout(() => {
      const f = el("div", { class: "float " + cls }, [text]);
      card.appendChild(f);
      setTimeout(() => f.remove(), 1000);
    }, delay);
  }
  function flashCard(idx, cls, delay) {
    const card = cardByCanon(idx); if (!card) return;
    setTimeout(() => { card.classList.add(cls); setTimeout(() => card.classList.remove(cls), 560); }, delay);
  }
  // Play the Misaka "Ultra Railgun" clip the first time it's used in a match (by either side).
  // ABILITY_USED carries only {char_idx, ability_idx} — no name — so resolve the caster and the
  // ability in that slot from the CURRENT snapshot. This must run while S.snapshot is still the
  // PRE-turn state (before apply_turn_result overwrites it): "Ultra Railgun" is a swap-in form
  // that reverts to "Railgun" the instant it's used, so the post-turn snapshot no longer names it.
  function maybePlayRailgun(events) {
    if (S.railgunPlayed) return;
    const evt = (events || []).find((e) => {
      if (e.type !== "ABILITY_USED" || e.char_idx == null || e.ability_idx == null) return false;
      const c = snapChar(e.char_idx);
      const ab = c && c.abilities && c.abilities[e.ability_idx];
      return !!(c && c.path_name === "misaka" && ab && ab.ability_name === "Ultra Railgun");
    });
    if (!evt) return;
    S.railgunPlayed = true;
    playVfxVideo(resToUrl("res://assets/videos/misaka_ultra_railgun.mp4"), evt.char_idx);
  }
  // Mine's "High Output Blast Blade" clip — plays only on a FULLY empowered cast, i.e. both of the
  // skill's HP-threshold branches firing at once. Those thresholds are inline HP checks in
  // abilities/mine2.gd (HP <= 60 stuns non-Strategic skills, HP <= 30 adds 15 damage), not effects
  // on Mine, so "both active" == HP <= 30 (the lower bound implies the upper). Keep this constant in
  // sync with mine2.gd.
  //
  // HP source, best-first: the event's caster_hp is stamped server-side at the instant before
  // execute() runs, so it matches the value the skill's own branches read — the PRE-turn snapshot
  // can be stale (a DoT ticking earlier in the same turn may drop Mine past a threshold) and the
  // post-turn snapshot is the wrong moment entirely. caster_hp is a newer field, so fall back to
  // the snapshot HP when it's absent (older server build / older replay) rather than never firing.
  const MINE_BLADE_EMPOWERED_HP = 30;
  function castHp(evt, chr) {
    if (evt && typeof evt.caster_hp === "number") return evt.caster_hp;
    return chr && typeof chr.hp === "number" ? chr.hp : null;
  }
  function maybePlayMineBlade(events) {
    if (S.mineBladePlayed) return;
    const evt = (events || []).find((e) => {
      if (e.type !== "ABILITY_USED" || e.char_idx == null || e.ability_idx == null) return false;
      const c = snapChar(e.char_idx);
      const ab = c && c.abilities && c.abilities[e.ability_idx];
      if (!(c && c.path_name === "mine" && ab && ab.ability_name === "High Output Blast Blade")) return false;
      const hp = castHp(e, c);
      return hp != null && hp <= MINE_BLADE_EMPOWERED_HP;
    });
    if (!evt) return;
    S.mineBladePlayed = true;
    playVfxVideo(resToUrl("res://assets/videos/mine_high_output_blast_blade.mp4"), evt.char_idx);
  }
  // "Battle animations" setting (Settings menu). Absent/undefined counts as ON, matching
  // markSignificantOn's defensive default — only an explicit false disables.
  function animationsOn() { return !(S.player && S.player.animations_enabled === false); }
  // The VFX clip currently on screen, so the volume control can retune it mid-playback (these
  // clips run 10-13s, long enough that a player who grabs the slider expects it to respond).
  let _vfxVideo = null;
  // Point a VFX <video> at the client master volume/mute — the same _sfxVolume/_sfxMuted pair the
  // SFX pool uses, so one control governs all game audio.
  function applyVfxVolume(v) {
    if (!v) return;
    v.volume = Math.max(0, Math.min(1, _sfxVolume));
    v.muted = _sfxMuted || _sfxVolume <= 0.001;
  }
  // One-shot video overlay, appended to <body> so render()'s #app teardown leaves it intact. The
  // clip is anchored centered over the casting character's card (canonIdx) — a rAF loop re-reads
  // the card each frame so it tracks scroll/pinch-zoom and the card element being rebuilt by
  // render(); it falls back to screen center if that card isn't on screen. Plays at the client
  // volume, falling back to muted if the browser blocks autoplay-with-sound. Tap or clip-end
  // dismisses it. Skipped entirely when "Battle animations" is off.
  function playVfxVideo(url, canonIdx) {
    if (!url || document.querySelector(".vfx-overlay")) return;   // guard: never stack two
    if (!animationsOn()) return;        // "Battle animations" off — skip the clip entirely
    const v = document.createElement("video");
    v.className = "vfx-video";
    v.src = url;
    v.autoplay = true;
    v.playsInline = true;               // iOS: play inline, don't hijack into native fullscreen
    v.setAttribute("playsinline", "");
    applyVfxVolume(v);                  // obey the client master volume / mute like every other sound
    const overlay = el("div", { class: "vfx-overlay" }, [v]);
    let alive = true;
    const kill = () => { alive = false; _vfxVideo = null; try { v.pause(); } catch (e) {} if (overlay.parentNode) overlay.remove(); };
    _vfxVideo = v;                      // let the volume control retune this clip while it plays
    v.addEventListener("ended", kill);
    overlay.addEventListener("click", kill);   // tap to skip
    document.body.appendChild(overlay);
    // Follow the caster's card (its DOM node is recreated on every render, so re-query each frame).
    const place = () => {
      if (!alive || !overlay.parentNode) return;
      const card = canonIdx != null ? cardByCanon(canonIdx) : null;
      if (card) { const r = card.getBoundingClientRect(); v.style.left = (r.left + r.width / 2) + "px"; v.style.top = (r.top + r.height / 2) + "px"; }
      else { v.style.left = "50%"; v.style.top = "50%"; }
      requestAnimationFrame(place);
    };
    requestAnimationFrame(place);
    const pr = v.play();
    // Autoplay-with-sound refused: retry muted so the visual still plays. (A clip the player
    // deliberately muted never reaches here with sound on, so this only ever adds silence.)
    if (pr && pr.catch) pr.catch(() => { v.muted = true; v.play().catch(() => {}); });
  }
  function playEventAnimations(events) {
    let step = 0;
    for (const e of events) {
      const d = step * 80;
      // No cast flash: a white border on the acting character exposed turn order and, worse, leaked
      // invisible-skill use (a cast whose effect is hidden would still flash). step++ keeps the
      // downstream damage/heal stagger timing unchanged.
      if (e.type === "ABILITY_USED") { step++; }
      else if (e.type === "DAMAGE") { spawnFloat(e.target, "-" + e.amount, "dmg " + String(e.damage_class || "").toLowerCase(), d); flashCard(e.target, "fl-hit", d); step++; }
      else if (e.type === "HEALING") { spawnFloat(e.target, "+" + e.amount, "heal", d); step++; }
      else if (e.type === "DIED") { flashCard(e.char_idx, "fl-died", d); step++; }
    }
  }

  // Phones get the FULL wide (desktop) battle scaled to fit, not a cramped reflow: while in
  // battle we swap the viewport to a fixed design width so the mobile browser renders the
  // desktop arena and zooms it to the screen. Menus keep device-width (their responsive
  // single-column layouts), and because the battle viewport (1200) is > the 760px breakpoint,
  // the battle's mobile @media rules stop matching — it's pure desktop layout. Gate on the
  // physical screen width (independent of the meta we toggle, so never self-referential);
  // tablets/desktops are wide enough to render the battle natively and are left alone.
  const BATTLE_DESIGN_W = 1200;
  // Fallback board height (px, at the 1200px design width) used only when the live board can't be
  // measured. Normally fitBattleViewport measures the actual board so the fit contains the CURRENT
  // content — which grows tall with a staged action + an open description panel (~900px) and is short
  // at rest (~730px), so no single constant would fit both without either clipping or wasting space.
  const BATTLE_DESIGN_H = 900;
  // Zoom the fixed 1200px-wide battle design to CONTAIN the phone screen (min of the width- and
  // height-fit) so the WHOLE board is visible; the roomier axis letterboxes (the board is centered via
  // CSS body.battle-scaled). Players asked to zoom out so the full HEIGHT shows, even with side space.
  // initial-scale sets that fit as the starting zoom; minimum-scale pins it as the most zoomed-out
  // (never smaller than the full scene); maximum-scale + user-scalable let the player pinch IN.
  function battleViewportContent(screenW, screenH, boardH) {
    const raw = Math.max(0.1, Math.min(1, (screenW || 375) / BATTLE_DESIGN_W, (screenH || 700) / (boardH || BATTLE_DESIGN_H)));
    const fit = Math.floor(raw * 10000) / 10000;   // floor (not round) so the scaled board never rounds UP past the edge
    return "width=" + BATTLE_DESIGN_W + ", initial-scale=" + fit + ", minimum-scale=" + fit + ", maximum-scale=5, user-scalable=yes, viewport-fit=cover";
  }
  // Applies the phone battle zoom. battle-scaled forces the board to its natural 1200px-wide design
  // (dropping min-height:100vh and centering it) so its height can be MEASURED independent of the
  // current zoom, then the viewport is fit to contain that measured height. Call it AFTER a render so
  // the just-built board is measurable, and on rotation. Only rewrites the meta when it actually
  // changed, so it never fights a pinch-zoom within an orientation.
  // Is the viewport currently landscape? window.screen.width/height are NOT reliable for this
  // (some devices/browsers keep portrait values in landscape), so detect orientation independently:
  // screen.orientation.type first, then the orientation media query, then a raw inner-dims compare
  // (all three stay correct even under the width=1200 battle meta, whose layout viewport keeps the
  // device's aspect ratio).
  function battleIsLandscape() {
    const so = window.screen && window.screen.orientation;
    if (so && typeof so.type === "string") return so.type.indexOf("landscape") === 0;
    if (window.matchMedia) return window.matchMedia("(orientation: landscape)").matches;
    return (window.innerWidth || 0) >= (window.innerHeight || 0);
  }
  function fitBattleViewport() {
    // Take the two physical screen edges WITHOUT trusting which one screen.width claims to be
    // (it lies about orientation on some devices — the bug behind phones stretching the board to
    // full height and zooming way out). Assign width/height from the independently-detected
    // orientation so every phone computes the same contain-fit and letterboxes identically.
    const sw = (window.screen && window.screen.width) || 0;
    const sh = (window.screen && window.screen.height) || 0;
    const shortEdge = Math.min(sw, sh) || 375;   // device-natural width, orientation-independent
    const longEdge = Math.max(sw, sh) || 700;
    const landscape = battleIsLandscape();
    const effW = landscape ? longEdge : shortEdge;
    const effH = landscape ? shortEdge : longEdge;
    // Gate on the SHORT edge (orientation-independent) so a phone gets the zoom in BOTH orientations
    // and tablets/desktops (short edge > 820) still render the battle natively.
    const phone = shortEdge <= 820;
    if (document.body) document.body.classList.toggle("battle-scaled", phone && S.screen === "battle");
    if (!phone) return;
    const meta = document.querySelector('meta[name="viewport"]');
    if (!meta) return;
    let want;
    if (S.screen === "battle") {
      const board = document.querySelector(".screen.battle");
      const boardH = (board && board.offsetHeight) || BATTLE_DESIGN_H;   // 1200px-wide natural height, zoom-independent
      want = battleViewportContent(effW, effH, boardH);
    } else {
      want = "width=device-width, initial-scale=1, viewport-fit=cover";
    }
    if (meta.getAttribute("content") !== want) meta.setAttribute("content", want);
    // The phone battle zoom rewrites the LAYOUT viewport to 1200px and then scales the whole page
    // down to fit. A position:fixed banner rides that scale like everything else, so at a typical
    // 0.31 fit a 52px bar renders ~16 physical px tall with unreadable text — the opposite of
    // unmissable. Publish the inverse factor so the banner can cancel the zoom out (see
    // --maint-scale in style.css). 1 everywhere else, where it is a no-op.
    let inv = 1;
    if (S.screen === "battle") {
      const m = /initial-scale=([0-9.]+)/.exec(want);
      const fit = m ? parseFloat(m[1]) : 1;
      if (fit > 0 && fit < 1) inv = Math.min(1 / fit, 4);
    }
    document.documentElement.style.setProperty("--maint-scale", String(inv));
  }
  // Scroll preservation across render()'s full DOM teardown, applied GLOBALLY: EVERY scrolled
  // container (both axes) is captured before teardown and restored after the new tree is attached,
  // keyed by a STABLE string (data-scrollkey if set, else the class list) since each element is a
  // brand-new object every render. This is what stops horizontal strips (the ability/skill rows)
  // AND vertical lists from snapping back to the start every time a selection re-renders — no
  // per-element opt-in needed. Tab-scoped grids carry a data-scrollkey with their tab token so
  // scroll persists within a tab but resets on switch; duplicated classes (.nx-list) carry one to
  // avoid cross-restoring. `.log` is skipped — log() pins it to the bottom itself.
  function scrollKey(elm) { return elm.dataset.scrollkey || elm.className; }
  // ---- server announcements (admin -> all clients) -------------------------
  // A wide marquee scrolling one announcement at a time across the top of the screen.
  // Body-level so it survives render()'s #app teardown and shows on any screen.
  const _marqueeQueue = [];
  let _marqueeRunning = false;
  function showMarquee(text, _from) {
    const t = (text == null ? "" : String(text)).trim();
    if (!t) return;
    _marqueeQueue.push(t);
    if (_marqueeQueue.length > 20) _marqueeQueue.shift();   // cap a flood so it can't pile up unbounded
    if (!_marqueeRunning) _runNextMarquee();
  }
  function _runNextMarquee() {
    const t = _marqueeQueue.shift();
    if (t == null) { _marqueeRunning = false; return; }
    _marqueeRunning = true;
    const span = el("div", { class: "aa-marquee-text" }, ["📢  " + t]);   // string child => text node (never HTML)
    const bar = el("div", { class: "aa-marquee" }, [span]);
    document.body.appendChild(bar);
    const vw = window.innerWidth || document.documentElement.clientWidth || 800;
    const textW = span.offsetWidth || 200;
    const travel = vw + textW + 40;
    const dur = Math.max(6, travel / 150);   // ~150 px/s => constant speed regardless of length
    span.style.transform = "translateX(" + vw + "px)";
    void span.offsetWidth;                    // commit the start position before the transition
    span.style.transition = "transform " + dur + "s linear";
    span.style.transform = "translateX(" + (-textW - 40) + "px)";
    let done = false;
    const finish = () => { if (done) return; done = true; if (bar.parentNode) bar.remove(); _runNextMarquee(); };
    span.addEventListener("transitionend", finish);
    setTimeout(finish, (dur + 1.5) * 1000);   // safety net if transitionend is missed (e.g. tab hidden)
  }

  // ---- maintenance banner ----------------------------------------------------
  // Screen-wide and not dismissible. Body-level like the marquee so it survives render()'s #app
  // teardown and shows on every screen, including mid-battle. The countdown ticks on its own timer
  // rather than through set()/render() — re-rendering the whole app once a second would fight the
  // battle screen's animations.
  let _maintBar = null, _maintTick = null, _maintSlim = null;
  function renderMaintBanner() {
    if (_maintTick) { clearInterval(_maintTick); _maintTick = null; }
    if (_maintSlim) { clearTimeout(_maintSlim); _maintSlim = null; }
    if (_maintBar && _maintBar.parentNode) { _maintBar.remove(); _maintBar = null; }
    if (!S.maint || S.maint.phase === "ejected") return;   // the login screen carries the ejected state
    const back = S.maint.phase === "back";
    const label = el("span", { class: "aa-maint-msg" }, [(back ? "Update complete — reloading…" : S.maint.message)]);
    const clock = el("span", { class: "aa-maint-clock" }, [""]);
    _maintBar = el("div", { class: "aa-maint" + (back ? " aa-maint--back" : "") }, [
      el("span", { class: "aa-maint-icon" }, [back ? "✅" : "🚧"]), label, clock,
    ]);
    document.body.appendChild(_maintBar);
    // Unmissable on arrival, then out of the way: a fixed bar parked over the battle topbar (turn
    // timer, portraits) for a five-minute warning window would be a real obstruction, so shrink to a
    // slim strip after 10s. Still on screen, still counting down, no longer covering anything.
    if (!back) _maintSlim = setTimeout(() => {
      if (!_maintBar) return;
      _maintBar.classList.add("aa-maint--slim");
      // setProperty with "important". A class rule lost even at doubled specificity, and so did a
      // plain inline style — something in the page outranks both — so state the collapse at the one
      // priority nothing can outrank. Measured: 52px -> 30px.
      // No transition: animating min-height here measurably did NOT settle (the bar stayed at its
      // full 52px indefinitely), and a collapse that silently fails to collapse is worse than an
      // instant one. Snap to the strip.
      _maintBar.style.setProperty("min-height", "0", "important");
      _maintBar.style.setProperty("padding", "3px 12px", "important");
      _maintBar.style.setProperty("gap", "8px", "important");
      _maintBar.style.setProperty("border-bottom-width", "2px", "important");
    }, 10000);
    if (back || !S.maint.deadline) { clock.textContent = ""; return; }
    const paint = () => {
      const left = Math.max(0, Math.round((S.maint.deadline - Date.now()) / 1000));
      const mm = Math.floor(left / 60), ss = left % 60;
      clock.textContent = left > 0 ? (mm > 0 ? mm + "m " + String(ss).padStart(2, "0") + "s" : ss + "s") : "any moment now";
    };
    paint();
    _maintTick = setInterval(paint, 1000);
  }
  // The ejected login screen: what replaces the form while the server is being updated.
  function maintenancePanel() {
    return el("div", { class: "panel aa-maint-panel" }, [
      el("div", { class: "aa-maint-panel-icon" }, ["🚧"]),
      el("div", { class: "aa-maint-panel-title" }, ["Update in progress"]),
      el("div", { class: "aa-maint-panel-msg" }, [S.maint.message]),
      el("div", { class: "aa-maint-panel-note" }, [
        "You've been signed out while the server restarts. Logging in is disabled until it's back — " +
        "this page will reload itself automatically the moment the new version is live.",
      ]),
      el("div", { class: "aa-maint-panel-status" }, [
        el("span", { class: "aa-maint-dot" }, []),
        S.conn === "connected" ? "Connected — waiting for the new version…" : "Waiting for the server to come back…",
      ]),
      el("div", { class: "login-actions" }, [
        // Same cache-busted URL the automatic path uses — a plain reload() can be served the CACHED
        // index.html, which is the one thing this whole flow exists to avoid.
        el("button", { class: "secondary", onclick: () => bustedReload() }, ["Reload now"]),
      ]),
    ]);
  }

  // ---- toast stack -----------------------------------------------------------
  // Like the marquee, the toast container lives on document.body so it survives render()'s #app
  // teardown and shows on any screen. Unlike the one-at-a-time marquee, toasts STACK (multiple
  // visible at once). kind ∈ {"ok","err","info"} (default "info"); each auto-dismisses after ~4s
  // and can be dismissed early by clicking it. text is set via textContent (never innerHTML).
  let _toastBox = null;
  function showToast(text, kind) {
    const t = (text == null ? "" : String(text)).trim();
    if (!t) return;
    if (!_toastBox || !_toastBox.parentNode) {
      _toastBox = el("div", { class: "aa-toasts" });
      document.body.appendChild(_toastBox);
    }
    const variant = (kind === "ok" || kind === "err" || kind === "info") ? kind : "info";
    const toast = el("div", { class: "aa-toast aa-toast--" + variant }, [t]);   // string child => text node
    let gone = false;
    const dismiss = () => { if (gone) return; gone = true; if (toast.parentNode) toast.remove(); };
    toast.addEventListener("click", dismiss);
    _toastBox.appendChild(toast);
    while (_toastBox.children.length > 5) _toastBox.removeChild(_toastBox.firstChild);   // drop oldest beyond a cap
    setTimeout(dismiss, 4000);
  }
  // Reusable unread-count chip; null when there's nothing to show so callers can drop it inline.
  function badgeChip(n) {
    return n > 0 ? el("span", { class: "aa-badge" }, [String(n)]) : null;
  }

  // ---- admin panel: announcements + player admin (visible only to server admins) ----
  // Body-level so it survives render()'s #app teardown and is reachable on any screen.
  let _adminFab = null, _adminPanel = null, _adminTab = "players";
  let _adminCharView = "";   // Character View tab: selected character path_name (full-toolkit viewer)
  let _adminBots = [];   // Ultra Bots status cache (admin "Bots" tab)
  let _adminBotsRotation = true;   // auto daily-rotation scheduler on/off (from ultra_bot_status)
  let _adminBotsDeployed = false;  // master DEPLOY switch — bots are dormant until deployed (from ultra_bot_status)
  let _adminStats = null, _adminStatsMode = "pvp", _adminStatsSort = "picks", _adminStatsQuery = "";
  // Date window for Char Usage, in unix SECONDS (0/0 = all time). The whole point is being able
  // to ask "how did this character do since I patched them" — the all-time aggregate can never
  // answer that, because a period cannot be subtracted back out of a running total.
  let _adminStatsFrom = 0, _adminStatsTo = 0, _adminStatsPreset = "all";
  let _adminStatsSpan = [0, 0];   // true extent of the recorded data, reported by the server
  let _adminNexusPreview = null;   // set by buildAdminNexusTab; nexus_state / round-closed handlers repaint via it
  function closeAdminPanel() { if (_adminPanel) { _adminPanel.remove(); _adminPanel = null; } }
  function refreshAdminPlayers() { if (S.isAdmin) S.net.send("admin_list_players", {}); }
  // ---- Ultra Bots (admin smoke-test): bring a persistent bot online + into the ranked queue ----
  function refreshAdminBots() { if (S.isAdmin) S.net.send("admin_ultra_bot", { action: "status" }); }
  function renderAdminBots() {
    if (!_adminPanel) return;
    const box = _adminPanel.querySelector(".admin-bots-list");
    if (!box) return;
    box.innerHTML = "";
    const depBtn = _adminPanel.querySelector(".admin-bots-deploy");
    if (depBtn) { depBtn.textContent = _adminBotsDeployed ? "◉ Deployed — Stand down" : "◯ Deploy fleet"; depBtn.classList.toggle("admin-danger", _adminBotsDeployed); }
    const rotBtn = _adminPanel.querySelector(".admin-bots-rot");
    if (rotBtn) rotBtn.textContent = "Auto-rotation: " + (_adminBotsRotation ? "ON" : "OFF");
    if (!_adminBotsDeployed) { box.appendChild(el("div", { class: "admin-muted" }, ["Fleet stood down — the Ultra Bots are dormant (not online, not queued, not playing). Press Deploy to launch them."])); return; }
    if (!_adminBots.length) { box.appendChild(el("div", { class: "admin-muted" }, ["Deployed, but no Ultra Bot accounts are seeded (add them to ultra_bots.json + restart)."])); return; }
    _adminBots.forEach((b) => {
      const state = (b.in_match ? "in match" : (b.queued ? "queued" : (b.online ? "online" : "offline"))) + (b.pinned ? " 📌" : "");
      box.appendChild(el("div", { class: "admin-bot-row" }, [
        el("div", { class: "admin-bot-name" }, [b.username, el("span", { class: "admin-bot-rating" }, [" " + b.rating])]),
        el("div", { class: "admin-bot-state admin-bot-" + (b.online ? "on" : "off") }, [state]),
        el("button", { class: "admin-btn admin-sm", onclick: () => S.net.send("admin_ultra_bot", { action: "queue", username: b.username }) }, ["Online + Queue"]),
        el("button", { class: "admin-btn admin-sm", onclick: () => S.net.send("admin_ultra_bot", { action: "offline", username: b.username }) }, ["Offline"]),
      ]));
    });
  }
  function buildAdminBotsTab() {
    return el("div", { class: "admin-bots" }, [
      el("div", { class: "admin-note" }, ["Ultra Bots are persistent, player-like bots (disguised from players). They stay dormant until you Deploy the fleet — deploying seeds the accounts and starts the daily rotation, and the choice persists across restarts. Stand down to take them all offline. While deployed, bring one Online + Queue and queue Ranked yourself to smoke-test."]),
      el("div", { class: "admin-bots-actions" }, [
        el("button", { class: "admin-btn admin-bots-deploy" + (_adminBotsDeployed ? " admin-danger" : ""), onclick: () => S.net.send("admin_ultra_bot", { action: "deploy", on: !_adminBotsDeployed }) }, [_adminBotsDeployed ? "◉ Deployed — Stand down" : "◯ Deploy fleet"]),
        el("button", { class: "admin-btn", onclick: refreshAdminBots }, ["Refresh"]),
        el("button", { class: "admin-btn admin-bots-rot", onclick: () => S.net.send("admin_ultra_bot", { action: "rotation", on: !_adminBotsRotation }) }, ["Auto-rotation: " + (_adminBotsRotation ? "ON" : "OFF")]),
      ]),
      el("div", { class: "admin-bots-list" }, []),
    ]);
  }
  // ---- The "Characters" tab: full-toolkit viewer. Pick a character to pop their WHOLE kit into a large
  // centered overlay — every skill's description panel at once (reusing the in-battle abilityDescPanel +
  // glossary highlighting), scrollable for the biggest kits. Read-only; reflects the live ability_info.json.
  function buildAdminCharactersTab() {
    loadRoster(); loadAbilityInfo();   // ensure the data is (being) fetched
    const wrap = el("div", { class: "admin-charview" }, [
      el("div", { class: "admin-note" }, ["Full toolkit viewer — pick a character to open their whole kit in a large centered panel."]),
    ]);
    if (!S.roster || !S.abilityInfo) {
      wrap.appendChild(el("div", { class: "admin-muted" }, ["Loading character + ability data…"]));
      setTimeout(() => { if (_adminTab === "characters") renderAdminTab(); }, 500);   // re-render once the fetch lands
      return wrap;
    }
    const roster = (S.roster || []).slice().sort((a, b) => (a.name || a.path_name).localeCompare(b.name || b.path_name));
    const sel = el("select", { class: "admin-charview-pick" },
      [el("option", { value: "" }, ["— pick a character —"])].concat(roster.map((c) => {
        const o = el("option", { value: c.path_name }, [(c.name || c.path_name) + (c.universe ? "  ·  " + c.universe : "")]);
        if (c.path_name === _adminCharView) o.selected = true;
        return o;
      })));
    sel.addEventListener("change", () => { if (sel.value) openCharView(sel.value); });
    wrap.appendChild(el("div", { class: "admin-charview-bar" }, [
      sel,
      el("button", { class: "admin-btn admin-sm", onclick: () => { if (sel.value) openCharView(sel.value); } }, ["Open ▸"]),
    ]));
    return wrap;
  }
  // The full kit as a large CENTERED overlay above the admin panel. Standalone body-level DOM (like the
  // admin panel itself), so the main render loop can't tear it down; dismiss via ✕, backdrop click, or Esc.
  let _charViewEl = null;
  function _charViewEsc(e) { if (e.key === "Escape") closeCharView(); }
  function openCharView(pn) {
    _adminCharView = pn;
    if (!_charViewEl) {
      _charViewEl = el("div", { class: "modal-overlay charview-overlay", onclick: (e) => { if (e.target === e.currentTarget) closeCharView(); } }, []);
      document.body.appendChild(_charViewEl);
      document.addEventListener("keydown", _charViewEsc);
    }
    renderCharView();
  }
  function closeCharView() {
    if (_charViewEl) { _charViewEl.remove(); _charViewEl = null; document.removeEventListener("keydown", _charViewEsc); }
  }
  function renderCharView() {
    if (!_charViewEl) return;
    _charViewEl.innerHTML = "";
    if (!S.roster || !S.abilityInfo) {
      _charViewEl.appendChild(el("div", { class: "charview-modal" }, [el("div", { class: "admin-muted charview-msg" }, ["Loading character + ability data…"])]));
      loadRoster(); loadAbilityInfo();
      setTimeout(() => { if (_charViewEl) renderCharView(); }, 400);
      return;
    }
    const pn = _adminCharView;
    const c = (S.roster || []).find((x) => x.path_name === pn);
    const bases = charAbilities(pn);
    const roster = (S.roster || []).slice().sort((a, b) => (a.name || a.path_name).localeCompare(b.name || b.path_name));
    const sel = el("select", { class: "admin-charview-pick charview-modal-pick" }, roster.map((r) => {
      const o = el("option", { value: r.path_name }, [(r.name || r.path_name) + (r.universe ? "  ·  " + r.universe : "")]);
      if (r.path_name === pn) o.selected = true;
      return o;
    }));
    sel.addEventListener("change", () => openCharView(sel.value));
    const head = el("div", { class: "charview-modal-head" }, [
      el("img", { class: "admin-charview-portrait", src: portraitUrlFor(pn), alt: "", onerror: (e) => e.target.remove() }),
      el("div", { class: "admin-charview-id" }, [
        el("div", { class: "admin-charview-name" }, [c ? (c.name || pn) : pn]),
        el("div", { class: "admin-charview-uni" }, [(c && c.universe ? c.universe : "—") + "  ·  " + bases.length + " skill" + (bases.length === 1 ? "" : "s")]),
      ]),
      el("div", { class: "charview-modal-tools" }, [sel, el("button", { class: "admin-x charview-x", onclick: closeCharView, title: "Close (Esc)" }, ["✕"])]),
    ]);
    let body;
    if (!bases.length) body = el("div", { class: "admin-muted charview-msg" }, ["No abilities found for " + pn + " (is ability_info.json loaded?)."]);
    else body = el("div", { class: "admin-charview-panels charview-modal-panels" }, bases.map((bn) => {
      const info = S.abilityInfo[bn] || {};
      const a = { source_basename: bn, ability_name: info.name || bn, cost: info.cost || {} };
      return abilityDescPanel(a, null);   // charIdx=null -> standalone panel, no live-battle nav strip
    }));
    _charViewEl.appendChild(el("div", { class: "charview-modal" }, [head, body]));
  }
  function refreshAdminStats() {
    if (S.isAdmin) S.net.send("admin_character_stats", { from_ts: _adminStatsFrom, to_ts: _adminStatsTo });
  }
  let _seasonResetArm = false;   // two-tap guard for the admin Season Reset (wipes EVERY player's record)
  let _maintEjectArm = false;    // two-tap guard for Eject All to Login
  function renderAdminPlayers(players, total) {
    if (!_adminPanel) return;
    const box = _adminPanel.querySelector(".admin-players");
    if (!box) return;
    box.innerHTML = "";
    if (!players.length) {
      box.appendChild(el("div", { class: "admin-empty" }, ["No players online"]));
    } else {
      players.forEach((p) => box.appendChild(el("div", {
        class: "admin-prow", title: "Click to target " + p.username,
        onclick: () => { const t = _adminPanel && _adminPanel.querySelector(".admin-target"); if (t) t.value = p.username; },
      }, [
        el("span", { class: "admin-pname" }, [p.username]),
        el("span", { class: "admin-pstat st-" + String(p.status || "online").replace(/\s+/g, "-") }, [p.status || ""]),
        el("span", { class: "admin-pmeta" }, ["AP " + p.ap + " · " + p.wins + "W/" + p.losses + "L · " + p.rating + "r"]),
      ])));
    }
    if (total != null) box.appendChild(el("div", { class: "admin-total" }, [total + " total accounts"]));
  }
  // The "Players" tab: announcements + player-admin controls + online list.
  function buildAdminPlayersTab() {
    const annTa = el("textarea", { class: "admin-input", placeholder: "Server announcement…", maxlength: "500", rows: "2" });
    const sendAnn = () => {
      const text = annTa.value.trim();
      if (!text) { annTa.focus(); return; }
      S.net.send("admin_announce", { text });   // server re-checks admin authority before broadcasting
      annTa.value = "";
      set({ msg: "Announcement broadcast", msgKind: "ok" });
    };
    annTa.addEventListener("keydown", (e) => { if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) { e.preventDefault(); sendAnn(); } });
    const targetIn = el("input", { class: "admin-input admin-target", placeholder: "Target username", autocapitalize: "off", autocorrect: "off", spellcheck: "false" });
    const apIn = el("input", { class: "admin-input admin-sm", type: "number", value: "1000", title: "AP amount (negative deducts)" });
    const unlockIn = el("input", { class: "admin-input admin-sm", placeholder: "unlock, e.g. adam", autocapitalize: "off", spellcheck: "false" });
    const maintMsgIn = el("input", { class: "admin-input", maxlength: "200", value: "Anime Arena is going down for an update.", placeholder: "Update message shown to everyone" });
    const maintMinIn = el("input", { class: "admin-input admin-sm", type: "number", value: "5", min: "0", title: "Minutes until the update" });
    // Two-tap guards. This panel is mounted on document.body by openAdminPanel and is NOT rebuilt by
    // set(), so an armed label has to be written onto the element itself — a label derived from the
    // flag at build time would never update. Both auto-disarm so a forgotten arm cannot linger.
    //
    // Reset the flags HERE, as the buttons are built: they are module-scoped and outlive the panel,
    // so a flag still armed from a previous build would pair with a brand-new button whose label
    // reads idle — and the very next click would fire the destructive action with no confirmation.
    _maintEjectArm = false;
    _seasonResetArm = false;
    const arm = (btn, flagGet, flagSet, armedLabel, idleLabel, warning, fire) => {
      let timer = null;
      const disarm = () => { flagSet(false); btn.textContent = idleLabel; clearTimeout(timer); };
      btn.addEventListener("click", () => {
        if (flagGet()) { disarm(); fire(); return; }
        flagSet(true); btn.textContent = armedLabel;
        set({ msg: warning, msgKind: "err" });
        clearTimeout(timer); timer = setTimeout(disarm, 8000);
      });
      return btn;
    };
    const ejectBtn = arm(el("button", { class: "admin-btn admin-btn-danger" }, ["Eject All to Login"]),
      () => _maintEjectArm, (v) => { _maintEjectArm = v; }, "Confirm Eject?", "Eject All to Login",
      "Tap again to eject EVERYONE to the login screen",
      () => S.net.send("admin_maintenance", { action: "eject", message: maintMsgIn.value.trim() }));
    const cancelBtn = el("button", { class: "admin-btn", onclick: () => {
      _maintEjectArm = false; ejectBtn.textContent = "Eject All to Login";
      S.net.send("admin_maintenance", { action: "cancel" });
    } }, ["Cancel Update"]);
    const previewBtn = el("button", { class: "admin-btn", onclick: () => {
      _seasonResetArm = false; wipeBtn.textContent = "Reset Season";
      S.net.send("admin_season_reset", { dry_run: true });
    } }, ["Preview Season Reset"]);
    const wipeBtn = arm(el("button", { class: "admin-btn admin-btn-danger" }, ["Reset Season"]),
      () => _seasonResetArm, (v) => { _seasonResetArm = v; }, "Confirm Wipe?", "Reset Season",
      "Tap again to WIPE every player's W/L and rating",
      () => S.net.send("admin_season_reset", { dry_run: false, confirm: "RESET SEASON" }));
    const modify = (op, value) => {
      const target = targetIn.value.trim();
      if (!target) { targetIn.focus(); return set({ msg: "Enter a target username", msgKind: "err" }); }
      S.net.send("admin_modify_player", { target, op, value });   // server re-checks authority + validates
    };
    return el("div", { class: "admin-tabbody" }, [
      el("div", { class: "admin-sec" }, ["📢 Announcement"]),
      annTa,
      el("div", { class: "admin-row" }, [el("button", { class: "admin-btn admin-btn-primary admin-btn-block", onclick: sendAnn }, ["Broadcast"])]),
      el("div", { class: "admin-sec" }, ["🛠️ Player Admin"]),
      targetIn,
      el("div", { class: "admin-row" }, [apIn, el("button", { class: "admin-btn", onclick: () => modify("grant_ap", Math.trunc(Number(apIn.value) || 0)) }, ["Grant AP"])]),
      el("div", { class: "admin-row" }, [unlockIn,
        el("button", { class: "admin-btn", onclick: () => modify("add_unlock", unlockIn.value.trim()) }, ["Unlock"]),
        el("button", { class: "admin-btn", onclick: () => modify("remove_unlock", unlockIn.value.trim()) }, ["Remove"])]),
      el("div", { class: "admin-row" }, [el("button", { class: "admin-btn admin-btn-danger admin-btn-block", onclick: () => modify("reset_record", 0) }, ["Reset W/L Record"])]),
      // Season rollover: zeroes W/L + rating for EVERY account. Preview is the default and the only
      // thing a single click can do — applying needs a second, separately-armed click, and the
      // server independently demands the confirm phrase and takes its own backup first.
      // Update helper. Three steps, in order: warn everyone -> eject everyone to a locked login
      // screen -> stop the server and start the new build. Cancel backs out of either step.
      el("div", { class: "admin-sec" }, ["🚧 Update / Maintenance"]),
      maintMsgIn,
      el("div", { class: "admin-row" }, [maintMinIn,
        el("button", { class: "admin-btn", onclick: () => {
          _maintEjectArm = false; ejectBtn.textContent = "Eject All to Login";
          S.net.send("admin_maintenance", { action: "warn", message: maintMsgIn.value.trim(), seconds: Math.max(0, Math.trunc(Number(maintMinIn.value) || 0)) * 60 });
        } }, ["Announce Update"])]),
      el("div", { class: "admin-row" }, [ejectBtn, cancelBtn]),
      el("div", { class: "admin-hint" }, ["Announce → wait → Eject → stop & relaunch the server. Ejected clients reload themselves once the new build answers."]),
      el("div", { class: "admin-sec" }, ["🏆 Ranked Season"]),
      el("div", { class: "admin-row" }, [previewBtn, wipeBtn]),
      el("div", { class: "admin-row" }, [   // chat moderation (rides the same admin_modify_player op channel as the rest)
        el("button", { class: "admin-btn", onclick: () => modify("mute") }, ["Mute"]),
        el("button", { class: "admin-btn", onclick: () => modify("unmute") }, ["Unmute"]),
      ]),
      el("div", { class: "admin-sec" }, ["💬 Global Chat"]),   // D7 kill switch — server echoes global_chat_state to all clients
      el("div", { class: "admin-row" }, [
        el("button", { class: "admin-btn", onclick: () => S.net.send("admin_toggle_global_chat", { enabled: true }) }, ["Enable Global Chat"]),
        el("button", { class: "admin-btn admin-btn-danger", onclick: () => S.net.send("admin_toggle_global_chat", { enabled: false }) }, ["Disable Global Chat"]),
      ]),
      el("div", { class: "admin-sec admin-sec-row" }, [el("span", {}, ["Online Players"]), el("button", { class: "admin-btn admin-btn-sm", onclick: refreshAdminPlayers }, ["Refresh"])]),
      el("div", { class: "admin-players" }, []),
    ]);
  }

  // Reduce a server stats row to the counters for the currently-selected mode.
  function statBucket(r, mode) {
    const pvp = (r && r.pvp) || { picks: 0, wins: 0, losses: 0 };
    const bot = (r && r.bot) || { picks: 0, wins: 0, losses: 0 };
    if (mode === "bot") return bot;
    if (mode === "all") return { picks: (pvp.picks || 0) + (bot.picks || 0), wins: (pvp.wins || 0) + (bot.wins || 0), losses: (pvp.losses || 0) + (bot.losses || 0) };
    return pvp;
  }
  function statRow(path, r) {
    const b = statBucket(r, _adminStatsMode);
    const games = (b.wins || 0) + (b.losses || 0);
    // nameFor (not charName) so characters removed from the roster but still in the
    // stats history (e.g. Kakashi/Uryuu) resolve to their real char_index name.
    return { path, name: nameFor(path), picks: b.picks || 0, wins: b.wins || 0, losses: b.losses || 0, games, winrate: games ? (b.wins || 0) / games : 0 };
  }
  // Rebuild only the .admin-stats-table body (leaves the controls — and search
  // focus — intact) from the cached _adminStats for the current mode/sort/filter.
  function renderAdminStatsTable() {
    if (!_adminPanel) return;
    const wrap = _adminPanel.querySelector(".admin-stats-table");
    if (!wrap) return;
    const foot = _adminPanel.querySelector(".admin-stats-foot");
    const byPath = {};
    (_adminStats || []).forEach((r) => { if (r && r.path) byPath[r.path] = r; });
    // Every playable character shows (0-usage ones included, at the bottom), plus
    // any server path not in the roster (defensive).
    const seen = {};
    let rows = (S.roster || []).map((c) => { seen[c.path_name] = 1; return statRow(c.path_name, byPath[c.path_name]); });
    (_adminStats || []).forEach((r) => { if (r && r.path && !seen[r.path]) rows.push(statRow(r.path, r)); });
    const q = (_adminStatsQuery || "").toLowerCase();
    if (q) rows = rows.filter((r) => (r.name + " " + r.path).toLowerCase().includes(q));
    rows.sort((a, b) => _adminStatsSort === "winrate"
      ? (b.winrate - a.winrate) || (b.picks - a.picks)
      : (b.picks - a.picks) || (b.winrate - a.winrate));
    wrap.innerHTML = "";
    wrap.appendChild(el("div", { class: "admin-st-row admin-st-head" }, [
      el("span", { class: "admin-st-rank" }, ["#"]),
      el("span", { class: "admin-st-name" }, ["Character"]),
      el("span", { class: "admin-st-num" }, ["Picks"]),
      el("span", { class: "admin-st-num" }, ["W-L"]),
      el("span", { class: "admin-st-num" }, ["Win%"]),
    ]));
    rows.forEach((r, i) => {
      const purl = portraitUrlFor(r.path);
      const wr = r.games ? Math.round(r.winrate * 100) + "%" : "—";
      wrap.appendChild(el("div", { class: "admin-st-row" + (r.picks === 0 ? " admin-st-zero" : "") }, [
        el("span", { class: "admin-st-rank" }, [String(i + 1)]),
        el("span", { class: "admin-st-name" }, [
          purl ? el("img", { class: "admin-st-pic", src: purl, loading: "lazy" }) : el("span", { class: "admin-st-pic admin-st-pic-none" }, []),
          el("span", { class: "admin-st-cn" }, [r.name]),
        ]),
        el("span", { class: "admin-st-num" }, [String(r.picks)]),
        el("span", { class: "admin-st-num" }, [r.wins + "-" + r.losses]),
        el("span", { class: "admin-st-num admin-st-wr" }, [wr]),
      ]));
    });
    if (foot) {
      // Always state the window. Without it a filtered table is indistinguishable from an
      // all-time one, which is exactly how a patch gets judged against the wrong baseline.
      let win = "all time";
      const fmt = (t) => new Date(t * 1000).toISOString().slice(0, 10);
      if (_adminStatsFrom && _adminStatsTo) win = fmt(_adminStatsFrom) + " to " + fmt(_adminStatsTo);
      else if (_adminStatsFrom) win = "since " + fmt(_adminStatsFrom);
      else if (_adminStatsTo) win = "up to " + fmt(_adminStatsTo);
      foot.textContent = _adminStats == null ? "Loading…"
        : (rows.filter((r) => r.picks > 0).length + " played · " + rows.length + " shown · " + win);
    }
  }
  // The "Char Usage" tab: mode (PvP/Bot/All) + sort + name filter over the table.
  function buildAdminUsageTab() {
    const modeBtns = [["pvp", "PvP"], ["bot", "Bot"], ["all", "All"]].map(([k, label]) =>
      el("button", { class: "admin-mtab", "data-k": k, onclick: () => { _adminStatsMode = k; modeBtns.forEach((b) => b.classList.toggle("sel", b.dataset.k === k)); renderAdminStatsTable(); } }, [label]));
    const sortBtns = [["picks", "Picks"], ["winrate", "Win%"]].map(([k, label]) =>
      el("button", { class: "admin-mtab", "data-k": k, onclick: () => { _adminStatsSort = k; sortBtns.forEach((b) => b.classList.toggle("sel", b.dataset.k === k)); renderAdminStatsTable(); } }, [label]));
    modeBtns.forEach((b) => b.classList.toggle("sel", b.dataset.k === _adminStatsMode));
    sortBtns.forEach((b) => b.classList.toggle("sel", b.dataset.k === _adminStatsSort));
    const search = el("input", { class: "admin-input admin-stats-search", placeholder: "Filter by name…", value: _adminStatsQuery, autocapitalize: "off", spellcheck: "false",
      oninput: (e) => { _adminStatsQuery = e.target.value; renderAdminStatsTable(); } });
    // --- date window -------------------------------------------------------
    // Presets cover the common "since the patch" question; Custom is there for pinning an
    // exact patch date. Changing the window re-queries the SERVER (unlike mode/sort/filter,
    // which are pure client-side views of the cached rows) because the windowed numbers come
    // from a different table.
    const DAY = 86400;
    const nowS = () => Math.floor(Date.now() / 1000);
    const dateIn = (v) => el("input", { class: "admin-input admin-sm", type: "date", value: v || "" });
    const fromIn = dateIn(_adminStatsFrom ? new Date(_adminStatsFrom * 1000).toISOString().slice(0, 10) : "");
    const toIn = dateIn(_adminStatsTo ? new Date(_adminStatsTo * 1000).toISOString().slice(0, 10) : "");
    const customRow = el("div", { class: "admin-mrow admin-stats-custom" }, [
      el("span", { class: "admin-mlabel" }, ["From"]), fromIn,
      el("span", { class: "admin-mlabel" }, ["To"]), toIn,
      el("button", { class: "admin-btn admin-btn-sm", onclick: () => {
        // Parse as UTC midnight and push `to` to the END of its day, so a single-day range
        // actually contains that day instead of being an empty instant.
        _adminStatsFrom = fromIn.value ? Math.floor(Date.parse(fromIn.value + "T00:00:00Z") / 1000) : 0;
        _adminStatsTo = toIn.value ? Math.floor(Date.parse(toIn.value + "T23:59:59Z") / 1000) : 0;
        _adminStatsPreset = "custom";
        refreshAdminStats();
      } }, ["Apply"]),
    ]);
    const rangeBtns = [["all", "All time"], ["7", "Last 7d"], ["30", "Last 30d"], ["custom", "Custom"]].map(([k, label]) =>
      el("button", { class: "admin-mtab", "data-k": k, onclick: () => {
        _adminStatsPreset = k;
        if (k === "all") { _adminStatsFrom = 0; _adminStatsTo = 0; }
        else if (k !== "custom") { _adminStatsFrom = nowS() - Number(k) * DAY; _adminStatsTo = 0; }
        rangeBtns.forEach((b) => b.classList.toggle("sel", b.dataset.k === k));
        customRow.style.display = k === "custom" ? "" : "none";
        if (k !== "custom") refreshAdminStats();   // Custom waits for Apply
      } }, [label]));
    rangeBtns.forEach((b) => b.classList.toggle("sel", b.dataset.k === _adminStatsPreset));
    customRow.style.display = _adminStatsPreset === "custom" ? "" : "none";

    return el("div", { class: "admin-tabbody" }, [
      el("div", { class: "admin-sec admin-sec-row" }, [el("span", {}, ["Character Usage"]), el("button", { class: "admin-btn admin-btn-sm", onclick: refreshAdminStats }, ["Refresh"])]),
      el("div", { class: "admin-mrow" }, [el("span", { class: "admin-mlabel" }, ["Range"]), ...rangeBtns]),
      customRow,
      el("div", { class: "admin-mrow" }, [el("span", { class: "admin-mlabel" }, ["Mode"]), ...modeBtns]),
      el("div", { class: "admin-mrow" }, [el("span", { class: "admin-mlabel" }, ["Sort"]), ...sortBtns]),
      search,
      el("div", { class: "admin-stats-table" }, []),
      el("div", { class: "admin-stats-foot admin-total" }, []),
    ]);
  }

  // ---- The "Metrics" tab: site usage — who visits, how often, how long, and what they play. ----
  // Server-assembled (admin_site_metrics) so every number on screen shares one window and one
  // instant; this side only draws. Charts are small multiples rather than one overlaid plot:
  // players, matches, sign-ups and peak-concurrency are different measures with different
  // magnitudes, and stacking them on a shared y-axis (or worse, two y-axes) makes the small
  // series unreadable and invites false "they move together" readings.
  //
  // Hue is per MEASURE and fixed — the same colour means "players" in every chart on the tab.
  // Palette is validated for the dark surfaces of both themes (contrast, chroma, colour-vision
  // separation); identity never rests on colour alone, since each series sits in its own titled
  // chart and every chart has a table view behind the "Table" toggle.
  const MX_COLORS = { players: "#5b7cf0", matches: "#2fa85a", signups: "#cc5d94", peak: "#c2861d" };
  const MX_MODES = [["quick", "Quick"], ["ranked", "Ladder"], ["bot", "Bot"], ["campaign", "Campaign"], ["private", "Private"]];
  let _adminMetrics = null, _adminMetricsDays = 30, _adminMetricsTable = false;

  function refreshAdminMetrics() {
    if (S.isAdmin) S.net.send("admin_site_metrics", { days: _adminMetricsDays });
  }
  function mxNum(n) {   // compact counts so a 4-digit total can't blow out a tile
    n = Number(n) || 0;
    if (n >= 1000000) return (n / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
    if (n >= 10000) return Math.round(n / 1000) + "k";
    return String(n);
  }
  function mxDur(secs) {   // seconds -> "4m" / "1h 12m"; session lengths span both scales
    secs = Math.max(0, Math.round(Number(secs) || 0));
    if (secs < 60) return secs + "s";
    const m = Math.floor(secs / 60);
    if (m < 60) return m + "m";
    return Math.floor(m / 60) + "h " + (m % 60) + "m";
  }
  function mxDay(ts) { return new Date(ts * 1000).toISOString().slice(5, 10); }        // MM-DD
  function mxDate(ts) { return new Date(ts * 1000).toISOString().slice(0, 10); }       // YYYY-MM-DD
  function mxPct(part, whole) { return whole > 0 ? Math.round((part / whole) * 100) + "%" : "—"; }

  // A hero number with its label. The dashboard's top row answers "how are we doing" before any
  // chart is read, which is the only thing most visits to this tab actually need.
  function mxTile(label, value, sub, color) {
    return el("div", { class: "mx-tile" }, [
      el("div", { class: "mx-tile-v", style: color ? "color:" + color : null }, [String(value)]),
      el("div", { class: "mx-tile-l" }, [label]),
      sub ? el("div", { class: "mx-tile-s" }, [sub]) : null,
    ]);
  }

  // One small-multiple bar chart over the day series.
  //
  // Drawn as inline SVG (no chart library on the wire) with a viewBox + preserveAspectRatio="none"
  // so it scales to whatever width the panel has. Bars carry a 2px surface gap and a rounded data
  // end; the value axis shows only the max, since the exact height of every bar is what the table
  // view is for. A transparent full-height hit column per bar drives the tooltip — hovering a 2px
  // bar on a quiet day would otherwise be impossible.
  function mxChart(title, rows, key, color, opts) {
    opts = opts || {};
    const W = 300, H = 64, GAP = 2;
    const vals = rows.map((r) => Number(r[key]) || 0);
    const max = Math.max(1, ...vals);
    const n = Math.max(1, rows.length);
    const bw = W / n;
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 " + W + " " + H);
    svg.setAttribute("preserveAspectRatio", "none");
    svg.setAttribute("class", "mx-svg");
    const mk = (tag, attrs) => {
      const e = document.createElementNS("http://www.w3.org/2000/svg", tag);
      for (const k in attrs) if (attrs[k] != null) e.setAttribute(k, attrs[k]);
      return e;
    };
    // The label lives in a child span so its background hugs the text; a background on the
    // full-width tip itself would draw a bar across the plot.
    const tip = el("div", { class: "mx-tip" }, [el("span", {}, [])]);
    const tipText = tip.firstChild;
    vals.forEach((v, i) => {
      const x = i * bw;
      const h = Math.max(v > 0 ? 2 : 0, Math.round((v / max) * (H - 2)));
      if (h > 0) {
        // Rounded data end only (top), square at the baseline — a bar is anchored to zero and
        // rounding that end would visually lift it off the axis.
        const w = Math.max(1, bw - GAP);
        const r = Math.min(2, w / 2, h);
        const y = H - h;
        svg.appendChild(mk("path", {
          d: "M" + x + " " + H + " L" + x + " " + (y + r) + " Q" + x + " " + y + " " + (x + r) + " " + y
            + " L" + (x + w - r) + " " + y + " Q" + (x + w) + " " + y + " " + (x + w) + " " + (y + r)
            + " L" + (x + w) + " " + H + " Z",
          fill: color,
        }));
      }
      const hit = mk("rect", { x: x, y: 0, width: bw, height: H, fill: "transparent", class: "mx-hit" });
      const label = mxDate(rows[i].day) + " · " + (opts.fmt ? opts.fmt(v) : v) + " " + (opts.unit || "");
      hit.addEventListener("pointerenter", () => { tipText.textContent = label; tip.classList.add("on"); });
      hit.addEventListener("pointerleave", () => tip.classList.remove("on"));
      svg.appendChild(hit);
    });
    const total = vals.reduce((a, b) => a + b, 0);
    return el("div", { class: "mx-chart" }, [
      el("div", { class: "mx-chart-head" }, [
        el("span", { class: "mx-chart-t" }, [el("i", { class: "mx-swatch", style: "background:" + color }, []), title]),
        el("span", { class: "mx-chart-max" }, [opts.summary ? opts.summary(total, max) : ("peak " + max)]),
      ]),
      el("div", { class: "mx-plot" }, [svg, tip]),
      el("div", { class: "mx-axis" }, [
        el("span", {}, [rows.length ? mxDay(rows[0].day) : ""]),
        el("span", {}, [rows.length ? mxDay(rows[rows.length - 1].day) : ""]),
      ]),
    ]);
  }

  // Activity-by-hour: same bar treatment, but the x axis is the 24 UTC hours rather than dates.
  // This is the chart that answers "when should an event or a restart go", which no daily series can.
  function mxHourChart(hours) {
    const rows = (hours || []).map((v, i) => ({ day: i, v: Number(v) || 0 }));
    const W = 300, H = 44, GAP = 2;
    const max = Math.max(1, ...rows.map((r) => r.v));
    const bw = W / 24;
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 " + W + " " + H);
    svg.setAttribute("preserveAspectRatio", "none");
    svg.setAttribute("class", "mx-svg");
    // The label lives in a child span so its background hugs the text; a background on the
    // full-width tip itself would draw a bar across the plot.
    const tip = el("div", { class: "mx-tip" }, [el("span", {}, [])]);
    const tipText = tip.firstChild;
    rows.forEach((r, i) => {
      const x = i * bw, h = Math.max(r.v > 0 ? 2 : 0, Math.round((r.v / max) * (H - 2)));
      if (h > 0) {
        const e = document.createElementNS("http://www.w3.org/2000/svg", "rect");
        e.setAttribute("x", x); e.setAttribute("y", H - h);
        e.setAttribute("width", Math.max(1, bw - GAP)); e.setAttribute("height", h);
        e.setAttribute("rx", "2"); e.setAttribute("fill", MX_COLORS.players);
        svg.appendChild(e);
      }
      const hit = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      hit.setAttribute("x", x); hit.setAttribute("y", 0);
      hit.setAttribute("width", bw); hit.setAttribute("height", H);
      hit.setAttribute("fill", "transparent");
      const lbl = String(i).padStart(2, "0") + ":00 UTC · " + r.v + " logins";
      hit.addEventListener("pointerenter", () => { tipText.textContent = lbl; tip.classList.add("on"); });
      hit.addEventListener("pointerleave", () => tip.classList.remove("on"));
      svg.appendChild(hit);
    });
    return el("div", { class: "mx-chart" }, [
      el("div", { class: "mx-chart-head" }, [
        el("span", { class: "mx-chart-t" }, [el("i", { class: "mx-swatch", style: "background:" + MX_COLORS.players }, []), "Logins by hour (UTC)"]),
        el("span", { class: "mx-chart-max" }, ["peak " + max]),
      ]),
      el("div", { class: "mx-plot" }, [svg, tip]),
      el("div", { class: "mx-axis" }, [el("span", {}, ["00"]), el("span", {}, ["06"]), el("span", {}, ["12"]), el("span", {}, ["18"]), el("span", {}, ["23"])]),
    ]);
  }

  // Mode mix as labelled magnitude bars (one hue, length carries the value) rather than a pie or a
  // five-colour stack: the label is already on every row, so colour would be decoration — and a
  // five-slot categorical palette that survives colour-vision checks is not worth spending here.
  function mxModeMix(mix) {
    const rows = MX_MODES.map(([k, label]) => [label, Number((mix || {})[k]) || 0]).filter((r) => r[1] > 0);
    const total = rows.reduce((a, r) => a + r[1], 0);
    if (!total) return el("div", { class: "admin-note" }, ["No matches recorded in this window."]);
    const max = Math.max(...rows.map((r) => r[1]));
    return el("div", { class: "mx-mix" }, rows.sort((a, b) => b[1] - a[1]).map(([label, v]) =>
      el("div", { class: "mx-mix-row" }, [
        el("span", { class: "mx-mix-l" }, [label]),
        el("span", { class: "mx-mix-bar" }, [el("i", { style: "width:" + Math.round((v / max) * 100) + "%;background:" + MX_COLORS.matches }, [])]),
        el("span", { class: "mx-mix-v" }, [String(v), el("span", { class: "mx-mix-p" }, [" " + mxPct(v, total)])]),
      ])));
  }

  // The table view every chart is required to have: the same daily numbers as text, for reading
  // exact values, copying them out, and for anyone the charts don't work for.
  function mxTable(series) {
    const head = el("div", { class: "mx-tr mx-th" }, ["Day", "Players", "Sess", "Matches", "New", "Peak"].map((h) => el("span", {}, [h])));
    const rows = series.slice().reverse().map((r) => el("div", { class: "mx-tr" }, [
      el("span", {}, [mxDate(r.day)]),
      el("span", {}, [String(r.players)]),
      el("span", {}, [String(r.sessions)]),
      el("span", {}, [String(r.matches)]),
      el("span", {}, [String(r.registrations)]),
      el("span", {}, [String(r.peak_online)]),
    ]));
    return el("div", { class: "mx-table" }, [head, ...rows]);
  }

  // Tab-separated dump of the day series to the clipboard — the fastest path from "interesting"
  // to a spreadsheet, and the reason this dashboard doesn't need an export endpoint.
  function mxCopySeries() {
    const s = (_adminMetrics && _adminMetrics.series) || [];
    const lines = ["day\tplayers\tsessions\tsession_seconds\tmatches\tmatch_players\tnew_accounts\tpeak_online"];
    s.forEach((r) => lines.push([mxDate(r.day), r.players, r.sessions, r.seconds, r.matches, r.match_players, r.registrations, r.peak_online].join("\t")));
    const text = lines.join("\n");
    const done = () => showToast("Copied " + s.length + " days", "ok");
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done).catch(() => showToast("Copy failed", "err"));
    else showToast("Clipboard unavailable", "err");
  }

  function renderAdminMetrics() {
    if (!_adminPanel) return;
    const box = _adminPanel.querySelector(".mx-body");
    if (!box) return;
    box.innerHTML = "";
    const m = _adminMetrics;
    if (!m) { box.appendChild(el("div", { class: "admin-empty" }, ["Loading…"])); return; }
    if (m.unavailable) { box.appendChild(el("div", { class: "admin-note" }, ["Metrics storage is unavailable on the server (SQLite failed to open) — nothing is being recorded."])); return; }
    const live = m.live || {};
    const sess = m.sessions || {};
    const mix = m.mix || {};
    const series = m.series || [];

    // --- right now ---
    box.appendChild(el("div", { class: "admin-sec" }, ["Right now"]));
    box.appendChild(el("div", { class: "mx-live" }, [
      el("span", { class: "mx-live-dot" + (live.online > 0 ? " on" : "") }, []),
      el("b", {}, [String(live.online || 0)]), " online · ",
      el("b", {}, [String(live.in_match || 0)]), " in match · ",
      el("b", {}, [String(live.queued || 0)]), " queued · ",
      el("b", {}, [String(live.matches || 0)]), " live games",
    ]));

    // --- headline tiles ---
    box.appendChild(el("div", { class: "admin-sec" }, ["Active players"]));
    box.appendChild(el("div", { class: "mx-tiles" }, [
      mxTile("Today", mxNum(m.dau), "unique", MX_COLORS.players),
      mxTile("7 days", mxNum(m.wau), "unique", MX_COLORS.players),
      mxTile("30 days", mxNum(m.mau), "unique", MX_COLORS.players),
    ]));
    box.appendChild(el("div", { class: "mx-tiles" }, [
      mxTile("New accounts", mxNum((m.registrations || {}).count), "in window", MX_COLORS.signups),
      mxTile("Matches", mxNum((m.matches || {}).refs), "in window", MX_COLORS.matches),
      mxTile("Peak online", mxNum((m.peak || {}).online), (m.peak && m.peak.ts) ? mxDate(m.peak.ts) : "in window", MX_COLORS.peak),
    ]));
    box.appendChild(el("div", { class: "mx-tiles" }, [
      mxTile("Visits", mxNum(sess.sessions), "sessions"),
      mxTile("Typical visit", mxDur(sess.median), "median"),
      mxTile("Returning", mxPct(mix.returning, (mix.new || 0) + (mix.returning || 0)), (mix.new || 0) + " new"),
    ]));

    // --- small multiples ---
    box.appendChild(el("div", { class: "admin-sec admin-sec-row" }, [
      el("span", {}, ["Daily trend"]),
      el("button", { class: "admin-btn admin-btn-sm", onclick: () => { _adminMetricsTable = !_adminMetricsTable; renderAdminMetrics(); } }, [_adminMetricsTable ? "Charts" : "Table"]),
    ]));
    if (_adminMetricsTable) {
      box.appendChild(mxTable(series));
    } else {
      box.appendChild(mxChart("Active players", series, "players", MX_COLORS.players, { unit: "players" }));
      box.appendChild(mxChart("Matches played", series, "matches", MX_COLORS.matches, { unit: "matches" }));
      box.appendChild(mxChart("New accounts", series, "registrations", MX_COLORS.signups, {
        unit: "sign-ups", summary: (total) => total + " total",
      }));
      box.appendChild(mxChart("Peak concurrent", series, "peak_online", MX_COLORS.peak, { unit: "online" }));
      box.appendChild(mxHourChart(m.hours));
    }

    // --- what they played ---
    box.appendChild(el("div", { class: "admin-sec" }, ["Matches by mode"]));
    box.appendChild(mxModeMix(m.matches_by_mode));

    // --- retention ---
    // Only MATURE cohorts are charted as rates: a cohort whose week hasn't closed can only ever
    // rise, so showing its D7 next to a finished one invites reading a fall that isn't there.
    const ret = (m.retention || []).filter((c) => c.mature && c.size > 0);
    box.appendChild(el("div", { class: "admin-sec" }, ["New-player retention"]));
    if (!ret.length) {
      box.appendChild(el("div", { class: "admin-note" }, ["No cohort has finished its first week yet — retention needs 8 days of tracking before it can be measured."]));
    } else {
      const size = ret.reduce((a, c) => a + c.size, 0);
      const d1 = ret.reduce((a, c) => a + c.d1, 0);
      const d7 = ret.reduce((a, c) => a + c.d7, 0);
      box.appendChild(el("div", { class: "mx-tiles" }, [
        mxTile("Came back next day", mxPct(d1, size), d1 + " of " + size),
        mxTile("Came back that week", mxPct(d7, size), d7 + " of " + size),
        mxTile("First-timers", mxNum(size), ret.length + " cohorts"),
      ]));
    }

    // --- most active players ---
    box.appendChild(el("div", { class: "admin-sec" }, ["Most active players"]));
    const top = m.top_players || [];
    if (!top.length) {
      box.appendChild(el("div", { class: "admin-note" }, ["No visits recorded in this window."]));
    } else {
      const maxSecs = Math.max(1, ...top.map((p) => p.seconds || 0));
      box.appendChild(el("div", { class: "mx-top" }, top.map((p) => el("div", {
        class: "mx-top-row", title: "Last seen " + timeAgo(p.last_seen),
        // Clicking a name drops it into the Players tab's target field — the usual next question
        // after "who is here a lot" is "what does this account look like".
        onclick: () => { const t = _adminPanel && _adminPanel.querySelector(".admin-target"); if (t) { t.value = p.username; _adminTab = "players"; renderAdminTab(); } },
      }, [
        el("span", { class: "mx-top-n" + (p.online ? " on" : "") }, [p.username]),
        el("span", { class: "mx-top-bar" }, [el("i", { style: "width:" + Math.round(((p.seconds || 0) / maxSecs) * 100) + "%;background:" + MX_COLORS.players }, [])]),
        el("span", { class: "mx-top-v" }, [mxDur(p.seconds), el("span", { class: "mx-top-s" }, [" · " + p.sessions + "v · " + p.matches + "m"])]),
      ]))));
    }

    // --- provenance ---
    // Says exactly how far back each kind of number goes. Match history is backfilled from the match
    // archive and reaches back years; visits/sessions/concurrency only exist from the day tracking
    // shipped. Presenting them as one continuous history would read as a traffic collapse that never
    // happened, so the footer states both spans and marks any window that predates them.
    const vs = m.visit_span || [0, 0];
    const foot = [];
    foot.push(mxNum(m.total_accounts) + " accounts total");
    foot.push("window " + mxDate(m.from_ts) + " → " + mxDate(m.now) + " (UTC days)");
    if (vs[0]) {
      foot.push("session tracking since " + mxDate(vs[0]));
      if (m.from_ts < vs[0]) foot.push("⚠ days before " + mxDate(vs[0]) + " have match history only — no visit data existed yet");
    } else {
      foot.push("⚠ no visits recorded yet — session metrics start at the first login after this build");
    }
    box.appendChild(el("div", { class: "mx-foot" }, [foot.join(" · ")]));
  }

  function buildAdminMetricsTab() {
    const rangeBtns = [[7, "7d"], [30, "30d"], [90, "90d"], [365, "1y"]].map(([k, label]) =>
      el("button", { class: "admin-mtab", "data-k": String(k), onclick: () => {
        _adminMetricsDays = k;
        rangeBtns.forEach((b) => b.classList.toggle("sel", b.dataset.k === String(k)));
        refreshAdminMetrics();
      } }, [label]));
    rangeBtns.forEach((b) => b.classList.toggle("sel", b.dataset.k === String(_adminMetricsDays)));
    return el("div", { class: "admin-tabbody mx-tab" }, [
      el("div", { class: "admin-sec admin-sec-row" }, [
        el("span", {}, ["Site Usage"]),
        el("span", { class: "admin-row" }, [
          el("button", { class: "admin-btn admin-btn-sm", onclick: mxCopySeries }, ["Copy"]),
          el("button", { class: "admin-btn admin-btn-sm", onclick: refreshAdminMetrics }, ["Refresh"]),
        ]),
      ]),
      el("div", { class: "admin-mrow" }, [el("span", { class: "admin-mlabel" }, ["Range"]), ...rangeBtns]),
      el("div", { class: "mx-body" }, []),
    ]);
  }

  // The "Nexus" tab: close a voting round — remove the top N by AP + halve everyone else's AP.
  function buildAdminNexusTab() {
    const countIn = el("input", { class: "admin-input admin-sm", type: "number", min: "0", value: "3", title: "How many top characters to remove" });
    const preview = el("div", { class: "admin-nx-preview" }, []);
    const getN = () => Math.max(0, Math.trunc(Number(countIn.value) || 0));
    const renderPreview = () => {
      if (!preview.isConnected) return;   // stale closure after tab switch / panel close
      const n = getN();
      const sorted = Object.keys(S.nexusBuckets || {}).map((p) => [p, S.nexusBuckets[p]]).sort((a, b) => b[1] - a[1]);
      preview.innerHTML = "";
      preview.appendChild(el("div", { class: "admin-sec admin-sec-row" }, [
        el("span", {}, ["Top " + n + " to be removed"]),
        el("button", { class: "admin-btn admin-btn-sm", onclick: () => S.net.send("nexus_state", {}) }, ["Refresh"]),
      ]));
      if (!sorted.length) { preview.appendChild(el("div", { class: "admin-empty" }, ["Loading Nexus standings…"])); return; }
      sorted.slice(0, n).forEach((e, i) => preview.appendChild(el("div", { class: "admin-nx-prow" }, [
        el("span", { class: "admin-st-rank" }, ["#" + (i + 1)]),
        el("span", { class: "admin-st-cn" }, [nameFor(e[0])]),
        el("span", { class: "admin-st-num" }, [fmtAp(e[1]) + " AP"]),
      ])));
      if (!n) preview.appendChild(el("div", { class: "admin-note" }, ["Nothing removed — only the AP halving will apply."]));
    };
    _adminNexusPreview = renderPreview;
    countIn.addEventListener("input", renderPreview);
    S.net.send("nexus_state", {});   // fetch fresh standings for the preview
    let armed = false, armTimer = null;
    const disarm = () => { armed = false; clearTimeout(armTimer); closeBtn.textContent = "Close Round"; closeBtn.classList.remove("armed"); };
    const closeBtn = el("button", { class: "admin-btn admin-btn-danger admin-btn-block" }, ["Close Round"]);
    closeBtn.addEventListener("click", () => {
      const n = getN();
      if (!armed) {   // two-click arm — no native confirm() (blocks the preview harness & can be suppressed)
        armed = true;
        closeBtn.textContent = "⚠ Confirm: remove top " + n + " & halve rest";
        closeBtn.classList.add("armed");
        clearTimeout(armTimer);
        armTimer = setTimeout(disarm, 4000);
        return;
      }
      disarm();
      S.net.send("admin_close_nexus_round", { count: n });   // server re-checks admin authority
      set({ msg: "Closing Nexus round…", msgKind: "ok" });
    });
    // Scale-all-AP: multiply every bucket's AP by a value (decimal < 1 divides). Two-click arm, like Close Round.
    const multIn = el("input", { class: "admin-input admin-sm", type: "number", min: "0", step: "0.1", value: "1", title: "Multiply every character's AP by this (use a decimal like 0.5 to divide)" });
    let scaleArmed = false, scaleArmTimer = null;
    const scaleBtn = el("button", { class: "admin-btn admin-btn-danger admin-btn-block" }, ["Scale AP"]);
    const scaleDisarm = () => { scaleArmed = false; clearTimeout(scaleArmTimer); scaleBtn.textContent = "Scale AP"; scaleBtn.classList.remove("armed"); };
    scaleBtn.addEventListener("click", () => {
      const mult = Number(multIn.value);
      if (!isFinite(mult) || mult <= 0) { set({ msg: "Enter a multiplier greater than 0", msgKind: "err" }); return; }
      if (!scaleArmed) {   // two-click arm — a global, irreversible AP change
        scaleArmed = true;
        scaleBtn.textContent = "⚠ Confirm: multiply all AP ×" + mult;
        scaleBtn.classList.add("armed");
        clearTimeout(scaleArmTimer);
        scaleArmTimer = setTimeout(scaleDisarm, 4000);
        return;
      }
      scaleDisarm();
      S.net.send("admin_scale_nexus_ap", { multiplier: mult });   // server re-checks admin authority
      set({ msg: "Scaling Nexus AP…", msgKind: "ok" });
    });
    const tab = el("div", { class: "admin-tabbody" }, [
      el("div", { class: "admin-sec" }, ["🗳️ Close Voting Round"]),
      el("div", { class: "admin-note" }, ["Removes the top N characters from the Nexus — they leave permanently and the server stops accepting/tracking their AP — then halves every remaining character's AP so the standings order stays the same but the field is easier to catch."]),
      el("div", { class: "admin-row" }, [el("span", { class: "admin-mlabel" }, ["Remove top"]), countIn]),
      preview,
      el("div", { class: "admin-row" }, [closeBtn]),
      el("div", { class: "admin-sec" }, ["✖️ Scale All AP"]),
      el("div", { class: "admin-note" }, ["Multiplies every Nexus character's AP by the multiplier (use a decimal like 0.5 to divide). Results are rounded to the nearest integer."]),
      el("div", { class: "admin-row" }, [el("span", { class: "admin-mlabel" }, ["Multiplier"]), multIn]),
      el("div", { class: "admin-row" }, [scaleBtn]),
      el("div", { class: "admin-sec" }, ["🎡 Raffle Wheel"]),
      el("div", { class: "admin-note" }, ["Spin a weighted wheel over the top 10 Nexus characters (1 AP = 1 ticket) to draw a winner. Uses the current live standings — open it and screen-share for players to watch. Read-only: it never changes any AP. Each spin draws without replacement, so you can pull 2-3 winners in a row."]),
      el("div", { class: "admin-row" }, [el("button", { class: "admin-btn admin-btn-primary admin-btn-block", onclick: openNexusRaffle }, ["🎡 Open Raffle Wheel"])]),
    ]);
    setTimeout(renderPreview, 0);   // initial paint (buckets may already be cached)
    return tab;
  }
  // ── Nexus raffle wheel (admin tool) ──────────────────────────────────────
  // Imperative overlay (NOT state-driven) so the canvas spin survives app re-renders. Weighted
  // raffle over the top-10 Nexus characters by AP (1 AP = 1 ticket), client-side on the live
  // S.nexusBuckets standings; drawn WITHOUT replacement so 2-3 winners can be pulled in a row.
  const RAFFLE_COLORS = ["#e0466b", "#f28e2b", "#edc948", "#59a14f", "#4e9ec7", "#7c6cf0", "#b07aa1", "#ff9da7", "#59c3a5", "#d98a5f"];
  function openNexusRaffle() {
    const src = Object.keys(S.nexusBuckets || {}).map((p) => [p, S.nexusBuckets[p] || 0]).filter((e) => e[1] > 0).sort((a, b) => b[1] - a[1]);
    if (src.length < 2) { set({ msg: "Need at least 2 characters with AP for a raffle", msgKind: "err" }); return; }
    let remaining = src.slice(0, 10);   // top 10 by AP, drawn without replacement
    const DPR = Math.min(2, window.devicePixelRatio || 1), SIZE = 460;
    const canvas = el("canvas", { class: "raffle-canvas", width: SIZE * DPR, height: SIZE * DPR });
    const ctx = canvas.getContext("2d");
    const imgs = {};
    src.slice(0, 10).forEach(([p]) => { const im = new Image(); im.onload = () => draw(rotation); im.src = portraitUrlFor(p) || ""; imgs[p] = im; });
    let rotation = -Math.PI / 2, slices = [], total = 0;
    function recompute() {
      total = remaining.reduce((s, e) => s + e[1], 0);
      slices = []; let a = 0;
      for (const [path, ap] of remaining) { const size = (ap / total) * 2 * Math.PI; slices.push({ path: path, ap: ap, a0: a, a1: a + size, mid: a + size / 2 }); a += size; }
    }
    function draw(rot) {
      ctx.save(); ctx.scale(DPR, DPR);
      ctx.clearRect(0, 0, SIZE, SIZE);
      const cx = SIZE / 2, cy = SIZE / 2, R = SIZE / 2 - 8;
      ctx.save(); ctx.translate(cx, cy); ctx.rotate(rot);
      slices.forEach((s, i) => {
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.arc(0, 0, R, s.a0, s.a1); ctx.closePath();
        ctx.fillStyle = RAFFLE_COLORS[i % RAFFLE_COLORS.length]; ctx.fill();
        ctx.lineWidth = 2; ctx.strokeStyle = "rgba(10,10,16,.5)"; ctx.stroke();
        const span = s.a1 - s.a0;
        ctx.save(); ctx.rotate(s.mid);
        const im = imgs[s.path];
        if (im && im.complete && im.naturalWidth && span > 0.30) {   // portrait bubble near the rim
          const pr = Math.min(30, R * 0.13), px = R * 0.72;
          ctx.save(); ctx.beginPath(); ctx.arc(px, 0, pr, 0, 2 * Math.PI); ctx.closePath(); ctx.clip();
          ctx.drawImage(im, px - pr, -pr, pr * 2, pr * 2); ctx.restore();
          ctx.beginPath(); ctx.arc(px, 0, pr, 0, 2 * Math.PI); ctx.lineWidth = 2; ctx.strokeStyle = "rgba(255,255,255,.85)"; ctx.stroke();
        }
        if (span > 0.12) {   // name label
          ctx.fillStyle = "#fff"; ctx.font = "bold 13px system-ui, sans-serif"; ctx.textAlign = "right"; ctx.textBaseline = "middle";
          ctx.shadowColor = "rgba(0,0,0,.65)"; ctx.shadowBlur = 3;
          ctx.fillText(nameFor(s.path), R - 8, span > 0.30 ? -15 : 0);
          ctx.shadowBlur = 0;
        }
        ctx.restore();
      });
      ctx.restore();
      ctx.beginPath(); ctx.arc(cx, cy, 26, 0, 2 * Math.PI); ctx.fillStyle = "#14141c"; ctx.fill();
      ctx.lineWidth = 3; ctx.strokeStyle = "#ffd400"; ctx.stroke();
      ctx.fillStyle = "#ffd400"; ctx.font = "18px system-ui"; ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillText("🎡", cx, cy + 1);
      ctx.restore();
    }
    recompute(); draw(rotation);

    let spinning = false;
    const status = el("div", { class: "raffle-status" }, ["Top " + remaining.length + " · " + fmtAp(total) + " AP in play"]);
    const winnerBox = el("div", { class: "raffle-winner-box" }, []);
    const spinBtn = el("button", { class: "raffle-spin" }, ["🎯 Spin"]);
    function pickWinnerIndex() {
      let ticket = Math.floor(Math.random() * total), cum = 0;
      for (let i = 0; i < remaining.length; i++) { cum += remaining[i][1]; if (ticket < cum) return i; }
      return remaining.length - 1;
    }
    function spin() {
      if (spinning || remaining.length < 2) return;
      spinning = true; spinBtn.disabled = true; winnerBox.innerHTML = ""; draw(rotation);
      const wIdx = pickWinnerIndex(), winner = slices[wIdx];
      const pointer = -Math.PI / 2, TWO_PI = 2 * Math.PI;
      let target = pointer - winner.mid;
      while (target < rotation + 5 * TWO_PI) target += TWO_PI;
      const start = rotation, dur = 5200, t0 = performance.now();
      (function frame(now) {
        const t = Math.min(1, (now - t0) / dur), e = 1 - Math.pow(1 - t, 3);
        rotation = start + (target - start) * e; draw(rotation);
        if (t < 1) requestAnimationFrame(frame); else finish(winner);
      })(performance.now());
    }
    function finish(winner) {
      spinning = false;
      const purl = portraitUrlFor(winner.path);
      winnerBox.innerHTML = "";
      winnerBox.appendChild(el("div", { class: "raffle-winner" }, [
        purl ? el("img", { class: "raffle-w-pic", src: purl, alt: "" }) : el("span", { class: "raffle-w-pic" }, []),
        el("div", { class: "raffle-w-txt" }, [
          el("div", { class: "raffle-w-tag" }, ["🎉 WINNER 🎉"]),
          el("div", { class: "raffle-w-name" }, [nameFor(winner.path)]),
          el("div", { class: "raffle-w-ap" }, [fmtAp(winner.ap) + " AP"]),
        ]),
      ]));
      remaining = remaining.filter((e) => e[0] !== winner.path);   // without replacement
      recompute();
      status.textContent = remaining.length >= 2
        ? remaining.length + " left · " + fmtAp(total) + " AP in play"
        : (remaining.length === 1 ? nameFor(remaining[0][0]) + " is the only one left" : "Field empty");
      spinBtn.disabled = remaining.length < 2;
      spinBtn.textContent = remaining.length >= 2 ? "🎯 Spin Again (" + remaining.length + " left)" : "🎯 Spin";
    }
    spinBtn.addEventListener("click", spin);
    const overlay = el("div", { class: "raffle-overlay" }, [
      el("div", { class: "raffle-panel" }, [
        el("button", { class: "raffle-close", title: "Close", onclick: () => overlay.remove() }, ["✕"]),
        el("div", { class: "raffle-title" }, ["🎡 Nexus Raffle"]),
        status,
        el("div", { class: "raffle-stage" }, [el("div", { class: "raffle-pointer" }, []), canvas]),
        winnerBox,
        el("div", { class: "raffle-actions" }, [spinBtn]),
      ]),
    ]);
    overlay.addEventListener("click", (e) => { if (e.target === overlay) overlay.remove(); });
    document.body.appendChild(overlay);
  }

  // ---- Training tab: v3 bot self-play status, Elo ladder, replays, tuning editor ----
  function refreshAdminTraining() {
    S.net.send("admin_training_status", {});
    S.net.send("admin_get_bot_tuning", {});
  }
  function trainStat(label, val, extra) {
    return el("div", { class: "admin-train-stat" + (extra ? " " + extra : "") }, [el("span", { class: "admin-mlabel" }, [label]), el("b", {}, [String(val)])]);
  }
  function buildAdminTrainingTab() {
    return el("div", { class: "admin-tabbody" }, [
      el("div", { class: "admin-sec admin-sec-row" }, [el("span", {}, ["Bot Training (v3)"]), el("button", { class: "admin-btn admin-btn-sm", onclick: refreshAdminTraining }, ["Refresh"])]),
      el("div", { class: "admin-train-status" }, [el("div", { class: "sub" }, ["Loading…"])]),
      el("div", { class: "admin-sec" }, ["Elo ladder"]),
      el("div", { class: "admin-train-elo" }, []),
      el("div", { class: "admin-sec" }, ["Training replays"]),
      el("div", { class: "admin-train-replays" }, []),
      el("div", { class: "admin-sec" }, ["Tuning overlay (bot_tuning.json)"]),
      el("div", { class: "admin-train-tuning" }, []),
    ]);
  }
  // Fill the Training tab from the cached payloads. Tolerates the tab being
  // closed (no-op) and re-renders in place so Refresh doesn't lose scroll.
  function renderAdminTrainingBody() {
    if (!_adminPanel) return;
    const statusBox = _adminPanel.querySelector(".admin-train-status");
    if (!statusBox) return;   // Training tab not open
    const t = _adminTraining || {};
    const st = t.status && Object.keys(t.status).length ? t.status : null;
    statusBox.innerHTML = "";
    if (!st) {
      statusBox.appendChild(el("div", { class: "sub" }, ["No training run recorded yet — start one with training/orchestrate_training.ps1."]));
    } else {
      const total = (st.wins || 0) + (st.losses || 0) + (st.draws || 0);
      const wr = total ? Math.round((st.wins / total) * 1000) / 10 : 0;
      statusBox.appendChild(el("div", { class: "admin-train-grid" }, [
        trainStat("State", st.done ? "finished" : "running", st.done ? "" : "live"),
        trainStat("Matches", (st.matches_done || 0) + " / " + (st.num_matches || 0)),
        trainStat("W / L / D", (st.wins || 0) + " / " + (st.losses || 0) + " / " + (st.draws || 0)),
        trainStat("Win rate", wr + "%"),
        trainStat("Opponent", st.opponent || "—"),
        trainStat("Generation", st.generation != null ? st.generation : "—"),
        trainStat("Live policy", (t.live_generation != null && t.live_generation >= 0) ? "gen " + t.live_generation : "not promoted"),
        trainStat("Updated", st.updated || "—"),
      ]));
    }
    // Elo ladder: DOM bar rows (dependency-free) + the most recent eval blocks.
    const eloBox = _adminPanel.querySelector(".admin-train-elo");
    eloBox.innerHTML = "";
    const ratings = (t.elo && t.elo.ratings) || null;
    if (!ratings || !Object.keys(ratings).length) {
      eloBox.appendChild(el("div", { class: "sub" }, ["No eval blocks yet."]));
    } else {
      const rows = Object.keys(ratings).map((k) => [k, Number(ratings[k]) || 0]).sort((a, b) => b[1] - a[1]);
      let max = rows[0][1], min = 750;
      for (const r of rows) if (r[1] < min) min = r[1];
      for (const pair of rows) {
        const pct = Math.max(4, Math.round(((pair[1] - min) / Math.max(1, max - min)) * 100));
        eloBox.appendChild(el("div", { class: "admin-elo-row" }, [
          el("span", { class: "admin-elo-name" }, [pair[0]]),
          el("div", { class: "admin-elo-track" }, [el("i", { class: "admin-elo-bar", style: "width:" + pct + "%" })]),
          el("span", { class: "admin-elo-val" }, [String(Math.round(pair[1]))]),
        ]));
      }
      const hist = ((t.elo.history || []).slice(-6)).reverse();
      for (const h of hist) {
        const n = (h.w || 0) + (h.l || 0) + (h.d || 0);
        const wr2 = n ? Math.round(((h.w + 0.5 * (h.d || 0)) / n) * 100) : 0;
        eloBox.appendChild(el("div", { class: "admin-elo-hist sub" }, [h.a + " vs " + h.b + ":  " + (h.w || 0) + "W / " + (h.l || 0) + "L / " + (h.d || 0) + "D  (" + wr2 + "%)"]));
      }
    }
    // Training replays: latest first, Watch streams through the shared
    // replay_data chunk path straight into the existing viewer.
    const repBox = _adminPanel.querySelector(".admin-train-replays");
    repBox.innerHTML = "";
    const reps = t.replays || [];
    if (!reps.length) {
      repBox.appendChild(el("div", { class: "sub" }, ["None saved yet (run the trainer with --replay-every=N)."]));
    }
    for (const name of reps.slice(-12).reverse()) {
      repBox.appendChild(el("div", { class: "admin-train-rep" }, [
        el("span", { class: "admin-rep-name" }, [name]),
        el("button", { class: "admin-btn admin-btn-sm", onclick: () => { S.net.send("admin_fetch_training_replay", { name: name }); showToast("Fetching training replay…", "info"); closeAdminPanel(); } }, ["Watch"]),
      ]));
    }
    // Tuning editor. The module-level DRAFT is the source of truth while the
    // admin is typing: it survives re-renders, tab switches, and panel
    // toggles, and only a successful Save (or no edits at all) lets the
    // server payload repopulate the textarea.
    const tunBox = _adminPanel.querySelector(".admin-train-tuning");
    let ta = tunBox.querySelector("textarea");
    if (!ta) {
      tunBox.innerHTML = "";
      ta = el("textarea", { class: "admin-tuning-edit", spellcheck: "false" });
      ta.addEventListener("input", () => { _adminTuningDraft = ta.value; });
      tunBox.appendChild(ta);
      tunBox.appendChild(el("div", { class: "admin-sec-row" }, [
        el("button", { class: "admin-btn", onclick: () => {
          let parsed;
          try { parsed = JSON.parse(ta.value); } catch (e) { return showToast("Tuning is not valid JSON: " + e.message, "err"); }
          _adminTuningPending = parsed;
          S.net.send("admin_set_bot_tuning", { tuning: parsed });
        } }, ["Save tuning"]),
        el("span", { class: "sub" }, ["Hot-reloads live bots (offsets, multipliers, bans, difficulty temps)"]),
      ]));
    }
    if (_adminTuningDraft != null) {
      if (ta.value !== _adminTuningDraft) ta.value = _adminTuningDraft;
    } else if (_adminTuning && document.activeElement !== ta) {
      const fresh = JSON.stringify(_adminTuning, null, 2);
      if (ta.value !== fresh) ta.value = fresh;
    }
  }

  // Swap the .admin-body content for the active tab and mark the selected button.
  function renderAdminTab() {
    if (!_adminPanel) return;
    const body = _adminPanel.querySelector(".admin-body");
    if (!body) return;
    _adminPanel.querySelectorAll(".admin-tab").forEach((b) => b.classList.toggle("sel", b.dataset.tab === _adminTab));
    body.innerHTML = "";
    // The dashboard needs more width than the 360px tool panel: four charts, a table view and a
    // day axis are unreadable at that size. Widen the whole panel while it is showing (still
    // capped to the viewport, so on a phone it stays exactly as wide as it was).
    _adminPanel.classList.toggle("wide", _adminTab === "metrics");
    if (_adminTab === "usage") {
      body.appendChild(buildAdminUsageTab());
      renderAdminStatsTable();   // paint the cached (or empty) data at once
      refreshAdminStats();       // then request a fresh snapshot
    } else if (_adminTab === "metrics") {
      body.appendChild(buildAdminMetricsTab());
      renderAdminMetrics();      // paint the cached (or empty) payload at once
      refreshAdminMetrics();     // then request a fresh one
    } else if (_adminTab === "nexus") {
      body.appendChild(buildAdminNexusTab());
    } else if (_adminTab === "training") {
      body.appendChild(buildAdminTrainingTab());
      renderAdminTrainingBody();   // paint cached data at once
      refreshAdminTraining();      // then request fresh status + tuning
    } else if (_adminTab === "bots") {
      body.appendChild(buildAdminBotsTab());
      renderAdminBots();           // paint cached data at once
      refreshAdminBots();          // then request a fresh status snapshot
    } else if (_adminTab === "characters") {
      body.appendChild(buildAdminCharactersTab());
    } else {
      body.appendChild(buildAdminPlayersTab());
      refreshAdminPlayers();
    }
  }
  function openAdminPanel() {
    if (_adminPanel) { closeAdminPanel(); return; }
    _adminPanel = el("div", { class: "admin-panel" }, [
      el("div", { class: "admin-head" }, [
        el("div", { class: "admin-title" }, ["🛡️ Admin"]),
        el("button", { class: "admin-x", onclick: closeAdminPanel, title: "Close" }, ["✕"]),
      ]),
      el("div", { class: "admin-tabs" }, [
        el("button", { class: "admin-tab", "data-tab": "players", onclick: () => { _adminTab = "players"; renderAdminTab(); } }, ["Players"]),
        el("button", { class: "admin-tab", "data-tab": "metrics", onclick: () => { _adminTab = "metrics"; renderAdminTab(); } }, ["Metrics"]),
        el("button", { class: "admin-tab", "data-tab": "usage", onclick: () => { _adminTab = "usage"; renderAdminTab(); } }, ["Char Usage"]),
        el("button", { class: "admin-tab", "data-tab": "nexus", onclick: () => { _adminTab = "nexus"; renderAdminTab(); } }, ["Nexus"]),
        el("button", { class: "admin-tab", "data-tab": "training", onclick: () => { _adminTab = "training"; renderAdminTab(); } }, ["Training"]),
        el("button", { class: "admin-tab", "data-tab": "bots", onclick: () => { _adminTab = "bots"; renderAdminTab(); } }, ["Bots"]),
        el("button", { class: "admin-tab", "data-tab": "characters", onclick: () => { _adminTab = "characters"; renderAdminTab(); } }, ["Characters"]),
      ]),
      el("div", { class: "admin-body" }, []),
    ]);
    document.body.appendChild(_adminPanel);
    renderAdminTab();
  }
  // ---- audio volume control (mute icon + slider). Client master volume/mute (persisted). Shown as a
  // bubble in the bottom-left during battle (near Surrender) and as a row in the Settings menu. ----
  function volIcon() {
    if (_sfxMuted || _sfxVolume <= 0.001) return "🔇";
    if (_sfxVolume < 0.34) return "🔈";
    if (_sfxVolume < 0.67) return "🔉";
    return "🔊";
  }
  // Build a fresh {icon, slider} pair wired to _sfxVolume/_sfxMuted. Updates its own DOM in place (no
  // full re-render), so dragging the slider is cheap even over the heavy battle screen.
  function buildVolControl() {
    const icon = el("button", { class: "vol-icon", type: "button", title: "Mute / unmute all audio" }, [volIcon()]);
    const slider = el("input", { class: "vol-slider", type: "range", min: "0", max: "100", value: String(Math.round(_sfxVolume * 100)), title: "Volume", "aria-label": "Volume" });
    // sync also retunes an in-flight VFX clip, so mute/volume changes take effect immediately
    // instead of only applying to the next sound.
    const sync = () => { icon.textContent = volIcon(); applyVfxVolume(_vfxVideo); if (document.activeElement !== slider) slider.value = String(Math.round(_sfxVolume * 100)); };
    icon.addEventListener("click", (e) => { e.preventDefault(); _sfxMuted = !_sfxMuted; saveSfxPrefs(); sync(); if (!_sfxMuted) SFX.play("click"); });
    slider.addEventListener("input", () => { _sfxVolume = Math.max(0, Math.min(1, (Number(slider.value) || 0) / 100)); if (_sfxVolume > 0 && _sfxMuted) _sfxMuted = false; saveSfxPrefs(); sync(); });
    slider.addEventListener("change", () => SFX.play("hover"));   // preview a click at the new level on release
    return { icon, slider, sync };
  }
  function volumeBubble() {   // in-battle: bottom-left bubble near the Surrender button
    const c = buildVolControl();
    return el("div", { class: "vol-bubble vol-ctl", title: "Audio volume" }, [c.icon, c.slider]);
  }
  function settingsVolume() {   // Settings menu: a labelled row with the same control + a % readout
    const c = buildVolControl();
    const pct = el("span", { class: "set-val" }, [Math.round(_sfxVolume * 100) + "%"]);
    const upd = () => { pct.textContent = Math.round(_sfxVolume * 100) + "%"; };
    c.slider.addEventListener("input", upd);
    c.icon.addEventListener("click", upd);
    return el("div", { class: "set-row" }, [el("div", { class: "set-label" }, ["Volume"]), el("div", { class: "set-control vol-ctl" }, [c.icon, c.slider, pct])]);
  }

  // Run at the end of every render(): create/remove the body-level admin FAB for the current
  // admin + screen state, and drop the panel when admin status is lost. Server is authoritative.
  function syncAdminUI() {
    const show = S.isAdmin === true && S.screen !== "login";
    if (!show) {
      if (_adminFab) { _adminFab.remove(); _adminFab = null; }
      closeAdminPanel();
      return;
    }
    if (_adminFab) return;   // already present
    _adminFab = el("button", { class: "admin-fab", title: "Admin tools", onclick: openAdminPanel }, ["📢"]);
    document.body.appendChild(_adminFab);
  }

  // Viewer mode: true when watching a replay/spectating instead of playing. NO-OP today (S.viewer is
  // always null); the seam lets later phases flip it to make the battle screen read-only.
  function isViewer() { return !!S.viewer; }

  // ---- Phase 2 chat dock (body-level; survives render()'s #app teardown — the point of P0.6) -------
  // A collapsed 💬 pill in a screen corner that expands into a tabbed panel (Global / Match / DMs).
  // Buffers are client-side RAM rings fed by "chat_message"; the server is authoritative for
  // membership, muting, the global kill switch and ignore-filtering — the client renders what arrives.
  const _chatHistReq = new Set();   // channel keys already asked history for ("global","match","dm:<peer>")
  function chatMe() { return (S.player && S.player.username) || S.username || ""; }
  function chatNorm() {   // guarantee every sub-field so a partial/empty S.chat can never throw a render
    const C = S.chat || (S.chat = {});
    C.global = C.global || []; C.match = C.match || []; C.dms = C.dms || {};
    C.unread = C.unread || { global: 0, match: 0, dms: {} }; C.unread.dms = C.unread.dms || {};
    if (C.tab == null) C.tab = "global";
    if (C.globalEnabled == null) C.globalEnabled = true;
    return C;
  }
  function chatTotalUnread() {   // collapsed-pill badge: global + dms always, match only while PLAYING a battle
    const u = chatNorm().unread;
    let n = (u.global || 0);
    if (S.screen === "battle" && !isViewer()) n += (u.match || 0);   // viewers aren't match-chat members (D6)
    for (const k in u.dms) n += (u.dms[k] || 0);
    return n;
  }
  function chatDmUnread() { const d = chatNorm().unread.dms; let n = 0; for (const k in d) n += (d[k] || 0); return n; }
  function chatClock(ts) {   // unix seconds -> HH:MM (chat-style timestamp; timeAgo() is the fuzzier cousin)
    if (!ts) return "";
    const d = new Date(ts * 1000);
    return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
  }
  function chatHistOnce(key, payload) { if (_chatHistReq.has(key)) return; _chatHistReq.add(key); S.net.send("chat_history", payload); }
  function openChatTab(tab) {
    const C = chatNorm();
    C.expanded = true; C.tab = tab;
    if (tab === "global") { C.unread.global = 0; chatHistOnce("global", { channel: "global" }); }               // global history: once, on first open
    else if (tab === "match") { C.unread.match = 0; if (S.screen === "battle") chatHistOnce("match", { channel: "match" }); }
    syncSocialUI();
  }
  function openChatDm(peer) {
    if (!peer) return;
    const C = chatNorm();
    C.expanded = true; C.tab = "dms"; C.dm = peer;
    if (!C.dms[peer]) C.dms[peer] = [];
    C.unread.dms[peer] = 0;
    chatHistOnce("dm:" + peer, { channel: "dm", to: peer });   // dm history: on opening the thread
    syncSocialUI();
  }
  function chatSend() {
    const C = chatNorm(), text = (S.chatInput || "").trim();
    if (!text) return;
    if (C.tab === "global") { if (!C.globalEnabled) return; S.net.send("chat_send", { channel: "global", text }); }
    else if (C.tab === "match") { if (S.screen !== "battle" || isViewer()) return; S.net.send("chat_send", { channel: "match", text }); }   // viewers aren't match-chat members (D6)
    else if (C.tab === "dms") { if (!C.dm) return; S.net.send("chat_send", { channel: "dm", text, to: C.dm }); }
    else return;
    S.chatInput = "";   // the echoed chat_message will render it; clear the buffer + repaint the (now empty) input
    syncSocialUI();
  }
  function chatMsgRow(msg) {
    return el("div", { class: "chat-msg" }, [
      el("span", { class: "chat-msg-from" }, [String((msg && msg.from) || "")]),
      el("span", { class: "chat-msg-text" }, [String((msg && msg.text) || "")]),   // ALWAYS a text node — never innerHTML with message text
      el("span", { class: "chat-msg-time" }, [chatClock(msg && msg.ts)]),
    ]);
  }
  // Close a DM thread (client-side only — a new message from that peer will recreate it).
  function closeChatDm(peer) {
    const C = chatNorm();
    delete C.dms[peer]; delete C.unread.dms[peer]; _chatHistReq.delete("dm:" + peer);
    if (C.dm === peer) { const rest = Object.keys(C.dms); C.dm = rest.length ? rest[0] : null; if (C.dm) chatHistOnce("dm:" + C.dm, { channel: "dm", to: C.dm }); }
    syncSocialUI();
  }
  // ===== Chat dock: built ONCE, reconciled IN PLACE. =====
  // The old version replaceWith()'d the ENTIRE dock on every message / tab change — that was the
  // flicker (the panel appeared to disappear + reappear). Now the panel, its section containers, and
  // the input element all PERSIST; each update mutates only what changed (append a message row, flip a
  // tab's .sel, toggle disabled) so nothing is torn out of the DOM and the caret is never lost.
  let _socialDock = null, _chatPill = null, _chatPanel = null;
  function buildChatPill() {
    const badge = el("span", { class: "chat-dock-badge" }, []);
    const pill = el("div", { class: "chat-dock", title: "Chat", onclick: () => {
      const C = chatNorm(); C.expanded = true;
      if (C.tab === "match" && !(S.screen === "battle" && !isViewer())) C.tab = "global";
      openChatTab(C.tab || "global");
    } }, ["💬", badge]);
    pill._badge = badge;
    return pill;
  }
  function updateChatPill(pill) {
    const total = chatTotalUnread();
    pill._badge.textContent = total > 0 ? String(total) : "";
    pill._badge.style.display = total > 0 ? "" : "none";
    // classList.toggle rather than rewriting className: the pill is reconciled in place
    // (never rebuilt), so clobbering the class list would drop .chat-dock itself.
    pill.classList.toggle("has-notify", total > 0);
  }
  function buildChatPanel() {
    const tabsEl = el("div", { class: "chat-tabs" });
    const dmTabsEl = el("div", { class: "chat-dmtabs" });
    const logEl = el("div", { class: "chat-log", "data-scrollkey": "chat-log" });
    const inputEl = el("input", { class: "chat-input", "data-focus-id": "chat-input", value: "",
      placeholder: "Message…", autocapitalize: "off", autocorrect: "off", spellcheck: "false",
      oninput: (e) => { S.chatInput = e.target.value; } });   // off-render buffer: never set()/render()
    inputEl.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); chatSend(); } });
    const sendBtn = el("button", { class: "chat-send", onclick: chatSend }, ["Send"]);
    const panel = el("div", { class: "chat-panel" }, [tabsEl, dmTabsEl, logEl, el("div", { class: "chat-input-row" }, [inputEl, sendBtn])]);
    panel._tabsEl = tabsEl; panel._dmTabsEl = dmTabsEl; panel._logEl = logEl; panel._inputEl = inputEl; panel._sendBtn = sendBtn;
    panel._view = null; panel._count = -1; panel._firstMsg = null;
    return panel;
  }
  function updateChatPanel(panel) {
    const C = chatNorm();
    const inBattle = S.screen === "battle" && !isViewer();   // viewers aren't match-chat members (D6)
    let tab = C.tab;
    if (tab === "match" && !inBattle) { tab = "global"; if (C.tab === "match") C.tab = "global"; }
    // --- channel tabs: rebuild the tab buttons, but the .chat-tabs CONTAINER persists (no panel flicker) ---
    const mkTab = (key, label, unread) => el("div", { class: "chat-tab" + (tab === key ? " sel" : ""),
      onclick: () => { if (key === "dms") { C.expanded = true; C.tab = "dms"; syncSocialUI(); } else openChatTab(key); } },
      [label, unread > 0 ? el("span", { class: "chat-tab-badge" }, [String(unread)]) : null]);
    const chTabs = [mkTab("global", "Global", C.unread.global || 0)];
    if (inBattle) chTabs.push(mkTab("match", "Match", C.unread.match || 0));
    chTabs.push(mkTab("dms", "DMs", chatDmUnread()));
    chTabs.push(el("div", { class: "chat-tab chat-tab-min", title: "Minimize", onclick: () => { C.expanded = false; syncSocialUI(); } }, ["✕"]));
    panel._tabsEl.replaceChildren(...chTabs);
    // --- pick the active view + its messages ---
    let view, msgs, emptyText, disabled = false;
    if (tab === "dms") {
      const peers = Object.keys(C.dms);
      if (peers.length && (!C.dm || !C.dms[C.dm])) C.dm = peers[0];   // auto-select a thread
      // horizontal, scrollable DM thread tabs — each independently closeable
      panel._dmTabsEl.style.display = peers.length ? "" : "none";
      panel._dmTabsEl.replaceChildren(...peers.map((p) => el("div", { class: "chat-dmtab" + (C.dm === p ? " sel" : "") }, [
        el("span", { class: "chat-dmtab-name", title: p, onclick: () => openChatDm(p) }, [p]),
        (C.unread.dms[p] || 0) > 0 ? el("span", { class: "chat-tab-badge", onclick: () => openChatDm(p) }, [String(C.unread.dms[p])]) : null,
        el("span", { class: "chat-dmtab-x", title: "Close conversation", onclick: (e) => { e.stopPropagation(); closeChatDm(p); } }, ["×"]),
      ])));
      view = "dm:" + (C.dm || "");
      msgs = C.dm ? C.dms[C.dm] : [];
      emptyText = peers.length ? "No messages yet — say hi." : "No conversations yet — Message a friend from the Social panel.";
    } else {
      panel._dmTabsEl.style.display = "none";
      panel._dmTabsEl.replaceChildren();
      view = tab; msgs = (tab === "match") ? C.match : C.global; emptyText = "No messages yet.";
      disabled = (tab === "global" && !C.globalEnabled);
    }
    // --- message log: if the view is unchanged and only GREW AT THE TAIL, append (no flicker); else replace ---
    const logEl = panel._logEl;
    const wasAtBottom = logEl.scrollHeight - logEl.scrollTop - logEl.clientHeight < 48;
    const viewChanged = view !== panel._view;
    const count = (msgs && msgs.length) || 0;
    // The fast-path is only valid when the already-rendered head is unchanged. Channels are capped at
    // 100 messages via a FRONT shift() (see chat_message handler), so at the cap a new message keeps
    // count==100 while the oldest row is dropped — appending [count..count) would render nothing and
    // leave the stale head in place. Gate on the first message's identity: if msgs[0] is the same node
    // we rendered last time, the head is intact and appending the tail is safe; otherwise rebuild.
    const headIntact = count > 0 && panel._firstMsg === msgs[0];
    if (!viewChanged && headIntact && count === panel._count) {
      // Nothing about this view changed (syncSocialUI runs after EVERY render() — friend pings, battle
      // snapshots — so this is the common case). Leave the log DOM untouched: no O(n) rebuild, and an
      // in-progress text selection in the log survives. This is what makes the panel truly static.
    } else if (!viewChanged && headIntact && count > panel._count && panel._count >= 0) {
      for (let i = panel._count; i < count; i++) logEl.appendChild(chatMsgRow(msgs[i]));   // tail grew: append only
    } else {
      logEl.replaceChildren(...(count ? msgs.map(chatMsgRow) : [el("div", { class: "chat-empty" }, [emptyText])]));   // head changed / view switch / trim
    }
    panel._view = view; panel._count = count; panel._firstMsg = count ? msgs[0] : null;
    // --- input (element persists): only toggle disabled/placeholder and sync the value ---
    panel._inputEl.disabled = !!disabled;
    panel._sendBtn.disabled = !!disabled;
    panel._inputEl.placeholder = disabled ? "Global chat is disabled" : "Message…";
    const desired = S.chatInput || "";   // set on send-clear (even if focused) or when not typing; never clobber active typing
    if (panel._inputEl.value !== desired && (document.activeElement !== panel._inputEl || desired === "")) panel._inputEl.value = desired;
    if (viewChanged || wasAtBottom) logEl.scrollTop = logEl.scrollHeight;   // pin to bottom, but don't yank a user reading history
  }
  function syncSocialUI() {
    const show = S.socialDockEnabled && S.screen !== "login";
    if (!show) { if (_socialDock) { _socialDock.remove(); _socialDock = null; } return; }
    const C = chatNorm();
    const want = C.expanded ? (_chatPanel || (_chatPanel = buildChatPanel())) : (_chatPill || (_chatPill = buildChatPill()));
    let justMountedPanel = false;
    if (_socialDock !== want) {   // only the pill<->panel (expand/collapse) transition remounts — user-initiated, fine
      if (_socialDock) _socialDock.remove();
      document.body.appendChild(want); _socialDock = want;
      justMountedPanel = (want === _chatPanel);   // opening from the pill: force the log to the bottom below
    }
    if (want === _chatPill) { updateChatPill(want); return; }
    updateChatPanel(want);
    // Re-appending the panel resets logEl.scrollTop to 0, so updateChatPanel's wasAtBottom read is stale
    // (it sees the top) and won't pin. On a fresh open, always land on the newest messages (the bottom).
    if (justMountedPanel) want._logEl.scrollTop = want._logEl.scrollHeight;
  }

  function render() {
    const root = $("#app");
    GK.onRerender();         // dismiss unpinned hover popovers (their anchors are about to be rebuilt); pinned ones float on
    // Capture scroll positions before teardown; restored at the end once the new tree is attached.
    const savedScroll = {};
    document.querySelectorAll("#app *").forEach((elm) => {
      if (elm.classList.contains("log")) return;   // the battle log pins itself to the bottom (see log())
      if (elm.scrollLeft || elm.scrollTop) savedScroll[scrollKey(elm)] = [elm.scrollLeft, elm.scrollTop];
    });
    // Capture focus + caret of a data-focus-id'd text input so a live re-render (e.g. a clan_state
    // push arriving while you're typing an invite/search) doesn't drop the cursor + in-flight key.
    let savedFocus = null;
    const _ae = document.activeElement;
    if (_ae && _ae.dataset && _ae.dataset.focusId && root.contains(_ae)) {
      try { savedFocus = { id: _ae.dataset.focusId, start: _ae.selectionStart, end: _ae.selectionEnd }; } catch (e) {}
    }
    root.innerHTML = "";
    if (document.body) {  // wide desktop layout for battle + char-select
      document.body.classList.toggle("battle-mode", S.screen === "battle");
      document.body.classList.toggle("menu-mode", S.screen === "menu");
      document.body.classList.toggle("draft-mode", S.screen === "draft");
      document.body.classList.toggle("campaign-mode", S.screen === "campaign");
    }
    const scr = S.screen === "login" ? loginScreen() : S.screen === "menu" ? menuScreen() : S.screen === "draft" ? draftScreen() : S.screen === "campaign" ? campaignScreen() : battleScreen();
    root.appendChild(scr);
    // Kick the HP bars from their rendered (previous) width to the new target so the
    // CSS width-transition animates instead of snapping. Forcing a reflow (offsetWidth)
    // between the two widths registers the start value — more reliable than rAF, which
    // is throttled when the tab isn't actively rendering.
    root.querySelectorAll('.hp > i[data-target-w]').forEach((b) => { void b.offsetWidth; b.style.width = b.dataset.targetW; });
    if (S.reconnecting) root.appendChild(
      el("div", { class: "overlay" }, [
        el("div", { class: "overlay-card" }, [
          el("div", { class: "spinner" }),
          el("div", { class: "ov-title" }, ["Reconnecting…"]),
          el("div", { class: "note" }, ["Resuming your match — keep this tab open"]),
        ]),
      ]));
    if (S.screen === "menu" && S.menuOverlay) root.appendChild(menuModal());
    if (S.screen === "menu" && S.avatarEdit) root.appendChild(avatarModal());
    if (S.screen === "menu" && S.privatePrompt) root.appendChild(privateModal());
    if (S.screen === "menu" && S.disguisePicker) root.appendChild(disguiseModal());
    if (S.screen === "menu" && S.jinwooPicker) root.appendChild(jinwooFormModal());
    if (S.screen === "campaign" && S.campaignLoadout) root.appendChild(campaignLoadoutModal());
    if (S.screen === "battle" && S.randomModal) root.appendChild(randomAllocModal());
    if (S.screen === "battle" && S.exchangeSetup) root.appendChild(exchangeModal());
    if (S.catView != null) root.appendChild(categoryModal());   // bounty-category browser (stacks over the bounty menu)
    if (S.bountyBuy != null) root.appendChild(bountyBuyModal());   // "complete this square for AP" confirm
    if (S.glossaryOpen) root.appendChild(glossaryModal());   // term reference — no screen gate (char-select AND in-battle)
    // Restore scroll now that the new tree (incl. modals) is attached + laid out.
    root.querySelectorAll("*").forEach((elm) => {
      const k = scrollKey(elm), v = savedScroll[k];
      if (v) { if (v[0]) elm.scrollLeft = v[0]; if (v[1]) elm.scrollTop = v[1]; delete savedScroll[k]; }
    });
    if (savedFocus) {   // put the caret back into the same input after the rebuild
      const esc = (window.CSS && CSS.escape) ? CSS.escape(savedFocus.id) : savedFocus.id;
      const fn = root.querySelector('[data-focus-id="' + esc + '"]');
      if (fn) { fn.focus(); try { if (savedFocus.start != null) fn.setSelectionRange(savedFocus.start, savedFocus.end); } catch (e) {} }
    }
    fitBattleViewport();   // phones: measure the just-built board and zoom it to fit the whole screen
    syncAdminUI();         // create/remove the admin FAB for the current admin+screen state
    syncSocialUI();        // create/remove the body-level social dock scaffold (off until P1)
    if (S.screen === "draft" && S.draftSearch) applyDraftFilter(S.draftSearch);   // re-apply the pool search after a rebuild
  }

  // ---- top-menu overlays (Mastery / Cosmetics) -----------------------------
  const MENU_TITLES = { profile: "Profile", mastery: "Mastery", cosmetics: "Cosmetics", nexus: "Nexus", titles: "Titles", settings: "Settings", ladder: "Ladder", bounties: "Bounties", shop: "Shop", clan: "Clan", social: "Social" };
  const MENU_RENDERERS = { profile: () => profileMenu(), mastery: () => masteryMenu(), cosmetics: () => cosmeticsMenu(), nexus: () => nexusMenu(), titles: () => titleMenu(), settings: () => settingsMenu(), ladder: () => ladderMenu(), bounties: () => bountiesMenu(), shop: () => shopMenu(), clan: () => clanMenu(), social: () => socialMenu() };
  // Contextual "?" help — a short, new-player explanation of each panel's purpose. One entry
  // per menu overlay; each value is an array of paragraphs shown in the help card.
  const HELP_TEXT = {
    mastery: [
      "Mastery tracks how much you've played each character. Every Quick or Ladder match a character fights in earns them Mastery XP — more for a win, less for a loss — which levels them up.",
      "Hitting a character's mastery milestones unlocks their personal cosmetics (player cards, game panels, hats and more) to equip in the Cosmetics panel. It's a record of your dedication to each fighter.",
    ],
    cosmetics: [
      "Cosmetics personalize your fighters. Pick a tab to browse Player Cards, in-battle Game Panels, Hats, Elite Panels, or Backgrounds, then tap an unlocked item to equip it.",
      "Most cosmetics are earned by leveling a character's Mastery; Backgrounds are bought in the Shop. Panels and hats are equipped per team slot (Char 1 / 2 / 3).",
    ],
    nexus: [
      "The Nexus is a community effort. Every character has a shared bucket that all players fill by donating AP, grouped by universe. The Leaderboard shows which characters the community is rallying behind.",
      "Pick a universe to see its characters, then donate your AP to the ones you want to champion. Donations open and close in rounds.",
    ],
    bounties: [
      "Each bounty is a 5×5 grid of missions tied to one character. Win matches that satisfy a square's requirement — like winning with that character or a certain archetype — to fill that square in.",
      "You only need to complete a single line to finish a bounty and claim its AP reward — any one full row, column, or diagonal. You do NOT have to fill the whole grid.",
      "You can also spend AP to instantly finish an individual mission; the cost scales with how many wins that mission still needs. You can hold a few bounties at once, and reroll or cancel ones you don't want (rerolling costs AP).",
    ],
    titles: [
      "Titles are a custom label shown next to your name. Build one from words you've unlocked — choose and arrange them to create your own.",
      "Unlock more title words through play, then save your combination here.",
    ],
    shop: [
      "The Shop is where you spend AP. Buy new playable characters to unlock them for your team, or cosmetic items like Backgrounds.",
      "Items you already own are marked as owned. Earn more AP from matches and bounties.",
    ],
    ladder: [
      "The Ladder is the competitive leaderboard. It ranks players by their Ladder rating so you can see where you stand and who's at the top.",
    ],
    settings: [
      "Settings let you tune your experience — toggle animations, whether enemy cosmetics are shown, and bot/queue timing, among others.",
      "You can also change your account password here.",
    ],
    clan: [
      "Clans are teams of players. Create one (you become its leader), or join an existing one — either by accepting an invite or by finding a clan and requesting to join.",
      "As a leader you can invite players by username, approve or deny join requests, kick members, and disband the clan. Members can leave anytime. Your clan racks up wins and losses from Ladder matches between two different clans.",
    ],
    social: [
      "Add friends by username to see when they're online, view their profile, or send them a private challenge. Friend requests are mutual — the other player has to accept before you're friends.",
      "Ignore is one-way: add a player to your ignore list and you won't hear from them. Manage your incoming and outgoing requests, your friends, and your ignore list here.",
    ],
  };
  // Full-panel help card overlaying the current menu overlay. Dismiss via ✕, the scrim, or the "?".
  function menuHelpCard() {
    const key = S.menuOverlay, paras = HELP_TEXT[key];
    if (!paras) return null;
    return el("div", { class: "help-overlay", onclick: (e) => { if (e.target.classList.contains("help-overlay")) set({ menuHelp: null }); } }, [
      el("div", { class: "help-card" }, [
        el("div", { class: "help-card-head" }, [
          el("div", { class: "help-card-title" }, ["❔ About " + (MENU_TITLES[key] || "this panel")]),
          el("button", { class: "help-card-x", title: "Close help", onclick: () => set({ menuHelp: null }) }, ["✕"]),
        ]),
        el("div", { class: "help-card-body" }, paras.map((p) => el("p", { class: "help-p" }, [p]))),
      ]),
    ]);
  }
  // ---- Clan panel ----------------------------------------------------------
  // Server-authoritative: the client sends clan_* actions and the server validates,
  // then pushes back clan_state (panel) + receive_player_update (clan badge) + a
  // clan_result toast. So actions never optimistically mutate — they just send.
  let _clanDisbandArm = false;   // two-tap guard for the destructive Disband action
  let _clanResetRecordArm = false;   // two-tap guard for the leader's Reset Clan Record action
  function clanAction(type, extra) { S.net.send(type, extra || {}); }
  function clanAvatar(url, cls) {
    return url ? el("img", { class: cls, src: url, alt: "", loading: "lazy", onerror: (e) => e.target.replaceWith(el("div", { class: cls + " clan-av-none" }, [])) })
      : el("div", { class: cls + " clan-av-none" }, []);
  }
  // Member avatars fall back to the app's default avatar (toko_toda) when unset — matching the
  // profile/info-card avatars. Only clan banners (which are optional) get the blank placeholder.
  function clanMemberAvatar(url, cls) {
    return el("img", { class: cls, src: avatarSrc(url), alt: "", loading: "lazy", onerror: (e) => e.target.replaceWith(el("div", { class: cls + " clan-av-none" }, [])) });
  }
  function clanWL(w, l) { return "W " + (w || 0) + " / L " + (l || 0); }

  function clanMyView(clan) {
    const isLeader = clan.my_role === "Leader";
    const isOfficer = clan.my_role === "Officer";
    const canManage = isLeader || isOfficer;   // leader OR officer: invite / accept / remove members
    // Win-derived level progress (server sends level_progress = wins into this level, level_needed =
    // wins this level costs). Older servers omit them → hide the bar rather than render a broken one.
    const into = clan.level_progress, needed = clan.level_needed;
    const hasXp = Number.isFinite(into) && Number.isFinite(needed) && needed > 0;
    const pct = hasXp ? Math.min(100, Math.round((into / needed) * 100)) : 0;
    const kids = [
      el("div", { class: "clan-head" }, [
        clanAvatar(clan.banner_url, "clan-banner"),
        el("div", { class: "clan-head-info" }, [
          el("div", { class: "clan-name" }, [clan.name]),
          el("div", { class: "clan-sub" }, ["Level " + clan.level + " · " + clan.member_count + " member" + (clan.member_count === 1 ? "" : "s") + " · " + clanWL(clan.wins, clan.losses)]),
          hasXp ? el("div", { class: "clan-xp", title: into + " / " + needed + " clan wins toward Level " + (clan.level + 1) }, [
            el("div", { class: "clan-xp-track" }, [el("div", { class: "clan-xp-fill", style: "width:" + pct + "%" }, [])]),
            el("div", { class: "clan-xp-label" }, [
              el("span", { class: "clan-xp-lv" }, ["Lv " + clan.level]),
              el("span", { class: "clan-xp-count" }, [into + " / " + needed + " wins → Lv " + (clan.level + 1)]),
            ]),
          ]) : null,
          el("div", { class: "clan-role" }, ["Your role: " + clan.my_role]),
        ]),
      ]),
      el("div", { class: "clan-sec" }, ["Members (" + clan.member_count + ")"]),
      el("div", { class: "clan-list" }, (clan.members || []).map((m) => {
        const row = [
          clanMemberAvatar(m.avatar_url, "clan-av"),
          el("span", { class: "clan-mname" }, [m.username]),
          el("span", { class: "clan-mrole" + (m.role === "Leader" ? " lead" : (m.role === "Officer" ? " officer" : "")) }, [m.role]),
          el("span", { class: "clan-mwl" }, [clanWL(m.wins, m.losses)]),
        ];
        // Leader: promote members ↔ demote officers, and kick anyone below them. Officer: kick regular members only.
        if (isLeader && m.role === "Member") row.push(el("button", { class: "clan-btn sm", onclick: () => clanAction("clan_promote", { username: m.username }) }, ["Promote"]));
        if (isLeader && m.role === "Officer") row.push(el("button", { class: "clan-btn sm", onclick: () => clanAction("clan_demote", { username: m.username }) }, ["Demote"]));
        if (m.role !== "Leader" && (isLeader || (isOfficer && m.role === "Member"))) row.push(el("button", { class: "clan-btn danger sm", onclick: () => clanAction("clan_kick", { username: m.username }) }, ["Kick"]));
        return el("div", { class: "clan-row" }, row);
      })),
    ];
    if (canManage) {
      // Invite + join-request management — available to the leader AND officers.
      const inviteIn = el("input", { class: "clan-input", "data-focus-id": "clan-invite", placeholder: "Invite a player by username", value: S.clanInviteName, autocapitalize: "off", autocorrect: "off", spellcheck: "false", oninput: (e) => { S.clanInviteName = e.target.value; } });
      const doInvite = () => { const u = (S.clanInviteName || "").trim(); if (!u) return set({ msg: "Enter a username to invite", msgKind: "err" }); clanAction("clan_invite", { username: u }); S.clanInviteName = ""; };
      inviteIn.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); doInvite(); } });
      kids.push(el("div", { class: "clan-sec" }, ["Invite a Player"]));
      kids.push(el("div", { class: "clan-inline" }, [inviteIn, el("button", { class: "clan-btn primary", onclick: doInvite }, ["Invite"])]));
      if ((clan.invites || []).length) {
        kids.push(el("div", { class: "clan-sec" }, ["Pending Invites"]));
        kids.push(el("div", { class: "clan-list" }, clan.invites.map((m) => el("div", { class: "clan-row" }, [
          clanMemberAvatar(m.avatar_url, "clan-av"), el("span", { class: "clan-mname" }, [m.username]),
          el("button", { class: "clan-btn sm", onclick: () => clanAction("clan_cancel_invite", { username: m.username }) }, ["Cancel"]),
        ]))));
      }
      kids.push(el("div", { class: "clan-sec" }, ["Join Requests" + ((clan.applications || []).length ? " (" + clan.applications.length + ")" : "")]));
      if ((clan.applications || []).length) {
        kids.push(el("div", { class: "clan-list" }, clan.applications.map((m) => el("div", { class: "clan-row" }, [
          clanMemberAvatar(m.avatar_url, "clan-av"), el("span", { class: "clan-mname" }, [m.username]), el("span", { class: "clan-mwl" }, [clanWL(m.wins, m.losses)]),
          el("button", { class: "clan-btn primary sm", onclick: () => clanAction("clan_approve_application", { username: m.username }) }, ["Accept"]),
          el("button", { class: "clan-btn sm", onclick: () => clanAction("clan_deny_application", { username: m.username }) }, ["Deny"]),
        ]))));
      } else {
        kids.push(el("div", { class: "clan-empty" }, ["No pending join requests."]));
      }
    }
    if (isLeader) {
      // Leader-only: change the clan's profile picture (banner). Empty field + Update is rejected;
      // the separate Remove button clears it back to the blank placeholder. Off-render buffer +
      // data-focus-id so a live clan_state re-render doesn't drop the caret.
      const bannerEditIn = el("input", { class: "clan-input", "data-focus-id": "clan-banner-edit", placeholder: "New banner image URL (https://…)", value: S.clanBannerEdit, autocapitalize: "off", autocorrect: "off", spellcheck: "false", oninput: (e) => { S.clanBannerEdit = e.target.value; } });
      const doSetBanner = () => {
        const u = (S.clanBannerEdit || "").trim();
        if (!u) return set({ msg: "Paste an image URL to set the clan picture", msgKind: "err" });
        if (!/^https?:\/\//i.test(u)) return set({ msg: "Enter a full image URL starting with http:// or https:// — use Remove to clear the picture", msgKind: "err" });
        clanAction("clan_set_banner", { banner_url: u }); S.clanBannerEdit = "";
      };
      bannerEditIn.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); doSetBanner(); } });
      kids.push(el("div", { class: "clan-sec" }, ["Clan Picture"]));
      const bannerRow = [bannerEditIn, el("button", { class: "clan-btn primary", onclick: doSetBanner }, ["Update"])];
      if (clan.banner_url) bannerRow.push(el("button", { class: "clan-btn", onclick: () => clanAction("clan_set_banner", { banner_url: "" }) }, ["Remove"]));
      kids.push(el("div", { class: "clan-inline" }, bannerRow));
      kids.push(el("div", { class: "clan-end" }, [
        el("button", { class: "clan-btn danger", onclick: () => {
          if (_clanResetRecordArm) { _clanResetRecordArm = false; clanAction("clan_reset_record", {}); }
          else { _clanResetRecordArm = true; set({ msg: "Tap Reset again to confirm — this zeroes the clan's W/L record", msgKind: "err" }); }
        } }, [_clanResetRecordArm ? "Confirm Reset?" : "Reset Clan Record"]),
        el("button", { class: "clan-btn danger", onclick: () => {
          if (_clanDisbandArm) { _clanDisbandArm = false; clanAction("clan_disband", {}); }
          else { _clanDisbandArm = true; set({ msg: "Tap Disband again to confirm — this can't be undone", msgKind: "err" }); }
        } }, [_clanDisbandArm ? "Confirm Disband?" : "Disband Clan"]),
      ]));
    } else {
      kids.push(el("div", { class: "clan-end" }, [el("button", { class: "clan-btn danger", onclick: () => clanAction("clan_leave", {}) }, ["Leave Clan"])]));
    }
    return el("div", { class: "clan-menu" }, kids);
  }

  function clanBrowseView(cs) {
    const kids = [];
    kids.push(el("div", { class: "clan-sec" }, ["Create a Clan"]));
    const nameIn = el("input", { class: "clan-input", "data-focus-id": "clan-create-name", placeholder: "Clan name (3–24 chars)", maxlength: "24", value: S.clanCreateName, oninput: (e) => { S.clanCreateName = e.target.value; } });
    const bannerIn = el("input", { class: "clan-input", "data-focus-id": "clan-create-banner", placeholder: "Banner image URL (optional)", value: S.clanCreateBanner, autocapitalize: "off", autocorrect: "off", spellcheck: "false", oninput: (e) => { S.clanCreateBanner = e.target.value; } });
    const doCreate = () => { const n = (S.clanCreateName || "").trim(); if (!n) return set({ msg: "Enter a clan name", msgKind: "err" }); clanAction("create_clan", { name: n, banner_url: (S.clanCreateBanner || "").trim() }); };
    kids.push(el("div", { class: "clan-create" }, [nameIn, bannerIn, el("button", { class: "clan-btn primary", onclick: doCreate }, ["Create Clan"])]));

    const invs = (cs && cs.invitations) || [];
    if (invs.length) {
      kids.push(el("div", { class: "clan-sec" }, ["Your Invitations"]));
      kids.push(el("div", { class: "clan-list" }, invs.map((c) => el("div", { class: "clan-row" }, [
        clanAvatar(c.banner_url, "clan-av"), el("span", { class: "clan-mname" }, [c.clan_name]), el("span", { class: "clan-mwl" }, ["Lv " + c.level + " · " + c.members + "m"]),
        el("button", { class: "clan-btn primary sm", onclick: () => clanAction("clan_accept_invite", { clan_name: c.clan_name }) }, ["Accept"]),
        el("button", { class: "clan-btn sm", onclick: () => clanAction("clan_decline_invite", { clan_name: c.clan_name }) }, ["Decline"]),
      ]))));
    }
    const apps = (cs && cs.applications) || [];
    if (apps.length) {
      kids.push(el("div", { class: "clan-sec" }, ["Your Join Requests"]));
      kids.push(el("div", { class: "clan-list" }, apps.map((c) => el("div", { class: "clan-row" }, [
        clanAvatar(c.banner_url, "clan-av"), el("span", { class: "clan-mname" }, [c.clan_name]), el("span", { class: "clan-mwl" }, ["Lv " + c.level + " · " + c.members + "m"]),
        el("span", { class: "clan-pending" }, ["Pending"]),
        el("button", { class: "clan-btn sm", onclick: () => clanAction("clan_cancel_application", { clan_name: c.clan_name }) }, ["Cancel"]),
      ]))));
    }
    kids.push(el("div", { class: "clan-sec" }, ["Find a Clan"]));
    const searchIn = el("input", { class: "clan-input", "data-focus-id": "clan-search", placeholder: "Search clans by name…", value: S.clanSearchQuery, autocapitalize: "off", spellcheck: "false", oninput: (e) => { S.clanSearchQuery = e.target.value; } });
    const doSearch = () => S.net.send("clan_search", { query: (S.clanSearchQuery || "").trim() });
    searchIn.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); doSearch(); } });
    kids.push(el("div", { class: "clan-inline" }, [searchIn, el("button", { class: "clan-btn", onclick: doSearch }, ["Search"])]));
    const results = S.clanSearchResults;
    if (results != null) {
      kids.push(results.length
        ? el("div", { class: "clan-list" }, results.map((c) => el("div", { class: "clan-row" }, [
            clanAvatar(c.banner_url, "clan-av"), el("span", { class: "clan-mname" }, [c.clan_name]),
            el("span", { class: "clan-mwl" }, ["Lv " + c.level + " · " + c.members + "m · " + clanWL(c.wins, c.losses)]),
            el("button", { class: "clan-btn primary sm", onclick: () => clanAction("clan_apply", { clan_name: c.clan_name }) }, ["Request to Join"]),
          ])))
        : el("div", { class: "clan-empty" }, ["No clans found."]));
    }
    return el("div", { class: "clan-menu" }, kids);
  }

  function clanMenu() {
    const p = S.player || {};
    const cs = S.clan;
    if (cs && cs.clan) return clanMyView(cs.clan);
    // In a clan per the player record but detail not fetched yet → brief loader (avoid flashing the create form).
    if (p.clan && p.clan !== "Clanless" && (!cs || !cs.clan)) return el("div", { class: "clan-menu" }, [el("div", { class: "clan-empty" }, ["Loading " + p.clan + "…"])]);
    return clanBrowseView(cs);
  }

  // ---- Social panel --------------------------------------------------------
  // Server-authoritative, exactly like the clan panel: the client sends friend_*/ignore_*
  // actions and the server validates, then pushes back a FULL social_state snapshot + a
  // social_result toast. Actions never optimistically mutate S.social — the panel only ever
  // repaints from the pushed snapshot (the sole exception is the friend_presence handler,
  // which patches a single status the server just told us, to avoid a needless refetch).
  // Reuses the clan-* CSS classes so the panel is styled without new CSS.
  let _socialRemoveArm = {};   // per-username two-tap guard for the destructive Remove-friend action
  function socialAction(type, extra) { S.net.send(type, extra || {}); }
  // Open the Profile overlay focused on a given player (no dedicated openProfile existed; this
  // mirrors openMenuOverlay's "profile" branch but seeds the search box with the target username).
  function openProfile(username) {
    const u = (username || "").trim();
    if (!u) return;
    S.profileQuery = u; _profileResetArm = false;
    S.net.send("get_player_profile", { username: u });
    set({ menuOverlay: "profile", menuHelp: null, msg: "" });
  }
  function socialMenu() {
    const soc = S.social;
    if (!soc) return el("div", { class: "clan-menu" }, [el("div", { class: "clan-empty" }, ["Loading…"])]);   // loading guard — never throw on null S.social
    // Prune stale two-tap arms every repaint: if a username left the friends list (removed elsewhere,
    // or its row moved), disarm it so a re-added row never renders pre-armed and one click unfriends.
    const _friendSet = new Set((soc.friends || []).map((f) => f.username));
    for (const k in _socialRemoveArm) if (!_friendSet.has(k)) delete _socialRemoveArm[k];
    const kids = [];

    // --- Friend requests: incoming (accept/decline) + outgoing (cancel) ---
    const rin = soc.requests_in || [], rout = soc.requests_out || [];
    kids.push(el("div", { class: "clan-sec" }, ["Friend Requests" + (rin.length ? " (" + rin.length + ")" : "")]));
    if (rin.length) {
      kids.push(el("div", { class: "clan-list" }, rin.map((u) => el("div", { class: "clan-row" }, [
        el("span", { class: "clan-mname" }, [u]),
        el("button", { class: "clan-btn primary sm", onclick: () => socialAction("friend_accept", { username: u }) }, ["Accept"]),
        el("button", { class: "clan-btn sm", onclick: () => socialAction("friend_decline", { username: u }) }, ["Decline"]),
      ]))));
    } else {
      kids.push(el("div", { class: "clan-empty" }, ["No incoming requests."]));
    }
    if (rout.length) {
      kids.push(el("div", { class: "clan-sec" }, ["Sent Requests"]));
      kids.push(el("div", { class: "clan-list" }, rout.map((u) => el("div", { class: "clan-row" }, [
        el("span", { class: "clan-mname" }, [u]),
        el("span", { class: "clan-pending" }, ["Pending"]),
        el("button", { class: "clan-btn sm", onclick: () => socialAction("friend_cancel", { username: u }) }, ["Cancel"]),
      ]))));
    }

    // --- Add a friend (off-render buffer + caret-preserving data-focus-id) ---
    const addIn = el("input", { class: "clan-input", "data-focus-id": "social-add", placeholder: "Add a friend by username", value: S.socialAddName, autocapitalize: "off", autocorrect: "off", spellcheck: "false", oninput: (e) => { S.socialAddName = e.target.value; } });
    const doAdd = () => { const u = (S.socialAddName || "").trim(); if (!u) return set({ msg: "Enter a username to add", msgKind: "err" }); socialAction("friend_request", { username: u }); S.socialAddName = ""; };
    addIn.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); doAdd(); } });
    kids.push(el("div", { class: "clan-sec" }, ["Add a Friend"]));
    kids.push(el("div", { class: "clan-inline" }, [addIn, el("button", { class: "clan-btn primary", onclick: doAdd }, ["Add"])]));

    // --- Friends: presence pill + Profile / Challenge / (two-tap) Remove ---
    const friends = soc.friends || [];
    kids.push(el("div", { class: "clan-sec" }, ["Friends (" + friends.length + ")"]));
    if (friends.length) {
      kids.push(el("div", { class: "clan-list" }, friends.map((f) => {
        const u = f.username, armed = !!_socialRemoveArm[u];
        // Two committed rows: the name+presence on its own line, the action buttons wrapping below —
        // so no number of options can ever crowd the username off the row (esp. the extra "Watch" in-match).
        return el("div", { class: "clan-row social-frow" }, [
          el("div", { class: "social-frow-head" }, [statusBadge(f.status), el("span", { class: "clan-mname" }, [u])]),
          el("div", { class: "social-frow-acts" }, [
            f.status === "in match" ? el("button", { class: "clan-btn sm", onclick: () => { S.net.send("spectate", { username: u }); showToast("Joining as spectator…", "info"); } }, ["Watch"]) : null,
            el("button", { class: "clan-btn sm", onclick: () => openProfile(u) }, ["Profile"]),
            el("button", { class: "clan-btn sm", onclick: () => { set({ menuOverlay: null, menuHelp: null }); openChatDm(u); } }, ["Message"]),
            el("button", { class: "clan-btn primary sm", onclick: () => { set({ menuOverlay: null, menuHelp: null }); queuePrivate(u); } }, ["Challenge"]),
            el("button", { class: "clan-btn danger sm", onclick: () => {
              if (_socialRemoveArm[u]) { delete _socialRemoveArm[u]; socialAction("friend_remove", { username: u }); }
              else { _socialRemoveArm[u] = true; set({ msg: "Tap Remove again to confirm — unfriend " + u, msgKind: "err" }); }
            } }, [armed ? "Confirm Remove?" : "Remove"]),
          ]),
        ]);
      })));
    } else {
      kids.push(el("div", { class: "clan-empty" }, ["No friends yet — add someone above."]));
    }

    // --- Ignored: one-way list; add-to-ignore + unignore ---
    const ignored = soc.ignored || [];
    kids.push(el("div", { class: "clan-sec" }, ["Ignored (" + ignored.length + ")"]));
    const ignIn = el("input", { class: "clan-input", "data-focus-id": "social-ignore", placeholder: "Ignore a player by username", value: S.socialIgnoreName, autocapitalize: "off", autocorrect: "off", spellcheck: "false", oninput: (e) => { S.socialIgnoreName = e.target.value; } });
    const doIgnore = () => { const u = (S.socialIgnoreName || "").trim(); if (!u) return set({ msg: "Enter a username to ignore", msgKind: "err" }); socialAction("ignore_add", { username: u }); S.socialIgnoreName = ""; };
    ignIn.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); doIgnore(); } });
    kids.push(el("div", { class: "clan-inline" }, [ignIn, el("button", { class: "clan-btn", onclick: doIgnore }, ["Ignore"])]));
    if (ignored.length) {
      kids.push(el("div", { class: "clan-list" }, ignored.map((u) => el("div", { class: "clan-row" }, [
        el("span", { class: "clan-mname" }, [u]),
        el("button", { class: "clan-btn sm", onclick: () => socialAction("ignore_remove", { username: u }) }, ["Unignore"]),
      ]))));
    } else {
      kids.push(el("div", { class: "clan-empty" }, ["You aren't ignoring anyone."]));
    }

    return el("div", { class: "clan-menu social-menu" }, kids);
  }

  function menuModal() {
    const key = S.menuOverlay;
    const title = MENU_TITLES[key] || "";
    const inner = (MENU_RENDERERS[key] || (() => el("div", {}, [])))();
    const helpOn = S.menuHelp === key && !!HELP_TEXT[key];   // key-scoped so switching panels auto-hides help
    return el("div", { class: "modal-overlay", onclick: (e) => { if (e.target.classList.contains("modal-overlay")) set({ menuOverlay: null, menuHelp: null }); } }, [
      el("div", { class: "modal-panel" }, [
        el("div", { class: "modal-head" }, [
          el("div", { class: "modal-title" }, [title]),
          el("div", { class: "modal-head-btns" }, [
            HELP_TEXT[key] ? el("button", { class: "modal-help" + (helpOn ? " on" : ""), title: "What is this panel?", onclick: () => set({ menuHelp: helpOn ? null : key }) }, ["?"]) : null,
            el("button", { class: "modal-close", onclick: () => set({ menuOverlay: null, menuHelp: null }) }, ["✕"]),
          ]),
        ]),
        inner,
        helpOn ? menuHelpCard() : null,
      ]),
    ]);
  }

  // Per-character mastery: a character grid (level badges) + a detail pane with the
  // level, an XP progress bar, and the 6-row reward track. Display-only from S.player.
  function masteryMenu() {
    if (!(S.roster || []).length) loadRoster();
    const sort = S.masterySort || "name";
    const mxp = (p) => ((S.player && S.player.mastery_xp) || {})[p] || 0;
    const roster = rosterByName();   // already a name-sorted, path-tiebroken COPY
    if (sort === "mastery") roster.sort((a, b) => (mxp(b.path_name) - mxp(a.path_name))
      || (a.name || "").localeCompare(b.name || "", undefined, { sensitivity: "base" }));
    const sel = S.masteryChar || (roster[0] && roster[0].path_name) || null;
    const sortRow = el("div", { class: "cos-note-row" }, [
      el("div", { class: "cos-note" }, ["Sort by character name, or by how far you've leveled their mastery."]),
      el("div", { class: "mastery-sort" }, [
        el("button", { class: "cos-filter" + (sort === "name" ? " on" : ""), onclick: () => set({ masterySort: "name" }) }, ["Name"]),
        el("button", { class: "cos-filter" + (sort === "mastery" ? " on" : ""), onclick: () => set({ masterySort: "mastery" }) }, ["Mastery"]),
      ]),
    ]);
    const grid = el("div", { class: "mastery-grid" }, roster.map((c) => {
      const thumb = portraitUrlFor(c.path_name);
      const kids = [];
      if (thumb) kids.push(el("img", { class: "mg-img", src: thumb, alt: "", onerror: (e) => e.target.remove() }));
      kids.push(el("div", { class: "mastery-badge" }, ["Lv " + masteryLevel(c.path_name)]));
      const tile = el("div", { class: "mg-cell mastery-cell" + (sel === c.path_name ? " sel" : ""), title: c.name }, kids);
      tile.addEventListener("click", () => set({ masteryChar: c.path_name }));
      return tile;
    }));
    return el("div", { class: "mastery-menu" }, [sortRow, grid, sel ? masteryDetail(sel) : el("div", { class: "note" }, ["Pick a character"])]);
  }
  function masteryDetail(path) {
    const c = (S.roster || []).find((r) => r.path_name === path);
    const xp = ((S.player && S.player.mastery_xp) || {})[path] || 0;
    const admin = !!S.isAdmin;
    const lvl = masteryLevel(path);   // 99 for admins (front-end override), else the real level
    const frac = admin ? 1 : levelProgressFraction(xp);
    const purl = portraitUrlFor(path);
    const headKids = [];
    if (purl) headKids.push(el("img", { class: "md-portrait", src: purl, alt: "", onerror: (e) => e.target.remove() }));
    headKids.push(el("div", {}, [
      el("div", { class: "md-name" }, [c ? c.name : titleCase(path)]),
      el("div", { class: "md-level" }, [admin ? "Level 99 (admin — all rewards unlocked)" : (lvl >= MAX_LEVEL ? "Level 100 (MAX) — " + xp + " XP total" : "Level " + lvl + " — " + xp + " XP total")]),
    ]));
    const rewards = MASTERY_REWARDS.map(([type, label, req]) => {
      const ok = admin || lvl >= req;
      return el("div", { class: "reward-row" + (ok ? " unlocked" : "") }, [
        el("span", { class: "rr-lvl" }, ["Lv " + req]),
        el("span", { class: "rr-label" }, [label]),
        el("span", { class: "rr-status" }, [ok ? "Unlocked" : "Level " + req]),
      ]);
    });
    return el("div", { class: "mastery-detail" }, [
      el("div", { class: "md-head" }, headKids),
      el("div", { class: "md-bar" }, [el("i", { style: "width:" + Math.round(frac * 100) + "%" })]),
      el("div", { class: "md-bar-label" }, [admin ? "Admin override — actual XP: " + xp : (lvl >= MAX_LEVEL ? xp + " XP (MAX)" : xpIntoLevel(xp) + " / " + xpNeededForLevel(xp) + " XP")]),
      el("div", { class: "md-rewards-label" }, ["Reward Track"]),
      el("div", { class: "md-rewards" }, rewards),
    ]);
  }

  // Cosmetics menu — the mastery→cosmetic link: per-character mastery cosmetics shown
  // unlocked (mastery level reached) or locked ("Mastery Lv N"); click an unlocked one
  // to equip (persisted via the save_cosmetics server bridge).
  const COS_TABS = [["playercard", "Player Cards"], ["action_frame", "Game Panels"], ["hat", "Hats"], ["elite_action_frame", "Elite Panels"], ["background", "Backgrounds"]];
  const COS_DIRS = { playercard: "playercards", action_frame: "game_panels", hat: "character_baubles", elite_action_frame: "game_panels" };
  // tile geometry per type — explicit w/h (from real asset aspect ratios) so banners show as
  // banners. Explicit height (not aspect-ratio) is required: aspect-ratio doesn't feed the grid's
  // row-track sizing, so rows would collapse and tiles overlap.
  const COS_TILE = { playercard: { w: 152, h: 37 }, action_frame: { w: 152, h: 44 }, hat: { w: 84, h: 84 }, elite_action_frame: { w: 152, h: 44 } };
  const COS_LABELS = { playercard: "Player Card", action_frame: "Game Panel", hat: "Hat", elite_action_frame: "Elite Panel" };
  function cosmeticUrl(dir, id) { return resToUrl("res://assets/cosmetics/" + dir + "/" + id + ".png"); }
  function isCosmeticEquipped(tab, id) {           // equipped in ANY slot (grid ✓ badge)
    const p = S.player || {};
    if (tab === "playercard") return p.player_card === id;
    if (tab === "hat") return (p.hats || []).includes(id);
    return (p.action_frames || []).includes(id);   // game panels + elite panels
  }
  function isCosmeticEquippedSlot(tab, id, slot) { // equipped in THIS specific slot
    const p = S.player || {};
    if (tab === "playercard") return p.player_card === id;
    if (tab === "hat") return (p.hats || [])[slot] === id;
    return (p.action_frames || [])[slot] === id;
  }
  // Panels/hats equip to a single team slot (0..2); player_card is one value for the player.
  function equipCosmetic(tab, id, slot) {
    const p = S.player; if (!p) return;
    slot = slot || 0;
    if (tab === "playercard") { p.player_card = id; }
    else if (tab === "hat") { const a = (p.hats || ["None", "None", "None"]).slice(); a[slot] = id; p.hats = a; }
    else { const def = "gamepanel_color_default"; const a = (p.action_frames || [def, def, def]).slice(); a[slot] = id; p.action_frames = a; }
    saveCosmetics();
    set({ msg: tab === "playercard" ? "Player card equipped" : "Equipped to Char " + (slot + 1), msgKind: "ok" });
  }
  function saveCosmetics() {
    if (!S.player) return;
    S.net.send("save_cosmetics", { update: makeCosmeticUpdate(S.player) });   // server bridge; no echo, keep local state
    log("out", "save_cosmetics");
  }
  // Mirror player_component.make_cosmetic_update — echo unmanaged fields from the blob.
  function makeCosmeticUpdate(p) {
    const k = (key, def) => (p[key] !== undefined ? p[key] : def);
    return {
      muted: k("muted", false), character_frames: k("character_frames", []), action_frames: k("action_frames", []),
      hats: k("hats", []), characters: k("characters", []), mastery_profiles: k("mastery_profiles", []),
      mastery_skins: k("mastery_skins", []), ingame_background: k("ingame_background", ""), charselect_background: k("charselect_background", ""),
      title: k("title", ""), unlocks: k("unlocks", []), ap: k("ap", 0), clan: k("clan", "Clanless"),
      cosmetics_on: k("cosmetics_on", false), bot_turn_delay: k("bot_turn_delay", 0), bot_queue_delay: k("bot_queue_delay", 15),
      // bounty_rerolls / active_bounties are DICTS ({key: …}). Defaulting to 0 / [] (as before)
      // corrupted the server's copy — a float bounty_rerolls crashes get_bounty_rerolls (String in
      // float) and an [] active_bounties wipes the player's bounties. Default to {} to keep the type.
      player_card: k("player_card", ""), avatar_url: k("avatar_url", ""), bounty_rerolls: k("bounty_rerolls", {}),
      active_bounties: k("active_bounties", {}), mark_significant: k("mark_significant", true), animations_enabled: k("animations_enabled", true),
      // ranked_allow_bots is intentionally NOT sent here — it's a server-written setting persisted via
      // its own "social_setting" message (see settingsMenu), like allow_spectators. Sending it on the
      // cosmetic bridge is what made stale clients reset it to the default.
      // campaign_state intentionally omitted — it is server-authoritative (mutated only by the campaign_*
      // intent handlers), so the client never sends it back; absorb_cosmetic_update ignores it anyway.
      // mastery_xp intentionally omitted — absorb_cosmetic_update applies it only `if 'mastery_xp' in data`,
      // so leaving it out keeps the server's authoritative mastery progress untouched on an equip.
    };
  }
  // cosmetic-image element (full, natural aspect) used by both tiles and the preview pane
  function cosImg(cls, dir, id, portUrl) {
    return el("img", { class: cls, src: cosmeticUrl(dir, id), alt: "", onerror: (e) => { if (portUrl && !e.target.dataset.fb) { e.target.dataset.fb = "1"; e.target.src = portUrl; } else e.target.style.visibility = "hidden"; } });
  }
  // Default preview = whatever is currently equipped for this tab (so you see your selection), else first unlocked.
  function defaultPreviewPath(tab) {
    const roster = S.roster || [], p = S.player || {};
    const eqId = tab === "playercard" ? p.player_card : tab === "hat" ? (p.hats || [])[0] : (p.action_frames || [])[0];
    if (eqId) { const m = roster.find((c) => masteryCosmeticId(tab, c.path_name) === eqId); if (m) return m.path_name; }
    const u = roster.find((c) => masteryLevel(c.path_name) >= UNLOCK_THRESHOLDS[tab]);
    return ((u || roster[0] || {}).path_name) || null;
  }
  // Build a tab's selectable tiles as uniform "entries" so the picker can mix sources. Mastery
  // entries (one per character, gated by that character's mastery level) exist for every tab; the
  // Game Panels tab (action_frame) ALSO lists the "Action Panels" bought in the Shop, which — like
  // mastery panels — live in action_frames[]. Owned shop panels are prepended so a freshly bought
  // panel shows without scrolling past the whole roster. Elite Panels stay mastery-only.
  // entry: { tab, id, name, path|null, req, source:"mastery"|"shop", unlocked }
  // Cosmetic tab -> shop item category. Owned shop cosmetics are merged into the picker alongside
  // mastery unlocks (Player Cards, Game Panels). Tabs with no shop category (hat, elite_action_frame)
  // stay mastery-only.
  const COS_SHOP_CATEGORY = { playercard: "playercard", action_frame: "gamepanel" };
  function cosmeticEntries(tab) {
    const req = UNLOCK_THRESHOLDS[tab];
    const mastery = rosterByName().map((c) => ({
      tab: tab, id: masteryCosmeticId(tab, c.path_name), name: c.name, path: c.path_name,
      req: req, source: "mastery", unlocked: masteryLevel(c.path_name) >= req,
    }));
    const shopCat = COS_SHOP_CATEGORY[tab];
    if (!shopCat) return mastery;
    if (!S.shopCatalog) loadShopCatalog();
    const cat = (S.shopCatalog && S.shopCatalog.items && S.shopCatalog.items[shopCat]) || [];
    const shop = cat.filter((it) => shopOwned(it[0])).map((it) => ({
      tab: tab, id: it[0], name: it[3], path: null, req: 0, source: "shop", unlocked: true,
    }));
    return shop.concat(mastery);
  }
  // Preview target when nothing is hovered: the entry matching whatever is already equipped for
  // this tab (mastery OR shop id), else the first unlocked one.
  function defaultPreviewEntry(tab, entries) {
    const p = S.player || {};
    const eqId = tab === "playercard" ? p.player_card : tab === "hat" ? (p.hats || [])[0] : (p.action_frames || [])[0];
    if (eqId) { const m = entries.find((e) => e.id === eqId); if (m) return m; }
    return entries.find((e) => e.unlocked) || entries[0] || null;
  }
  let _cosPreviewEl = null;
  function cosPreviewContent(tab, entry) {
    if (!entry) return [el("div", { class: "cpv-empty note" }, ["Hover a cosmetic to preview it"])];
    const id = entry.id, req = entry.req, lvl = entry.path ? masteryLevel(entry.path) : 0;
    const unlocked = entry.unlocked, slot = S.cosmeticSlot || 0, perSlot = tab !== "playercard";
    const equippedHere = unlocked && isCosmeticEquippedSlot(tab, id, slot);
    const kids = [
      el("div", { class: "cpv-imgbox" }, [cosImg("cpv-img", COS_DIRS[tab], id, entry.path ? portraitUrlFor(entry.path) : null)]),
      el("div", { class: "cpv-name" }, [entry.name]),
      el("div", { class: "cpv-type" }, [COS_LABELS[tab]]),
    ];
    if (perSlot) kids.push(el("div", { class: "cpv-slots" }, [0, 1, 2].map((s) =>
      el("button", { class: "cpv-slot" + (s === slot ? " sel" : ""), title: "Team slot " + (s + 1), onclick: () => { S.cosmeticSlot = s; fillCosPreview(S.cosmeticPreview); } }, ["Char " + (s + 1)]))));
    kids.push(equippedHere ? el("div", { class: "cpv-status equipped" }, ["✓ Equipped" + (perSlot ? " (Char " + (slot + 1) + ")" : "")])
      : unlocked ? el("div", { class: "cpv-status ok" }, [entry.source === "shop" ? "Owned — bought in the Shop" : "Unlocked at Mastery Lv " + req])
        : el("div", { class: "cpv-status locked" }, ["Locked — Mastery Lv " + req + " (you're Lv " + lvl + ")"]));
    if (unlocked && !equippedHere) kids.push(el("button", { class: "cpv-equip", onclick: () => equipCosmetic(tab, id, slot) }, [perSlot ? "Equip to Char " + (slot + 1) : "Equip"]));
    return kids;
  }
  function fillCosPreview(entry) {            // imperative update on hover — avoids a full re-render per mousemove
    S.cosmeticPreview = entry;
    if (_cosPreviewEl) _cosPreviewEl.replaceChildren(...cosPreviewContent(S.cosmeticTab, entry));
  }
  // Backgrounds aren't mastery cosmetics — they're owned via the shop and stored in
  // ingame_background / charselect_background. Apply one to the battle or char-select screen.
  function backgroundUrl(id) { return id ? resToUrl("res://assets/backgrounds/" + id + ".png") : null; }
  // A CSS background-image (shown at full color — no scrim) for an equipped background id.
  function bgStyle(id) {
    const url = backgroundUrl(id);
    return url ? ("background-image:url('" + url + "');background-size:cover;background-position:center;") : "";
  }
  function equipBackground(field, id) {
    if (!S.player) return;
    S.player[field] = id;
    saveCosmetics();
    set({ msg: id ? "Background applied" : "Background cleared", msgKind: "ok" });
  }
  function backgroundSection() {
    if (!S.shopCatalog) loadShopCatalog();
    const p = S.player || {};
    const target = S.bgTarget === "charselect" ? "charselect" : "ingame";
    const field = target === "charselect" ? "charselect_background" : "ingame_background";
    const current = p[field] || "";
    const cat = (S.shopCatalog && S.shopCatalog.items && S.shopCatalog.items.background) || [];
    const nameOf = (id) => { const it = cat.find((x) => x[0] === id); return it ? it[3] : titleCase(id.replace(/^background_(ingame_)?/, "").replace(/_/g, " ")); };
    // Owned = the shop's background items the player owns. Use shopOwned (not a raw unlocks
    // scan) so an "all_unlock" account — which owns everything implicitly — populates too.
    const owned = cat.filter((it) => shopOwned(it[0])).map((it) => it[0]);
    // The starting background for each screen (player_component.gd defaults every account to
    // these). They are NOT shop items, so listing only shop-owned ids made them unreachable
    // the moment you equipped anything else: "None" clears to a blank screen, which is not the
    // same thing as the default art. Always offer the one that belongs to the active target.
    const DEFAULT_BG = { ingame: "background_ingame_default", charselect: "background_charselect_default" };
    const defaultId = DEFAULT_BG[target];
    const tile = (id, label) => {
      const eq = (current || "") === (id || "");
      const kids = [
        id ? el("img", { class: "bg-img", src: backgroundUrl(id), alt: "", onerror: (e) => (e.target.style.visibility = "hidden") }) : el("div", { class: "bg-none" }, ["None"]),
        el("div", { class: "bg-name" }, [label]),
      ];
      if (eq) kids.push(el("div", { class: "cos-equipped bg-eq" }, ["✓"]));
      const cell = el("div", { class: "bg-cell" + (eq ? " equipped" : "") }, kids);
      cell.addEventListener("click", () => equipBackground(field, id));
      return cell;
    };
    // Default first, then None, then anything bought. `owned` is filtered so a default that
    // ever does get sold can't appear twice.
    const tiles = [tile(defaultId, "Default"), tile("", "None")]
      .concat(owned.filter((id) => id !== defaultId).map((id) => tile(id, nameOf(id))));
    return [
      el("div", { class: "cos-note" }, ["Apply a background to your battle or character-select screen. Buy more in the Shop."]),
      el("div", { class: "bg-target-row" }, [
        el("span", { class: "cpv-type" }, ["Apply to:"]),
        el("div", { class: "bg-targets" }, [["ingame", "In-Battle"], ["charselect", "Character Select"]].map(([k, lbl]) =>
          el("button", { class: "cpv-slot" + (target === k ? " sel" : ""), onclick: () => set({ bgTarget: k }) }, [lbl]))),
      ]),
      el("div", { class: "bg-grid" }, tiles),
    ];
  }
  function cosmeticsMenu() {
    const roster = rosterByName();
    if (!roster.length) loadRoster();
    const tab = S.cosmeticTab || "playercard";
    const tabsEl = el("div", { class: "cos-tabs" }, COS_TABS.map(([k, label]) =>
      el("button", { class: "cos-tab" + (tab === k ? " sel" : ""), onclick: () => set({ cosmeticTab: k }) }, [label])));
    if (tab === "background") return el("div", { class: "cosmetics-menu" }, [tabsEl].concat(backgroundSection()));
    const dir = COS_DIRS[tab], geo = COS_TILE[tab];
    const onlyUnlocked = !!S.cosOnlyUnlocked;
    const entries = cosmeticEntries(tab);
    const shown = onlyUnlocked ? entries.filter((e) => e.unlocked) : entries;
    const tiles = shown.map((e) => {
      const unlocked = e.unlocked;
      const equipped = unlocked && isCosmeticEquipped(tab, e.id);
      const kids = [cosImg("cos-img", dir, e.id, e.path ? portraitUrlFor(e.path) : null)];
      if (!unlocked) kids.push(el("div", { class: "cos-lock" }, ["Lv " + e.req]));
      if (equipped) kids.push(el("div", { class: "cos-equipped" }, ["✓"]));
      const title = e.name + (unlocked ? (e.source === "shop" ? " — Owned (Shop)" : " — Unlocked") : " — Mastery Lv " + e.req);
      const cell = el("div", { class: "cos-cell" + (unlocked ? "" : " locked") + (equipped ? " equipped" : ""), style: "width:" + geo.w + "px;height:" + geo.h + "px", title: title }, kids);
      cell.addEventListener("mouseenter", () => fillCosPreview(e));
      if (unlocked) cell.addEventListener("click", () => equipCosmetic(tab, e.id, S.cosmeticSlot || 0));
      return cell;
    });
    const preview = (S.cosmeticPreview && S.cosmeticPreview.tab === tab) ? S.cosmeticPreview : defaultPreviewEntry(tab, entries);
    _cosPreviewEl = el("div", { class: "cos-preview" }, cosPreviewContent(tab, preview));
    return el("div", { class: "cosmetics-menu" }, [
      tabsEl,
      el("div", { class: "cos-note-row" }, [
        el("div", { class: "cos-note" }, [COS_SHOP_CATEGORY[tab]
          ? COS_LABELS[tab] + "s — mastery ones unlock by leveling a character; those bought in the Shop appear here too. Hover to preview; click an owned one to equip."
          : "Mastery cosmetics — unlock each by leveling that character's mastery. Hover to preview; click an unlocked one to equip."]),
        el("button", { class: "cos-filter" + (onlyUnlocked ? " on" : ""), onclick: () => set({ cosOnlyUnlocked: !onlyUnlocked }) }, [onlyUnlocked ? "✓ Unlocked only" : "Unlocked only"]),
      ]),
      el("div", { class: "cos-body" }, [
        el("div", { class: "cos-grid", "data-scrollkey": "cos-grid-" + (S.cosmeticTab || ""), style: "grid-template-columns:repeat(auto-fill, " + geo.w + "px)" }, tiles.length ? tiles : [el("div", { class: "note" }, [onlyUnlocked ? "No unlocked cosmetics in this category yet." : "None."])]),
        _cosPreviewEl,
      ]),
    ]);
  }

  // Nexus — global community AP pool, one bucket per character. Home view = leaderboard;
  // pick a universe to see its characters' buckets and donate AP to them.
  const fmtAp = (n) => (n || 0).toLocaleString();
  // roster.json universe values are inconsistent — some clean ("Demon Slayer"), some raw enums
  // ("FULL_METAL_ALCHEMIST") or enum to_string ("Frieren (CharacterConcept.Universe.FRIEREN)").
  function prettyUniverse(u) {
    if (!u) return u;
    // Formats seen: "Clean Name", "RAW_ENUM", "Name (CharacterConcept.Universe.X)",
    // "RAW_ENUM (Clean Name)", "Clean Name (RAW_ENUM)". Pick the non-enum part.
    const m = u.match(/^(.*?)\s*\((.*)\)\s*$/);
    const parts = m ? [m[1].trim(), m[2].trim()] : [u.trim()];
    const isEnum = (s) => !s || /^[A-Z0-9_]+$/.test(s) || s.indexOf("CharacterConcept") !== -1;
    let clean = parts.find((p) => !isEnum(p)) || parts[0];
    if (/^[A-Z0-9_]+$/.test(clean)) clean = clean.toLowerCase().replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
    return clean;
  }
  // Canonical key for a universe name. roster.json display names ("Hunter x Hunter", "Yu-Gi-Oh!")
  // rarely match the titlecased enum key the server sends per bucket ("Hunter X Hunter", "Yu Gi Oh"),
  // so compare on a punctuation/case-insensitive key to avoid duplicate buttons / split buckets.
  function uniKey(u) { return (u || "").toLowerCase().replace(/[^a-z0-9]/g, ""); }
  // Mirrors the Godot Universe enum (components/character_concept.gd) — the canonical source for the
  // Nexus universe buttons, so they always match the server's enum-key bucket universes instead of
  // roster.json's drifting display names. INVINCIBLE is intentionally omitted (disabled in the Nexus).
  const NEXUS_UNIVERSE_KEYS = ["NARUTO", "BLEACH", "ONE_PIECE", "MY_HERO_ACADEMIA", "BLACK_CLOVER", "MADOKA_MAGICA", "FAIRY_TAIL", "SOUL_EATER", "AVATAR", "AKAME_GA_KILL", "DEMON_SLAYER", "SEVEN_DEADLY_SINS", "KATEKYO_HITMAN_REBORN", "ATTACK_ON_TITAN", "ONE_PUNCH_MAN", "FIRE_FORCE", "HUNTER_X_HUNTER", "A_CERTAIN_SCIENTIFIC_RAILGUN", "FATE", "KILL_LA_KILL", "DEADMAN_WONDERLAND", "TOKYO_GHOUL", "THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME", "JUJUTSU_KAISEN", "DIGIMON", "SAILOR_MOON", "DRAGON_BALL", "MASHLE", "EMINENCE_IN_SHADOW", "FRIEREN", "SOLO_LEVELING", "CHAINSAW_MAN", "AO_NO_EXORCIST", "YUGIOH", "INUYASHA", "FULL_METAL_ALCHEMIST", "ASSASSINATION_CLASSROOM", "KONOSUBA", "SERAPH_OF_THE_END", "CHIVALRY_OF_A_FAILED_KNIGHT", "GACHIAKUTA", "SHAMAN_KING", "RECORD_OF_RAGNAROK", "SAINT_SEIYA", "YU_YU_HAKUSHO", "TOUGEN_ANKI", "MIRAI_NIKKI", "RE_ZERO", "BAKI", "SYMPHOGEAR", "CLAYMORE"];
  function nexusMenu() {
    const roster = S.roster || [];
    if (!roster.length) loadRoster();
    // Buttons come straight from the Godot Universe enum (never roster.json, whose display names
    // drift from the enum keys and produced dead buttons like "Fate/stay night"). Any server bucket
    // universe missing from the client's enum copy is still added (drift safety); INVINCIBLE is off.
    const byKey = {};
    NEXUS_UNIVERSE_KEYS.forEach((k) => { const u = prettyUniverse(k); byKey[uniKey(u)] = u; });
    Object.values(S.nexusBucketUni || {}).forEach((u) => { if (u && !byKey[uniKey(u)]) byKey[uniKey(u)] = u; });
    delete byKey[uniKey("Invincible")];
    const universes = Object.values(byKey).sort((a, b) => a.localeCompare(b));
    const ap = (S.player && S.player.ap) || 0;
    const side = el("div", { class: "nx-side" }, [
      el("button", { class: "nx-uni" + (S.nexusUniverse == null ? " sel" : ""), onclick: () => set({ nexusUniverse: null }) }, ["★ Leaderboard"]),
      ...universes.map((u) => el("button", { class: "nx-uni" + (S.nexusUniverse === u ? " sel" : ""), title: u, onclick: () => set({ nexusUniverse: u }) }, [u])),
    ]);
    const content = S.nexusUniverse == null ? nexusLeaderboard() : nexusUniverseView(S.nexusUniverse);
    const kids = [
      el("div", { class: "nx-header" }, [
        el("div", { class: "nx-ap" }, ["Your AP: ", el("b", {}, [fmtAp(ap)])]),
        S.nexusPollOpen ? null : el("div", { class: "nx-closed" }, ["Donations closed"]),
      ]),
      el("div", { class: "nx-body" }, [side, content]),
    ];
    if (S.nexusDonate) kids.push(nexusDonatePopup());
    return el("div", { class: "nexus-menu" }, kids);
  }
  function nexusRow(path, ap, rank, donatable) {
    const purl = portraitUrlFor(path);
    const kids = [];
    if (rank != null) kids.push(el("div", { class: "nx-rank" }, ["#" + rank]));
    if (purl) kids.push(el("img", { class: "nx-portrait", src: purl, alt: "", onerror: (e) => e.target.remove() }));
    const info = [el("div", { class: "nx-name" }, [nameFor(path)])];
    if (donatable) {
      const pct = Math.max(0, Math.min(100, (ap / Math.max(1, S.nexusMax)) * 100));
      info.push(el("div", { class: "nx-bar" }, [el("i", { style: "width:" + pct + "%" })]));
    }
    kids.push(el("div", { class: "nx-info" }, info));
    kids.push(el("div", { class: "nx-apval" }, [fmtAp(ap) + " AP"]));
    const row = el("div", { class: "nx-row" + (donatable ? " donatable" : "") }, kids);
    if (donatable) row.addEventListener("click", () => set({ nexusDonate: { path_name: path } }));
    return row;
  }
  function nexusLeaderboard() {
    const top = Object.keys(S.nexusBuckets || {}).map((p) => [p, S.nexusBuckets[p]]).sort((a, b) => b[1] - a[1]).slice(0, 10);
    return el("div", { class: "nx-content" }, [
      el("div", { class: "nx-title" }, ["Top Characters"]),
      el("div", { class: "nx-list", "data-scrollkey": "nx-top" }, top.length ? top.map((e, i) => nexusRow(e[0], e[1], i + 1, true)) : [el("div", { class: "note" }, ["Loading…"])]),
    ]);
  }
  function nexusUniverseView(u) {
    const uni = S.nexusBucketUni || {}, buckets = S.nexusBuckets || {};
    const key = uniKey(u);   // match on canonical key — wire universe ("Hunter X Hunter") != button label ("Hunter x Hunter")
    // Iterate the BUCKETS (the authoritative, full set), grouped by their wire universe — not
    // roster.json, which only covers playable characters and misses almost every bucket.
    const rows = Object.keys(buckets).filter((p) => {
      if (uni[p] != null) return uniKey(uni[p]) === key;
      const c = (S.roster || []).find((r) => r.path_name === p);   // fallback for any bucket sent before the universe field existed
      return c && uniKey(prettyUniverse(c.universe)) === key;
    }).sort((a, b) => (buckets[b] || 0) - (buckets[a] || 0))
      .map((p) => nexusRow(p, buckets[p], null, true));
    return el("div", { class: "nx-content" }, [
      el("div", { class: "nx-title" }, [prettyUniverse(u)]),
      el("div", { class: "nx-note" }, ["Click a character to donate AP to their bucket."]),
      el("div", { class: "nx-list", "data-scrollkey": "nx-uni" }, rows.length ? rows : [el("div", { class: "note" }, ["No buckets in this universe yet"])]),
    ]);
  }
  function nexusDonatePopup() {
    const path = S.nexusDonate.path_name;
    const c = (S.roster || []).find((r) => r.path_name === path);
    const bucketAp = (S.nexusBuckets || {})[path] || 0;
    const playerAp = (S.player && S.player.ap) || 0;
    return el("div", { class: "nx-popup-overlay", onclick: (e) => { if (e.target.classList.contains("nx-popup-overlay")) set({ nexusDonate: null }); } }, [
      el("div", { class: "nx-popup" }, [
        el("div", { class: "nx-popup-title" }, ["Donate to " + (c ? c.name : titleCase(path))]),
        el("div", { class: "nx-popup-sub" }, ["Bucket: " + fmtAp(bucketAp) + " AP   ·   Your AP: " + fmtAp(playerAp)]),
        el("input", { class: "nx-popup-input", type: "number", min: "1", max: String(playerAp), placeholder: "Amount", value: S.nexusDonate.amount || "", oninput: (e) => { S.nexusDonate.amount = e.target.value; } }),
        el("div", { class: "nx-popup-actions" }, [
          el("button", { class: "nx-cancel", onclick: () => set({ nexusDonate: null }) }, ["Cancel"]),
          el("button", { class: "nx-confirm", onclick: () => doDonate(path) }, ["Donate"]),
        ]),
      ]),
    ]);
  }
  function doDonate(path) {
    const amount = Math.floor(Number(S.nexusDonate && S.nexusDonate.amount));
    const playerAp = (S.player && S.player.ap) || 0;
    if (!amount || amount <= 0) return set({ msg: "Enter a valid amount", msgKind: "bad" });
    if (!S.nexusPollOpen) return set({ msg: "Nexus donations are closed", msgKind: "bad" });
    if (amount > playerAp) return set({ msg: "Not enough AP", msgKind: "bad" });
    // Optimistic: decrement AP + bump the bucket; the server echoes receive_player_update (AP) and
    // update_buckets (bucket total) to reconcile to authoritative values.
    S.player.ap = playerAp - amount;
    S.nexusBuckets[path] = ((S.nexusBuckets[path] || 0) + amount);
    if (S.nexusBuckets[path] > S.nexusMax) S.nexusMax = S.nexusBuckets[path];
    S.net.send("donate", { path_name: path, amount: amount });
    log("out", "donate " + path + " " + amount);
    set({ nexusDonate: null, msg: "Donated " + fmtAp(amount) + " AP", msgKind: "ok" });
  }

  // Title builder — compose player.title (space-joined, up to 5 words) from unlocked words:
  // base words (Player.title_data default) + mastery words (lesser at Lv2, greater at Lv4 per
  // character). Persisted via the existing save_cosmetics `title` field.
  function unlockedTitleWords() {
    const words = new Set(BASE_TITLE_WORDS);
    const t = S.titles;
    if (t && S.roster) {
      for (const c of S.roster) {
        const lvl = masteryLevel(c.path_name);
        if (lvl >= UNLOCK_THRESHOLDS.lesser_title && t.lesser[c.path_name]) t.lesser[c.path_name].forEach((w) => words.add(w));
        if (lvl >= UNLOCK_THRESHOLDS.greater_title && t.greater[c.path_name]) t.greater[c.path_name].forEach((w) => words.add(w));
      }
    }
    // always include words already in the equipped title, so it stays editable even if data is partial
    (((S.player && S.player.title) || "").split(" ").filter(Boolean)).forEach((w) => words.add(w));
    return words;
  }
  function addTitleWord(w) {
    if (!S.titleEdit) S.titleEdit = [];
    if (S.titleEdit.includes(w)) return;
    if (S.titleEdit.length >= MAX_TITLE_WORDS) return set({ msg: "Titles are at most " + MAX_TITLE_WORDS + " words", msgKind: "bad" });
    S.titleEdit.push(w); render();
  }
  function removeTitleWord(i) { (S.titleEdit || []).splice(i, 1); render(); }
  function saveTitle() {
    if (!S.player) return;
    S.player.title = (S.titleEdit || []).join(" ");
    saveCosmetics();   // existing bridge persists the `title` field
    set({ msg: S.player.title ? "Title saved" : "Title cleared", msgKind: "ok" });
  }
  function titleMenu() {
    if (!S.roster || !S.roster.length) loadRoster();
    if (!S.titles) loadTitles();
    const edit = S.titleEdit || [];
    const unlocked = unlockedTitleWords();
    const available = Array.from(unlocked).filter((w) => !edit.includes(w)).sort((a, b) => a.localeCompare(b));
    const preview = edit.length
      ? el("div", { class: "tm-preview" }, [edit.join(" ")])
      : el("div", { class: "tm-preview empty" }, ["(no title)"]);
    const builderKids = edit.length
      ? edit.map((w, i) => { const chip = el("button", { class: "tm-chip used", title: "Remove" }, [w, el("span", { class: "tm-x" }, ["✕"])]); chip.addEventListener("click", () => removeTitleWord(i)); return chip; })
      : [el("div", { class: "tm-hint" }, ["Click words below to build your title (up to " + MAX_TITLE_WORDS + ")."])];
    const atMax = edit.length >= MAX_TITLE_WORDS;
    const poolKids = available.length
      ? available.map((w) => { const chip = el("button", { class: "tm-chip" + (atMax ? " off" : ""), disabled: atMax }, [w]); chip.addEventListener("click", () => addTitleWord(w)); return chip; })
      : [el("div", { class: "tm-hint" }, [S.titles ? "Level up character mastery to unlock title words." : "Loading…"])];
    const dirty = edit.join(" ") !== (((S.player && S.player.title) || ""));
    return el("div", { class: "title-menu" }, [
      el("div", { class: "tm-preview-row" }, [el("div", { class: "tm-label" }, ["Your Title"]), preview]),
      el("div", { class: "tm-builder" }, builderKids),
      el("div", { class: "tm-actions" }, [
        el("button", { class: "tm-save" + (dirty ? "" : " off"), disabled: !dirty, onclick: saveTitle }, ["Save Title"]),
        edit.length ? el("button", { class: "tm-clear", onclick: () => { S.titleEdit = []; render(); } }, ["Clear"]) : null,
        el("div", { class: "tm-count" }, [edit.length + " / " + MAX_TITLE_WORDS]),
      ]),
      el("div", { class: "tm-pool-label" }, ["Unlocked Words (" + available.length + ")"]),
      el("div", { class: "tm-pool" }, poolKids),
    ]);
  }

  // Settings — toggles/sliders for player fields already carried by the save_cosmetics bridge.
  function settingsSlider(label, field, min, max, suffix) {
    const val = Math.round((S.player && S.player[field]) || min);
    const valEl = el("span", { class: "set-val" }, [val + suffix]);
    const input = el("input", { type: "range", class: "set-slider", min: String(min), max: String(max), step: "1", value: String(val) });
    input.addEventListener("input", (e) => { valEl.textContent = e.target.value + suffix; });                 // live label, no re-render
    input.addEventListener("change", (e) => { S.player[field] = Number(e.target.value); saveCosmetics(); set({ msg: "Settings saved", msgKind: "ok" }); });
    return el("div", { class: "set-row" }, [el("div", { class: "set-label" }, [label]), el("div", { class: "set-control" }, [input, valEl])]);
  }
  // Number-entry variant for a wide range where a drag slider would be too coarse (e.g. up to 9999s).
  function settingsNumber(label, field, min, max, suffix) {
    const cur = Math.round((S.player && S.player[field]) || min);
    const input = el("input", { type: "number", class: "set-num", min: String(min), max: String(max), step: "1", value: String(cur) });
    const commit = (e) => {
      let v = Math.round(Number(e.target.value));
      if (!isFinite(v)) v = min;
      v = Math.max(min, Math.min(max, v));   // clamp to [min, max]
      e.target.value = String(v);
      S.player[field] = v; saveCosmetics(); set({ msg: "Settings saved", msgKind: "ok" });
    };
    input.addEventListener("change", commit);
    return el("div", { class: "set-row" }, [el("div", { class: "set-label" }, [label]), el("div", { class: "set-control" }, [input, el("span", { class: "set-val" }, [suffix])])]);
  }
  // `persist` overrides how the new value is saved. Default rides the save_cosmetics bridge; pass a
  // custom fn (e.g. a dedicated social_setting message) for server-written settings. Either way the
  // click is optimistic — S.player mutates locally and the server value re-arrives via the login blob.
  function settingsToggle(label, field, def, persist) {
    def = !!def;   // effective value when the field is absent (e.g. mark_significant defaults on)
    const on = (S.player && S.player[field] !== undefined) ? !!S.player[field] : def;
    const btn = el("button", { class: "set-toggle" + (on ? " on" : "") }, [el("i"), el("span", {}, [on ? "On" : "Off"])]);
    btn.addEventListener("click", () => { const nv = !on; S.player[field] = nv; (persist ? persist : saveCosmetics)(nv); set({ msg: "Settings saved", msgKind: "ok" }); });
    return el("div", { class: "set-row" }, [el("div", { class: "set-label" }, [label]), el("div", { class: "set-control" }, [btn])]);
  }
  // Client-only display toggle (no server round-trip): the state lives on S and persists to localStorage.
  // Default ON (undefined !== false). Flipping re-renders, so GK.frag/kw pick up the new flag immediately.
  function settingsClientToggle(label, stateKey, storageKey) {
    const on = S[stateKey] !== false;
    const btn = el("button", { class: "set-toggle" + (on ? " on" : "") }, [el("i"), el("span", {}, [on ? "On" : "Off"])]);
    btn.addEventListener("click", () => {
      const nv = !on; S[stateKey] = nv;
      try { localStorage.setItem(storageKey, nv ? "1" : "0"); } catch (e) {}
      set({ msg: "Settings saved", msgKind: "ok" });
    });
    return el("div", { class: "set-row" }, [el("div", { class: "set-label" }, [label]), el("div", { class: "set-control" }, [btn])]);
  }
  function passwordSection() {
    const curIn = el("input", { class: "set-pw-in", type: "password", placeholder: "Current password", autocomplete: "current-password" });
    const newIn = el("input", { class: "set-pw-in", type: "password", placeholder: "New password", autocomplete: "new-password" });
    const confIn = el("input", { class: "set-pw-in", type: "password", placeholder: "Confirm new password", autocomplete: "new-password" });
    const submit = () => {
      const cur = curIn.value, nw = newIn.value, cf = confIn.value;
      if (!cur || !nw) return set({ msg: "Enter your current and new password", msgKind: "err" });
      if (nw.length < 4) return set({ msg: "New password must be at least 4 characters", msgKind: "err" });
      if (nw !== cf) return set({ msg: "New passwords don't match", msgKind: "err" });
      changePassword(cur, nw);
    };
    confIn.addEventListener("keydown", (e) => { if (e.key === "Enter") submit(); });
    return el("div", { class: "set-pw" }, [
      el("div", { class: "set-pw-label" }, ["Change Password"]),
      curIn, newIn, confIn,
      el("button", { class: "set-pw-btn", onclick: submit }, ["Update Password"]),
    ]);
  }
  // Spectate privacy (D2): who may watch my live matches. Server-authoritative — the value rides
  // the login player blob; the click is optimistic (a self-preference) and social_result toasts
  // the server's verdict. Default "all".
  function settingsSpectators() {
    const cur = (S.player && S.player.allow_spectators) || "all";
    const opt = (val, label) => el("button", { class: "clan-btn sm" + (cur === val ? " primary" : ""), onclick: () => {
      S.player.allow_spectators = val;
      S.net.send("social_setting", { key: "allow_spectators", value: val });
      set({ msg: "Settings saved", msgKind: "ok" });
    } }, [label]);
    return el("div", { class: "set-row" }, [el("div", { class: "set-label" }, ["Allow spectators"]),
      el("div", { class: "set-control" }, [opt("all", "All"), opt("friends", "Friends"), opt("off", "Off")])]);
  }
  // UI theme picker (client-only, localStorage-backed, no server round-trip). The chosen theme is a
  // data-theme attribute on <html>; the CSS re-maps its :root tokens. Crimson Noir ("noir") is the
  // default; only an explicit "dark" choice (stored in localStorage) removes the attribute. Applied at
  // page load in index.html to avoid a flash of the wrong theme.
  const UI_THEMES = [["dark", "Dark"], ["noir", "Crimson Noir"]];
  function currentTheme() { try { return localStorage.getItem("aa_theme") || "noir"; } catch (e) { return "noir"; } }
  function applyTheme(name) {
    if (!name || name === "dark") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.setAttribute("data-theme", name);
  }
  function settingsTheme() {
    const cur = currentTheme();
    const opt = (val, label) => el("button", { class: "clan-btn sm" + (cur === val ? " primary" : ""), onclick: () => {
      try { localStorage.setItem("aa_theme", val); } catch (e) {}
      applyTheme(val);
      set({ msg: "Settings saved", msgKind: "ok" });
    } }, [label]);
    return el("div", { class: "set-row" }, [el("div", { class: "set-label" }, ["Theme"]),
      el("div", { class: "set-control" }, UI_THEMES.map((t) => opt(t[0], t[1])))]);
  }
  function settingsMenu() {
    if (!S.player) return el("div", { class: "note" }, ["Log in to change settings."]);
    return el("div", { class: "settings-menu" }, [
      settingsTheme(),
      settingsNumber("Bot queue delay", "bot_queue_delay", 15, 9999, "s"),
      settingsSlider("Bot turn delay", "bot_turn_delay", 5, 45, "s"),
      settingsToggle("Show enemy cosmetics", "cosmetics_on"),
      settingsToggle("Allow bots in Ladder queue", "ranked_allow_bots", true,
        (v) => S.net.send("social_setting", { key: "ranked_allow_bots", value: v })),
      el("div", { class: "set-note" }, [
        "With this off, a Ladder search never falls back to a bot — you keep waiting for a real " +
        "opponent, and may be matched far above or far below your rating.",
      ]),
      settingsVolume(),
      settingsToggle("Mark significant abilities", "mark_significant", true),
      settingsToggle("Battle animations", "animations_enabled"),
      settingsClientToggle("Colored keyword highlights", "gkColors", "aa_gk_colors"),
      settingsClientToggle("Keyword hover tips", "gkKeywords", "aa_gk_keywords"),
      el("div", { class: "set-note" }, [
        "Keyword hover tips highlight terms in skill descriptions. Turn off “Colored” for a single " +
        "uniform colour, or turn off “Keyword hover tips” to disable them entirely. Effect tooltips are unaffected.",
      ]),
      settingsSpectators(),
      el("div", { class: "set-note" }, ["Changes save automatically."]),
      passwordSection(),
      el("button", { class: "set-logout", onclick: () => { clearSavedLogin(); location.reload(); } }, ["Log Out"]),
    ]);
  }

  // Ladder — ranked players (top-50 by rating/wins/streak) + clans, fetched from the server.
  const LADDER_TABS = [["by_rating", "Rating", "rating"], ["by_wins", "Wins", "wins"], ["by_streak", "Streak", "streak"], ["clans", "Clans", null]];
  function ladderRow(rank, name, metric, sub, isMe) {
    return el("div", { class: "ld-row" + (isMe ? " me" : "") }, [
      el("div", { class: "ld-rank" }, ["#" + rank]),
      el("div", { class: "ld-name" }, name),
      el("div", { class: "ld-metric" }, [String(metric)]),
      el("div", { class: "ld-sub" }, [sub]),
    ]);
  }
  function ladderRanking(section, metric) {
    if (!section) return el("div", { class: "note" }, ["No data"]);
    const me = S.player && S.player.username;
    const mkName = (r) => [r.username, (r.clan_name && r.clan_name !== "Clanless") ? el("span", { class: "ld-clan" }, [" [" + r.clan_name + "]"]) : null];
    // On the rating board, lead the subtitle with the tier badge — the raw number is the headline
    // figure, but "Gold 3" is what people actually read their standing as. The server derives it
    // from the same rating, so the two can't disagree.
    const sub = (r) => {
      const wl = r.wins + "W " + r.losses + "L";
      const t = (r.rank != null && RANKS[r.rank] != null) ? divisionName(r.rank, r.tier) : "";
      return (metric === "rating" && t) ? t.trim() + " · " + wl : wl;
    };
    const mkRow = (rank, r) => ladderRow(rank, mkName(r), Math.round(r[metric]), sub(r), r.username === me);
    const rows = (section.top || []).map((r, i) => mkRow(i + 1, r));
    if (section.me) { rows.push(el("div", { class: "ld-gap" }, ["⋯"])); rows.push(mkRow(section.me.rank, section.me.row)); }
    return el("div", { class: "ld-list", "data-scrollkey": "ld-players" }, rows.length ? rows : [el("div", { class: "note" }, ["No ladder players yet"])]);
  }
  function ladderMenu() {
    const tab = S.ladderTab || "by_rating", data = S.ladder;
    const tabsEl = el("div", { class: "ld-tabs" }, LADDER_TABS.map(([k, label]) =>
      el("button", { class: "ld-tab" + (tab === k ? " sel" : ""), onclick: () => set({ ladderTab: k }) }, [label])));
    let body;
    if (!data) body = el("div", { class: "note ld-loading" }, ["Loading ladder…"]);
    else if (tab === "clans") {
      const rows = (data.clan_data || []).map((c, i) => ladderRow(i + 1, [c.clan_name], "Lv " + c.level, c.members + " members · " + c.wins + "W " + c.losses + "L", false));
      body = el("div", { class: "ld-list", "data-scrollkey": "ld-clans" }, rows.length ? rows : [el("div", { class: "note" }, ["No clans ranked yet"])]);
    } else {
      body = ladderRanking(data[tab], LADDER_TABS.find((t) => t[0] === tab)[2]);
    }
    return el("div", { class: "ladder-menu" }, [tabsEl, body]);
  }

  // ---- Player profile overlay: search any player + showcase stats/clan/title/top-5 mastery/history.
  const PROFILE_MODE_LABEL = { 0: "Private", 1: "Quick", 2: "Bot", 3: "Ladder", 4: "Campaign" };
  // Live presence (mirrors the admin panel's per-player status). Unknown/absent -> Offline.
  const PROFILE_STATUS = {
    online: { label: "Online", cls: "online" },
    "in match": { label: "In Match", cls: "inmatch" },
    disconnected: { label: "Away", cls: "away" },
    offline: { label: "Offline", cls: "offline" },
  };
  function statusBadge(status) {
    const s = PROFILE_STATUS[status] || PROFILE_STATUS.offline;
    return el("div", { class: "pi-status " + s.cls }, [el("span", { class: "pi-status-dot" }, []), s.label]);
  }
  function timeAgo(ts) {   // unix seconds -> compact relative string
    if (!ts) return "";
    const s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
    if (s < 60) return "just now";
    if (s < 3600) return Math.floor(s / 60) + "m ago";
    if (s < 86400) return Math.floor(s / 3600) + "h ago";
    return Math.floor(s / 86400) + "d ago";
  }
  let _profileResetArm = false;   // two-tap guard for the self-service W/L reset (mirrors _clanDisbandArm)
  function profileMenu() {
    if (!(S.roster || []).length) loadRoster();
    if (!S.portraits) loadPortraits();
    // Username search — off-render buffer + caret-preserving data-focus-id (mirrors clan search).
    const searchIn = el("input", { class: "clan-input", "data-focus-id": "profile-search", placeholder: "Search a player by username…", value: S.profileQuery, autocapitalize: "off", autocorrect: "off", spellcheck: "false", oninput: (e) => { S.profileQuery = e.target.value; } });
    const doSearch = () => { const q = (S.profileQuery || "").trim(); if (q) S.net.send("get_player_profile", { username: q }); };
    searchIn.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); doSearch(); } });
    const searchRow = el("div", { class: "clan-inline profile-search" }, [
      searchIn,
      el("button", { class: "clan-btn", onclick: doSearch }, ["Search"]),
      el("button", { class: "clan-btn", onclick: () => { S.profileQuery = ""; S.net.send("get_player_profile", { username: (S.player || {}).username }); } }, ["Me"]),
    ]);
    const p = S.profile;
    if (!p) return el("div", { class: "profile-menu" }, [searchRow, el("div", { class: "note" }, ["Loading profile…"])]);
    const mine = !!(S.player && p.username === S.player.username);   // shared by the Watch buttons + the reset section below

    // Identity header (no player-card): a large avatar with the username + title on the left,
    // and the clan avatar + name filling the right-hand side.
    const inClan = !!(p.clan && p.clan !== "Clanless");
    const avSrc = p.avatar_url || resToUrl("res://assets/avatars/toko_toda.png");
    const identity = el("div", { class: "profile-identity" }, [
      el("div", { class: "pi-main" }, [
        el("img", { class: "pi-avatar", src: avSrc, alt: "", onerror: (e) => e.target.remove() }),
        el("div", { class: "pi-idcol" }, [
          el("div", { class: "pi-name" }, [p.username || "?"]),
          el("div", { class: "pi-title" }, [p.title || "No title"]),
          statusBadge(p.status),
          // Live spectate entry: another player who's mid-match right now. The server owns every
          // denial (privacy/ignore/type/cap) behind one generic spectate_result note.
          (!mine && p.status === "in match")
            ? el("button", { class: "clan-btn sm", onclick: () => { S.net.send("spectate", { username: p.username }); showToast("Joining as spectator…", "info"); } }, ["Watch"])
            : null,
        ]),
      ]),
      el("div", { class: "pi-clan" }, inClan ? [
        clanAvatar(p.clan_banner || "", "pi-clan-av"),
        el("div", { class: "pi-clan-name" }, [p.clan]),
      ] : [
        el("div", { class: "pi-clan-name pi-clanless" }, ["Clanless"]),
      ]),
    ]);
    const rankTxt = (p.rank != null && RANKS[p.rank] != null) ? divisionName(p.rank, p.tier) : "Unranked";
    const stat = (label, val) => el("div", { class: "profile-stat" }, [el("div", { class: "ps-label" }, [label]), el("div", { class: "ps-val" }, [String(val)])]);
    const statRow = el("div", { class: "profile-stats" }, [
      stat("Rating", Math.round(p.rating || 0)),
      stat("Record", (p.wins || 0) + "W " + (p.losses || 0) + "L"),
      stat("Streak", p.streak || 0),
      stat("Rank", rankTxt),
    ]);

    const top5 = (p.top_mastery || []).slice(0, 5);
    const masteryStrip = el("div", { class: "profile-mastery" }, top5.length ? top5.map((m) => {
      const kids = [];
      const thumb = portraitUrlFor(m.path);
      if (thumb) kids.push(el("img", { class: "mg-img", src: thumb, alt: "", onerror: (e) => e.target.remove() }));
      kids.push(el("div", { class: "mastery-badge" }, ["Lv " + (m.level || 0)]));
      return el("div", { class: "mg-cell mastery-cell", title: nameFor(m.path) + " · Lv " + (m.level || 0) }, kids);
    }) : [el("div", { class: "note" }, ["No mastery yet"])]);

    const teamPortraits = (paths) => el("div", { class: "ph-team" }, (paths || []).map((pn) => {
      const u = portraitUrlFor(pn);
      return u ? el("img", { class: "ph-por", src: u, alt: "", title: nameFor(pn), onerror: (e) => e.target.remove() }) : null;
    }));
    const hist = (p.match_history || []).slice().reverse();   // newest first
    const histList = el("div", { class: "ld-list profile-history", "data-scrollkey": "profile-hist" }, hist.length ? hist.map((h) =>
      el("div", { class: "ld-row ph-row" }, [
        el("div", { class: "ph-result " + (h.result === "win" ? "win" : "loss") }, [h.result === "win" ? "WIN" : "LOSS"]),
        el("div", { class: "ph-opp" }, ["vs " + (h.opponent || "?")]),
        el("div", { class: "ph-meta" }, [
          el("div", { class: "ph-mode" }, [PROFILE_MODE_LABEL[h.mode] || "Match"]),
          el("div", { class: "ph-date", title: h.date ? new Date(h.date * 1000).toLocaleString() : "" }, [timeAgo(h.date)]),
        ]),
        teamPortraits(h.opp_team),
        // Replays are participants-only (D3): only YOUR OWN history offers Watch, and only for
        // entries recorded since replays shipped (they carry match_uid).
        (mine && h.match_uid && h.mode !== 2)   // mode 2 = BOT: history records these but the server never persists their replays — no dead Watch buttons
          ? el("button", { class: "clan-btn sm ph-watch", onclick: () => { S.net.send("replay_fetch", { match_id: h.match_uid }); showToast("Loading replay…", "info"); } }, ["Watch"])
          : null,
      ])) : [el("div", { class: "note" }, ["No recent matches"])]);

    // Own profile: a header row pairing the section label with "Load replay file" (plays a saved
    // .replay locally — the counterpart to the viewer's Save, so replays survive a server wipe).
    const matchesHeader = mine
      ? el("div", { class: "profile-sec profile-sec-row" }, [
          el("span", {}, ["Recent Matches"]),
          el("button", { class: "clan-btn sm", title: "Play a .replay file saved on your device", onclick: loadReplayFromFile }, ["📂 Load replay file"]),
        ])
      : el("div", { class: "profile-sec" }, ["Recent Matches"]);
    const kids = [
      searchRow, identity, statRow,
      el("div", { class: "profile-sec" }, ["Top Mastery"]), masteryStrip,
      matchesHeader, histList,
    ];
    // Own profile only: a two-tap-guarded reset of your win/loss record + streak. The server
    // route (reset_own_record) always acts on the caller, so this is scoped to you regardless.
    if (mine) {
      kids.push(el("div", { class: "profile-danger" }, [
        el("button", { class: "clan-btn danger", onclick: () => {
          if (_profileResetArm) { _profileResetArm = false; S.net.send("reset_own_record", {}); set({ msg: "Resetting record…", msgKind: "" }); }
          else { _profileResetArm = true; set({ msg: "Tap again to confirm — this zeroes your W/L record and streak and can't be undone", msgKind: "err" }); }
        } }, [_profileResetArm ? "Confirm Reset?" : "Reset Win/Loss Record"]),
        el("div", { class: "profile-danger-note" }, ["Zeroes your wins, losses, streak, and rating. Unlocks, mastery, bounties, and AP are unaffected."]),
      ]));
    }
    return el("div", { class: "profile-menu" }, kids);
  }

  // Bounties — a 5x5 bingo card of 25 missions per character (generated server-side via the
  // bounty_missions route to avoid porting Godot's RNG). Progress is server-computed and arrives
  // in active_bounties; accept/cancel/reroll ride save_cosmetics, complete uses a reward route.
  const BOUNTY_REROLL_COST = 1500, BOUNTY_MAX_ACTIVE = 5, MASTERY_SUFFIX = "_mastery", BOUNTY_WIN_COST = 200;   // BOUNTY_WIN_COST: AP charged per win still REMAINING when auto-completing a square
  function bountyOwned(path) {
    const u = (S.player && S.player.unlocks) || [], st = (S.bountyData && S.bountyData.starters) || [];
    return st.includes(path) || u.includes(path + "_unlock") || u.includes("all_unlock");
  }
  function bountyKeyFor(path, tab) { return tab === "mastery" ? path + MASTERY_SUFFIX : path; }
  function bountyIsArchetype(t) { return !!(S.bountyData && S.bountyData.categories && (t in S.bountyData.categories)); }
  function bountyTargetText(t) {
    return bountyIsArchetype(t) ? "a " + titleCase(t) : nameFor(t);
  }
  function bountyTargetImg(t) {   // archetype -> category icon; character -> portrait
    return bountyIsArchetype(t) ? resToUrl("res://assets/bounty/" + t + ".png") : portraitUrlFor(t);
  }
  function missionText(m) {
    const type = m[0], tg = m[1] || [];
    if (type === "with") return "Win with " + bountyTargetText(tg[0]);
    if (type === "against") return "Win against " + bountyTargetText(tg[0]);
    if (type === "versus") return "Win with " + bountyTargetText(tg[0]) + " vs " + bountyTargetText(tg[1]);
    return type;
  }
  function bountyCompleted(progress, missions) {
    if (!progress || !missions || !S.bountyData) return false;
    // Guard missions[i]: a pattern can only complete if every cell it covers exists and is
    // met. A short/malformed missions array just means "not complete" rather than a throw.
    return (S.bountyData.winning_patterns || []).some((pat) => pat.every((i) => missions[i] && (progress[i] || 0) >= missions[i][2]));
  }
  function selectBounty(path, tab) {
    S.bountySel = path;
    if (tab) S.bountyTab = tab;
    const key = bountyKeyFor(path, S.bountyTab);
    if (!S.bountyMissions[key]) S.net.send("bounty_missions", { path: path, btype: S.bountyTab });   // server replies async
    render();
  }
  function acceptBounty(key) {
    if (Object.keys(S.player.active_bounties || {}).length >= BOUNTY_MAX_ACTIVE) return set({ msg: "Max " + BOUNTY_MAX_ACTIVE + " active bounties", msgKind: "bad" });
    S.player.active_bounties = S.player.active_bounties || {};
    S.player.active_bounties[key] = new Array(25).fill(0);
    saveCosmetics(); set({ msg: "Bounty accepted", msgKind: "ok" });
  }
  function cancelBounty(key) { delete (S.player.active_bounties || {})[key]; saveCosmetics(); set({ msg: "Bounty cancelled", msgKind: "" }); }
  function rerollBounty(key, path) {
    if (((S.player && S.player.ap) || 0) < BOUNTY_REROLL_COST) return set({ msg: "Need " + BOUNTY_REROLL_COST + " AP to reroll", msgKind: "bad" });
    S.player.bounty_rerolls = S.player.bounty_rerolls || {};
    S.player.bounty_rerolls[key] = (S.player.bounty_rerolls[key] || 0) + 1;
    S.player.ap -= BOUNTY_REROLL_COST;
    S.player.active_bounties[key] = new Array(25).fill(0);
    delete S.bountyMissions[key];                                  // new reroll seed -> new card
    saveCosmetics();
    S.net.send("bounty_missions", { path: path, btype: S.bountyTab });   // refetch the new card
    set({ msg: "Rerolled (−" + BOUNTY_REROLL_COST + " AP)", msgKind: "ok" });
  }
  function completeBounty(key) { S.net.send("complete_bounty", { bounty_path: key }); set({ msg: "Claiming…", msgKind: "ok" }); }  // server grants reward + echoes player update
  // AP cost to instantly finish a square = BOUNTY_WIN_COST (200) × the wins still REMAINING on it.
  // A fresh "win 2 games" square costs 400; with 1 win already banked it's 200. Reads live goal/progress,
  // so it always reflects wins earned the normal way. Returns 0 for an already-complete / unknown square.
  function bountySquareCost(key, square) {
    const missions = S.bountyMissions[key];
    const goal = (missions && missions[square]) ? missions[square][2] : 0;
    const prog = (S.player && S.player.active_bounties && S.player.active_bounties[key]) || [];
    const remaining = Math.max(0, goal - Math.floor(prog[square] || 0));
    return remaining * BOUNTY_WIN_COST;
  }
  // Pay AP to instantly finish one bounty square (sets its progress to the mission goal). Rides the
  // client-trusted save_cosmetics bridge exactly like rerollBounty — active_bounties + ap are the
  // client's to write; the reward claim (complete_bounty) is still validated server-side.
  function buyBountySquare(key, square) {
    if (key.endsWith(MASTERY_SUFFIX)) { set({ bountyBuy: null, msg: "Mastery bounties can't be bought — play the character", msgKind: "err" }); return; }  // AP-buy is unlock-only
    const missions = S.bountyMissions[key];
    if (!missions || !missions[square]) { set({ msg: "Bounty still loading — try again", msgKind: "err" }); return; }
    const goal = missions[square][2];
    S.player.active_bounties = S.player.active_bounties || {};
    const prog = (S.player.active_bounties[key] || new Array(25).fill(0)).slice();
    if ((prog[square] || 0) >= goal) { set({ bountyBuy: null, msg: "That square is already complete", msgKind: "" }); return; }
    const cost = bountySquareCost(key, square);   // computed before we mutate prog, so it's the remaining-wins cost
    const ap = (S.player && S.player.ap) || 0;
    if (ap < cost) { set({ msg: "Need " + fmtAp(cost) + " AP to complete this square", msgKind: "err" }); return; }
    prog[square] = goal;
    S.player.active_bounties[key] = prog;
    S.player.ap = ap - cost;
    saveCosmetics();
    set({ bountyBuy: null, msg: "Square completed (−" + fmtAp(cost) + " AP)", msgKind: "ok" });
  }
  function bountyBuyModal() {
    const b = S.bountyBuy;
    if (!b) return null;
    const cost = bountySquareCost(b.key, b.square);
    const remaining = cost / BOUNTY_WIN_COST;   // cost is always a whole multiple of BOUNTY_WIN_COST
    const ap = (S.player && S.player.ap) || 0;
    const canAfford = ap >= cost;
    const close = () => set({ bountyBuy: null });
    return el("div", { class: "modal-overlay", onclick: (e) => { if (e.target.classList.contains("modal-overlay")) close(); } }, [
      el("div", { class: "modal-panel bbuy-modal" }, [
        el("div", { class: "bbuy-title" }, ["Complete this square?"]),
        el("div", { class: "bbuy-note" }, ["Instantly finish this square for " + fmtAp(cost) + " AP — " + fmtAp(BOUNTY_WIN_COST) + " AP per remaining win (" + remaining + " left). You have " + fmtAp(ap) + " AP."]),
        el("div", { class: "bbuy-actions" }, [
          el("button", { class: "bty-btn buy", disabled: !canAfford, onclick: () => buyBountySquare(b.key, b.square) }, [canAfford ? "Complete −" + fmtAp(cost) + " AP" : "Not enough AP"]),
          el("button", { class: "bty-btn secondary", onclick: close }, ["Cancel"]),
        ]),
      ]),
    ]);
  }
  function bountyCard(path) {
    const tab = S.bountyTab, key = bountyKeyFor(path, tab);
    const cname = nameFor(path);
    const missions = S.bountyMissions[key];
    const active = (S.player && S.player.active_bounties) || {};
    const isActive = key in active;
    const progress = active[key] || new Array(25).fill(0);
    const head = el("div", { class: "bty-card-head" }, [
      el("div", { class: "bty-card-title" }, [cname + (tab === "mastery" ? " — Mastery" : " — Unlock")]),
      el("div", { class: "bty-reward" }, [tab === "mastery" ? "Reward: 5,000 AP + 1,000 Mastery XP" : "Reward: unlocks " + cname]),
    ]);
    // Mastery bounties require the bounty's OWN character on every win, on top of each
    // mission's generated requirement (server: check_bounty_progress returns nothing unless
    // bounty_target_path is on your team). Unlock bounties need only the generated requirement.
    const isMastery = tab === "mastery";
    const purl = portraitUrlFor(path);
    const masteryNote = isMastery ? el("div", { class: "bty-mastery-note" }, [
      purl ? el("img", { class: "bty-mn-img", src: purl, alt: "", onerror: (e) => e.target.remove() }) : null,
      el("span", { class: "bty-mn-text" }, ["Every mission also requires ", el("b", {}, [cname]), " on your team — in addition to the requirement each cell shows."]),
    ]) : null;
    let grid;
    if (!missions) grid = el("div", { class: "note bty-loading" }, ["Loading bounty…"]);
    else grid = el("div", { class: "bty-grid" }, missions.map((m, i) => {
      const goal = m[2], cnt = Math.floor(progress[i] || 0), done = cnt >= goal;
      const type = m[0], tg = m[1] || [];
      // A mission is one or two requirements: "with" -> use a target; "against" -> beat a
      // target; "versus" -> BOTH (with tg[0], against tg[1]). Show every requirement's symbol.
      let parts;
      if (type === "versus") parts = [{ k: "with", t: tg[0] }, { k: "against", t: tg[1] }];
      else if (type === "against") parts = [{ k: "against", t: tg[0] }];
      else parts = [{ k: "with", t: tg[0] }];
      parts = parts.filter((p) => p.t != null);
      const targetImg = (p) => {
        const u = bountyTargetImg(p.t), isCat = bountyIsArchetype(p.t);
        // Archetype symbols open the category browser so you can see who they cover.
        const openCat = isCat ? (e) => { e.stopPropagation(); set({ catView: p.t }); } : undefined;
        return u ? el("img", { class: (isCat ? "cat " : "") + "bty-tg-img", src: u, alt: "", title: isCat ? "See " + titleCase(p.t) + " characters" : undefined, onclick: openCat, onerror: (e) => (e.target.style.display = "none") })
          : el("div", { class: "bty-cell-tgt" + (isCat ? " catlink" : ""), onclick: openCat }, [bountyTargetText(p.t)]);
      };
      const cellKids = [];
      if (parts.length > 1) cellKids.push(el("div", { class: "bty-split" }, parts.map((p) => el("div", { class: "bty-half h-" + p.k }, [targetImg(p)]))));
      else if (parts.length === 1) cellKids.push(el("div", { class: "bty-cell-img" }, [targetImg(parts[0])]));
      // Type label: the WITH / AGAINST word(s) so the requirement reads at a glance.
      cellKids.push(el("div", { class: "bty-type" }, parts.flatMap((p, idx) => {
        const word = el("span", { class: "k-" + p.k }, [p.k === "with" ? "WITH" : "AGAINST"]);
        return idx > 0 ? [el("span", { class: "k-sep" }, ["⚔"]), word] : [word];
      })));
      cellKids.push(el("div", { class: "bty-cell-prog" }, [cnt + "/" + goal]));
      const buyable = isActive && !done && !isMastery;   // AP-buy is unlock-only; mastery must be earned
      const sqCost = buyable ? bountySquareCost(key, i) : 0;   // 200 AP × wins left on this square
      if (buyable) cellKids.push(el("div", { class: "bty-buy-hint" }, ["Complete −" + fmtAp(sqCost)]));
      const cellAttrs = { class: "bty-cell bty-" + type + (done ? " done" : "") + (buyable ? " buyable" : ""),
        title: missionText(m) + (isMastery ? " — and play " + cname : "") + " (" + cnt + "/" + goal + ")" + (buyable ? " — click to complete for " + fmtAp(sqCost) + " AP" : "") };
      if (buyable) cellAttrs.onclick = () => set({ bountyBuy: { key: key, square: i, path: path } });
      return el("div", cellAttrs, cellKids);
    }));
    const actions = [];
    const activeCount = Object.keys(active).length;
    if (tab === "unlock" && bountyOwned(path)) {
      // Already unlocked: never re-offer the unlock bounty (no Accept). Point at the Mastery bounty.
      actions.push(el("div", { class: "bty-owned-note" }, ["✓ " + cname + " is already unlocked"]));
      actions.push(el("button", { class: "bty-btn", onclick: () => selectBounty(path, "mastery") }, ["View Mastery Bounty →"]));
    } else {
      if (!isActive && activeCount < BOUNTY_MAX_ACTIVE) actions.push(el("button", { class: "bty-btn accept", onclick: () => acceptBounty(key) }, ["Accept"]));
      if (isActive) actions.push(el("button", { class: "bty-btn cancel", onclick: () => cancelBounty(key) }, ["Cancel"]));
      if (isActive && ((S.player && S.player.ap) || 0) >= BOUNTY_REROLL_COST) actions.push(el("button", { class: "bty-btn reroll", onclick: () => rerollBounty(key, path) }, ["Reroll −" + BOUNTY_REROLL_COST]));
      if (isActive && missions && bountyCompleted(progress, missions)) actions.push(el("button", { class: "bty-btn complete", onclick: () => completeBounty(key) }, ["Complete!"]));
    }
    return el("div", { class: "bty-card" }, [head, masteryNote, el("div", { class: "bty-actions" }, actions), grid]);
  }
  // Bounty character-list search. Mirrors applyCharFilter (char-select grid): the input writes
  // the off-render buffer S.btySearch and filters IN PLACE via each row's data-search, so typing
  // never re-renders (which would drop focus). Purely visual — it hides rows, so the selected
  // bounty card and its reroll/buy/claim actions are untouched by whatever is typed.
  // Match WORD PREFIXES, not raw substrings. data-search folds in the universe and category names,
  // so a plain .includes() matched mid-word — typing "as" surfaced Aang via "Avatar: The Last
  // Airbender". Each whitespace-separated term must prefix some token (AND across terms), so
  // "sung jin" still finds Sung Jin-woo, and "woo" still finds him via the "woo" token.
  function searchHit(hay, q) {
    const terms = q.split(/\s+/).filter(Boolean);
    if (!terms.length) return true;
    const tokens = (hay || "").split(/[^a-z0-9]+/).filter(Boolean);
    return terms.every((t) => tokens.some((tok) => tok.startsWith(t)));
  }
  function applyBountyFilter(listEl, q) {
    q = (q || "").trim().toLowerCase();
    let shown = 0;
    listEl.querySelectorAll(".bty-list-item").forEach((cell) => {
      const hit = !q || searchHit(cell.dataset.search || "", q);
      cell.style.display = hit ? "" : "none";
      if (hit) shown++;
    });
    const none = listEl.querySelector(".bty-list-none");
    if (none) none.style.display = shown ? "none" : "";
  }
  function bountiesMenu() {
    if (!S.roster || !S.roster.length) loadRoster();
    if (!S.bountyData) loadBountyData();
    const tab = S.bountyTab, p = S.player || {};
    const active = p.active_bounties || {};
    const tabsEl = el("div", { class: "bty-tabs" }, [["unlock", "Unlock"], ["mastery", "Mastery"]].map(([k, label]) =>
      el("button", { class: "bty-tab" + (tab === k ? " sel" : ""), onclick: () => set({ bountyTab: k, bountySel: null }) }, [label])));
    // active strip (<=5)
    const activeChips = Object.keys(active).map((key) => {
      const raw = key.endsWith(MASTERY_SUFFIX) ? key.slice(0, -MASTERY_SUFFIX.length) : key;
      const purl = portraitUrlFor(raw);
      const chip = el("div", { class: "bty-active-chip", title: raw + (key.endsWith(MASTERY_SUFFIX) ? " (mastery)" : " (unlock)") }, [
        purl ? el("img", { src: purl, alt: "", onerror: (e) => e.target.remove() }) : el("span", {}, [raw.slice(0, 3)]),
      ]);
      chip.addEventListener("click", () => selectBounty(raw, key.endsWith(MASTERY_SUFFIX) ? "mastery" : "unlock"));
      return chip;
    });
    const activeBar = el("div", { class: "bty-active" }, [
      el("span", { class: "bty-active-label" }, ["Active " + Object.keys(active).length + "/" + BOUNTY_MAX_ACTIVE + ":"]),
      ...(activeChips.length ? activeChips : [el("span", { class: "muted" }, ["none"])]),
    ]);
    // eligible character list for this tab
    const list = rosterByName().filter((r) => tab === "mastery" ? bountyOwned(r.path_name) : !bountyOwned(r.path_name));
    const rows = list.map((r) => {
      const key = bountyKeyFor(r.path_name, tab);
      const cell = el("button", { class: "bty-list-item" + (S.bountySel === r.path_name ? " sel" : "") + (key in active ? " active" : ""), title: r.name,
        // searchable text: display name, path name, universe, and the bounty categories the
        // character belongs to (so "brawler" finds every Brawler's bounty)
        "data-search": (r.name + " " + r.path_name + " " + (r.universe || "") + " " + categoriesFor(r.path_name).join(" ")).toLowerCase() }, [
        (() => { const u = portraitUrlFor(r.path_name); return u ? el("img", { class: "bty-li-img", src: u, alt: "", onerror: (e) => e.target.remove() }) : el("span", {}); })(),
        el("span", { class: "bty-li-name" }, [r.name]),
      ]);
      cell.addEventListener("click", () => selectBounty(r.path_name, tab));
      return cell;
    });
    const listEl = el("div", { class: "bty-list" }, rows.concat([el("div", { class: "bty-list-none" }, ["No characters match."])]));
    const searchIn = el("input", { class: "bty-search", "data-focus-id": "bounty-search", type: "text", placeholder: "Search characters…",
      value: S.btySearch || "", autocapitalize: "off", autocorrect: "off", spellcheck: "false",
      oninput: (e) => { S.btySearch = e.target.value; applyBountyFilter(listEl, e.target.value); syncClear(); } });
    const clearBtn = el("button", { class: "bty-search-x", title: "Clear search",
      onclick: () => { S.btySearch = ""; searchIn.value = ""; applyBountyFilter(listEl, ""); syncClear(); searchIn.focus(); } }, ["✕"]);
    const syncClear = () => { clearBtn.style.visibility = (S.btySearch || "") ? "visible" : "hidden"; };
    searchIn.addEventListener("keydown", (e) => {   // Esc clears without closing the overlay
      if (e.key === "Escape" && (S.btySearch || "")) { e.preventDefault(); e.stopPropagation(); S.btySearch = ""; searchIn.value = ""; applyBountyFilter(listEl, ""); syncClear(); }
    });
    syncClear();
    applyBountyFilter(listEl, S.btySearch);   // re-apply after every rebuild (keeps the filter across async pushes)
    const sideEl = el("div", { class: "bty-side" }, [el("div", { class: "bty-search-wrap" }, [searchIn, clearBtn]), listEl]);
    const right = S.bountySel ? bountyCard(S.bountySel) : el("div", { class: "note bty-empty" }, ["Select a character to view their bounty."]);
    const catNames = (S.bountyData && S.bountyData.categories) ? Object.keys(S.bountyData.categories).sort() : [];
    const catBtn = el("button", { class: "bty-cat-btn", disabled: !catNames.length, title: "Browse which characters belong to each category", onclick: () => set({ catView: catNames[0] }) }, ["▦ Categories"]);
    return el("div", { class: "bounties-menu" }, [
      el("div", { class: "bty-top" }, [tabsEl, activeBar, catBtn]),
      el("div", { class: "bty-intro" }, [
        el("div", {}, ["Each bounty is a 5×5 grid of missions for one character — win matches that satisfy a square's requirement to fill it in."]),
        el("div", {}, ["Complete any ", el("b", {}, ["single line"]), " — one full row, column, or diagonal — to finish the bounty and claim its AP reward. You don't need the whole grid."]),
        el("div", {}, ["In a hurry? Spend ", el("b", {}, ["AP"]), " to finish an individual mission instead — the cost rises with how many wins that mission still needs (", fmtAp(BOUNTY_WIN_COST), " per remaining win)."]),
      ]),
      el("div", { class: "bty-body" }, [sideEl, right]),
    ]);
  }
  // Category browser: which characters belong to each bounty category, so a symbol on a
  // card is legible. Opened from the "Categories" button or by clicking a card's archetype
  // icon (sets S.catView). Stacks over the bounty menu.
  function categoryModal() {
    const cats = (S.bountyData && S.bountyData.categories) || {};
    const names = Object.keys(cats).sort();
    const sel = (S.catView && cats[S.catView]) ? S.catView : (names[0] || null);
    const members = sel ? (cats[sel] || []) : [];
    const catIcon = (cat, cls) => el("img", { class: "cat-icon" + (cls ? " " + cls : ""), src: resToUrl("res://assets/bounty/" + cat + ".png"), alt: "", onerror: (e) => e.target.remove() });
    return el("div", { class: "modal-overlay", onclick: (e) => { if (e.target.classList.contains("modal-overlay")) set({ catView: null }); } }, [
      el("div", { class: "modal-panel cat-modal" }, [
        el("div", { class: "modal-head" }, [
          el("div", { class: "modal-title" }, ["Bounty Categories"]),
          el("button", { class: "modal-close", onclick: () => set({ catView: null }) }, ["✕"]),
        ]),
        el("div", { class: "cat-modal-body" }, [
          el("div", { class: "cat-list" }, names.map((cat) => {
            const row = el("div", { class: "cat-list-row" + (cat === sel ? " sel" : "") }, [
              catIcon(cat), el("span", { class: "cat-list-name" }, [titleCase(cat)]), el("span", { class: "cat-list-count" }, [String((cats[cat] || []).length)]),
            ]);
            row.addEventListener("click", () => set({ catView: cat }));
            return row;
          })),
          el("div", { class: "cat-members" }, sel ? [
            el("div", { class: "cat-members-head" }, [catIcon(sel, "big"), el("div", { class: "cat-members-title" }, [titleCase(sel)]), el("div", { class: "cat-members-sub" }, [members.length + " character" + (members.length === 1 ? "" : "s")])]),
            el("div", { class: "cat-members-grid" }, members.map((pn) => {
              const u = portraitUrlFor(pn);
              return el("div", { class: "cat-member", title: nameFor(pn) }, [
                u ? el("img", { class: "cat-member-img", src: u, alt: "", onerror: (e) => e.target.remove() }) : el("span", { class: "cat-member-img ph" }, [pn.slice(0, 2)]),
                el("span", { class: "cat-member-name" }, [nameFor(pn)]),
              ]);
            })),
          ] : [el("div", { class: "note" }, ["No categories loaded."])]),
        ]),
      ]),
    ]);
  }

  // Shop — buy cosmetics + character unlocks with AP. Purchase = ap -= price, unlocks.push(name),
  // save_cosmetics (client-trusted, mirroring make_unlockable_purchase). Owned items show "Owned".
  function shopOwned(unlock) {
    const u = (S.player && S.player.unlocks) || [];
    return u.includes(unlock) || u.includes("all_unlock");
  }
  function buyShopItem(unlock, price) {
    if (!S.player || shopOwned(unlock)) return set({ shopBuy: null });
    if (((S.player.ap) || 0) < price) return set({ shopBuy: null, msg: "Not enough AP", msgKind: "bad" });
    S.player.ap -= price;
    S.player.unlocks = (S.player.unlocks || []).concat([unlock]);
    saveCosmetics();
    set({ shopBuy: null, msg: "Purchased!", msgKind: "ok" });
  }
  function shopCard(it) {
    const unlock = it[0], img = it[2], name = it[3], price = it[4];
    const owned = shopOwned(unlock), afford = ((S.player && S.player.ap) || 0) >= price;
    const kids = [];
    if (img) kids.push(el("img", { class: "shop-img", src: resToUrl(img), alt: "", onerror: (e) => (e.target.style.visibility = "hidden") }));
    kids.push(el("div", { class: "shop-name" }, [name]));
    if (owned) kids.push(el("div", { class: "shop-owned" }, ["✓ Owned"]));
    else kids.push(el("button", { class: "shop-buy" + (afford ? "" : " off"), disabled: !afford, onclick: () => set({ shopBuy: { unlock: unlock, name: name, price: price } }) }, [fmtAp(price) + " AP"]));
    return el("div", { class: "shop-card" + (owned ? " owned" : "") }, kids);
  }
  function shopConfirm() {
    const b = S.shopBuy;
    return el("div", { class: "nx-popup-overlay", onclick: (e) => { if (e.target.classList.contains("nx-popup-overlay")) set({ shopBuy: null }); } }, [
      el("div", { class: "nx-popup" }, [
        el("div", { class: "nx-popup-title" }, ["Purchase " + b.name + "?"]),
        el("div", { class: "nx-popup-sub" }, [fmtAp(b.price) + " AP   ·   You have " + fmtAp((S.player && S.player.ap) || 0)]),
        el("div", { class: "nx-popup-actions" }, [
          el("button", { class: "nx-cancel", onclick: () => set({ shopBuy: null }) }, ["Cancel"]),
          el("button", { class: "nx-confirm", onclick: () => buyShopItem(b.unlock, b.price) }, ["Buy"]),
        ]),
      ]),
    ]);
  }
  function shopMenu() {
    if (!S.shopCatalog) { loadShopCatalog(); return el("div", { class: "note shop-loading" }, ["Loading shop…"]); }
    if (!S.roster || !S.roster.length) loadRoster();
    // Characters are no longer sold here; character frames ("portrait") are pulled for now.
    const SHOP_HIDDEN = ["character", "portrait"];
    const order = (S.shopCatalog.order || Object.keys(S.shopCatalog.items)).filter((k) => SHOP_HIDDEN.indexOf(k) < 0);
    let cat = S.shopTab;
    if (order.indexOf(cat) < 0) cat = order[0];   // active tab was hidden -> fall back to the first visible one
    const items = S.shopCatalog.items[cat] || [];
    const ownedCount = items.filter((it) => shopOwned(it[0])).length;
    const tabsEl = el("div", { class: "shop-tabs" }, order.map((k) =>
      el("button", { class: "shop-tab" + (cat === k ? " sel" : ""), onclick: () => set({ shopTab: k }) }, [(S.shopCatalog.display_names || {})[k] || k])));
    const kids = [
      el("div", { class: "shop-header" }, [
        el("div", { class: "shop-ap" }, ["Your AP: ", el("b", {}, [fmtAp((S.player && S.player.ap) || 0)])]),
        el("div", { class: "shop-count" }, [ownedCount + " / " + items.length + " owned"]),
      ]),
      tabsEl,
      el("div", { class: "shop-grid shop-grid-" + cat }, items.map((it) => shopCard(it))),
    ];
    if (S.shopBuy) kids.push(shopConfirm());
    return el("div", { class: "shop-menu" }, kids);
  }

  // Dev handle: inspect/drive from the browser console (window.AA.state, window.AA.render()).
  // `fns`/`consts` expose the non-battle internals to the test harness (tests.html); they
  // are a dev/test surface only (the server is authoritative — same trust model as `state`).
  window.AA = {
    state: S, render: render, net: S.net, set: set,
    fns: {
      // mastery / xp / cosmetics
      xpToLevel, levelProgressFraction, xpIntoLevel, xpNeededForLevel, masteryLevel, masteryCosmeticId,
      isCosmeticEquipped, isCosmeticEquippedSlot, equipCosmetic, makeCosmeticUpdate, saveCosmetics, defaultPreviewPath, cosmeticUrl,
      equipBackground, backgroundUrl, bgStyle, backgroundSection,
      // generic helpers
      titleCase, titleName, nameFor, portraitUrlFor, relToUrl, resToUrl, abilityIconUrl,
      resolveAbilityKey, ingestSnapshot,
      charUnlocked, charAbilities, charAbilitySearchText, categoriesFor, prettyUniverse, fmtAp, rosterByName,
      // char select
      applyCharFilter, toggleChar, randomizeTeam, selectAndInspect, toggleTeamMember,
      loadSavedTeamsList, saveCurrentTeam, loadSavedTeam, deleteSavedTeam, changePassword, applyAvatar, queuePrivate, battleViewportContent,
      // bounties
      bountyOwned, bountyKeyFor, bountyIsArchetype, bountyTargetText, bountyTargetImg, missionText,
      bountyCompleted, acceptBounty, cancelBounty, rerollBounty, completeBounty, selectBounty, buyBountySquare, bountySquareCost, applyBountyFilter,
      // nexus
      doDonate,
      // shop
      shopOwned, buyShopItem,
      // titles
      unlockedTitleWords, addTitleWord, removeTitleWord, saveTitle,
      // session / net handlers
      onMatch, finishReconnect,
      // viewer (replay/spectate)
      enterReplay, viewerExit, replayStep,
      // ui primitives / scaffolds
      showToast, badgeChip, isViewer, syncSocialUI,
      // renderers (resilience: must not throw on empty/partial/malformed state)
      menuInfoPanel, playerPanel, gameOverModal, divisionName, divisionChangeBanner, isRankedMatch, matchApGain, rankBadge, gridArea, masteryMenu, masteryDetail, cosmeticsMenu,
      nexusMenu, bountiesMenu, bountyCard, titleMenu, shopMenu, ladderMenu, settingsMenu, categoryModal, clanMenu, clanMyView,
    },
    consts: {
      XP_THRESHOLDS, MAX_LEVEL, UNLOCK_THRESHOLDS, MASTERY_REWARDS, RANKS,
      BASE_TITLE_WORDS, MAX_TITLE_WORDS, MASTERY_SUFFIX, BOUNTY_REROLL_COST, BOUNTY_MAX_ACTIVE, CHAR_SELECT_ORDER,
    },
  };

  setInterval(() => {   // drain the cosmetic turn-timer bar without re-rendering
    const fill = document.querySelector(".timer-fill");
    if (fill && _timerStart) fill.style.width = (Math.max(0, 1 - (Date.now() - _timerStart) / turnTimerMs()) * 100) + "%";
    // Draft phase countdown (server-authoritative deadline; this is display only).
    if (S.screen === "draft" && S.draft && S.draft.deadline) {
      const total = S.draft.phase === "BAN" ? 60 : 30;
      const left = Math.max(0, S.draft.deadline - Date.now() / 1000);
      const dfill = document.querySelector(".draft-timer-fill");
      if (dfill) dfill.style.width = Math.min(100, (left / total) * 100) + "%";
      const dtxt = document.querySelector(".draft-timer-txt");
      if (dtxt) dtxt.textContent = Math.ceil(left) + "s";
    }
  }, 250);
  // Kill native image/link drag everywhere. Otherwise pressing an image and moving the pointer a
  // few px starts a browser drag (ghost image + no-entry cursor) that swallows the click — eating
  // taps on portraits, ability tiles, and effect icons. Nothing here uses HTML5 drag (the exec-order
  // reorder is pointer-based), so a blanket preventDefault is safe and needs no per-image attribute.
  document.addEventListener("dragstart", (e) => e.preventDefault());
  // Tap-outside dismissal for the effect panel (mobile, where there's no mouseleave).
  // A press outside every popover and keyword dismisses the unpinned ones (pinned panels persist
  // until their × is clicked). Covers the effect panel and the whole glossary chain uniformly.
  document.addEventListener("pointerdown", (e) => {
    if (e.target.closest && e.target.closest(".gk-panel, .eff-panel, .gk, .eff")) return;   // .eff = the effect icon, a legit trigger
    GK.closeUnpinned();
  });
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && S.targeting) set({ targeting: null }); });   // Esc cancels target selection
  // Re-fit the battle zoom when the phone rotates / the viewport changes. fitBattleViewport only
  // rewrites the meta if the target actually changed, so this never fights a pinch-zoom within an
  // orientation — and no full re-render is needed (the board is a fixed design, only the zoom moves).
  window.addEventListener("resize", fitBattleViewport);
  if (window.screen && window.screen.orientation && window.screen.orientation.addEventListener)
    window.screen.orientation.addEventListener("change", fitBattleViewport);
  document.addEventListener("DOMContentLoaded", () => {
    SFX.preload();
    // Global UI sound listeners — attached to `document` (capture phase) so they survive render()'s full
    // #app teardown and cover every button without per-widget wiring. Character/mastery tiles play the
    // "select" thunk (Godot: character_click); buttons + battle ability tiles play the click.
    document.addEventListener("click", (e) => {
      if (e.target.closest(".vol-ctl")) return;   // the volume control provides its own audio feedback
      if (e.target.closest(".mg-cell")) SFX.play("select");
      else if (e.target.closest("button, .ab-wrap")) SFX.play("click");
    }, true);
    let _sfxHover = null;   // only re-fire when the hovered element actually changes (no rapid retrigger)
    document.addEventListener("mouseover", (e) => {
      if (e.target.closest(".vol-ctl")) { _sfxHover = null; return; }
      const t = e.target.closest("button, .ab-wrap");
      if (t) { if (t !== _sfxHover) { _sfxHover = t; SFX.play("hover"); } } else _sfxHover = null;
    }, true);
    loadRoster(); loadPortraits(); loadCharIndex(); loadAbilityIcons(); loadAbilityInfo(); loadAbilityAliases(); loadTitles(); loadBountyData(); loadShopCatalog(); render();
    const saved = loadSavedLogin();
    if (saved) doLogin(defaultServerUrl(), saved.user, saved.pass, true);   // "keep me logged in" — silent auto-login on load
  });
})();
