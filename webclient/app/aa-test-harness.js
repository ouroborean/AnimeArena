// aa-test-harness.js — tiny browser test runner for the non-battle web-client mechanics.
// Loaded by tests.html AFTER net.js + app.js (so window.AA exists) and BEFORE the suite
// files (which register cases via AATest.test). Waits for the app's data loaders to land,
// then runs every registered test against the REAL app code, resetting session state
// between tests. Results render into #results and are mirrored to window.__AATEST so the
// run can be checked headlessly (preview_eval).
(function () {
  "use strict";
  const A = window.AA;
  if (!A) { document.getElementById("results").textContent = "FATAL: window.AA missing (app.js failed to load)"; return; }

  const T = { tests: [], results: [], pass: 0, fail: 0 };
  let BASELINE = null;     // cloned clean session state
  let DATA_REFS = null;    // references to the loaded reference data (restored — not cloned — per reset)
  // Read-only reference data the loaders fetch once — never cloned/reset (big + immutable).
  const DATA = ["roster", "abilityInfo", "bountyData", "titles", "portraits", "charIndex", "abilityIcons", "abilityAliases", "shopCatalog"];

  function test(name, fn) { T.tests.push({ name: name, fn: fn }); }
  function fail(msg) { throw new Error(msg); }
  function assert(cond, msg) { if (!cond) fail("assert failed: " + (msg || "")); }
  function eq(a, b, msg) { if (a !== b) fail((msg || "eq") + " — expected " + j(b) + ", got " + j(a)); }
  function deepEq(a, b, msg) { if (j(a) !== j(b)) fail((msg || "deepEq") + " — expected " + j(b) + ", got " + j(a)); }
  function near(a, b, eps, msg) { if (Math.abs(a - b) > (eps == null ? 1e-6 : eps)) fail((msg || "near") + " — " + a + " !~ " + b); }
  function noThrow(fn, msg) { try { return fn(); } catch (e) { fail((msg || "noThrow") + " — threw: " + (e && e.message)); } }
  function throws(fn, msg) { try { fn(); } catch (e) { return; } fail((msg || "throws") + " — did not throw"); }
  function j(v) { try { return JSON.stringify(v); } catch (e) { return String(v); } }

  // ---- state control -------------------------------------------------------
  function snapshot() {
    const s = A.state, out = {};
    for (const k in s) {
      if (k === "net" || DATA.indexOf(k) >= 0) continue;
      try { out[k] = JSON.parse(JSON.stringify(s[k])); } catch (e) { out[k] = s[k]; }
    }
    return out;
  }
  // Restore the session state to the clean baseline (data fields + net are left intact),
  // install a capturing net.send mock, and apply any per-test overrides.
  function resetState(overrides) {
    const s = A.state;
    for (const k in BASELINE) { try { s[k] = JSON.parse(JSON.stringify(BASELINE[k])); } catch (e) { s[k] = BASELINE[k]; } }
    // Re-point the loaded reference data (roster/abilityInfo/…) — a prior test may have
    // overridden e.g. {roster: []} to probe a no-data path; that must not leak forward.
    if (DATA_REFS) for (const k in DATA_REFS) s[k] = DATA_REFS[k];
    window.__sent = [];
    s.net.send = function (type, payload) { window.__sent.push({ type: type, payload: payload }); return false; };
    if (overrides) for (const k in overrides) s[k] = overrides[k];
    return s;
  }
  function emit(type, payload) { return A.net._emit(type, Object.assign({ type: type }, payload || {})); }
  function sentOfType(type) { return (window.__sent || []).filter(function (m) { return m.type === type; }); }
  function lastSent(type) { const a = window.__sent || []; for (let i = a.length - 1; i >= 0; i--) if (!type || a[i].type === type) return a[i]; return null; }

  function dataReady() {
    const s = A.state;
    return !!(s.roster && s.bountyData && s.titles && s.abilityInfo && s.shopCatalog && s.portraits && s.charIndex && s.abilityIcons && s.abilityAliases);
  }

  async function runAll() {
    BASELINE = snapshot();
    DATA_REFS = {};
    DATA.forEach(function (k) { DATA_REFS[k] = A.state[k]; });
    for (const t of T.tests) {
      resetState();
      try { await t.fn(); T.pass++; T.results.push({ name: t.name, ok: true }); }
      catch (e) { T.fail++; T.results.push({ name: t.name, ok: false, err: (e && e.message) || String(e) }); }
    }
    resetState();   // leave the app in a clean state
    report();
  }

  function report() {
    window.__AATEST = {
      done: true, total: T.tests.length, pass: T.pass, fail: T.fail, dataReady: dataReady(),
      failures: T.results.filter(function (r) { return !r.ok; }).map(function (r) { return { name: r.name, err: r.err }; }),
    };
    const root = document.getElementById("results");
    if (!root) { console.log("[AATEST]", window.__AATEST); return; }
    root.innerHTML = "";
    const head = document.createElement("div");
    head.style.cssText = "font:bold 15px monospace;padding:10px;color:" + (T.fail ? "#e8736b" : "#5fcf7f");
    head.textContent = (T.fail ? (T.fail + " FAILED") : "ALL PASSED") + " — " + T.pass + "/" + T.total + (dataReady() ? "" : "  (data NOT ready!)");
    root.appendChild(head);
    T.results.forEach(function (r) {
      const d = document.createElement("div");
      d.style.cssText = "font:12px/1.5 monospace;padding:1px 12px;color:" + (r.ok ? "#7f8a9a" : "#e8736b");
      d.textContent = (r.ok ? "✓ " : "✗ ") + r.name + (r.ok ? "" : "  — " + r.err);
      root.appendChild(d);
    });
    console.log("[AATEST]", window.__AATEST);
  }

  window.AATest = {
    test: test, assert: assert, eq: eq, deepEq: deepEq, near: near, noThrow: noThrow, throws: throws, fail: fail,
    resetState: resetState, emit: emit, sentOfType: sentOfType, lastSent: lastSent,
    S: A.state, fns: A.fns, consts: A.consts, render: A.render,
  };

  // Boot: wait for window.AA + the data loaders (app.js fires them on DOMContentLoaded),
  // then run. ~8s max wait, then run anyway (report flags data NOT ready).
  function boot(tries) {
    if ((!window.AA || !dataReady()) && tries > 0) return setTimeout(function () { boot(tries - 1); }, 50);
    runAll();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", function () { setTimeout(function () { boot(160); }, 60); });
  else setTimeout(function () { boot(160); }, 60);
})();
