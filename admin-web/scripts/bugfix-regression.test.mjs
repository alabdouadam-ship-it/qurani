// Offline regression tests. Execute real TS modules/handlers without a browser
// or Supabase credentials; database promises are deliberately controlled.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import ts from "typescript";
import { resolve, dirname } from "node:path";

function compile(source) {
  return ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX,
  } }).outputText;
}
function load(file, globals = {}) {
  const path = resolve(file);
  const exports = {};
  vm.runInNewContext(compile(readFileSync(path, "utf8")), {
    exports, ...globals,
    require: name => load(resolve(dirname(path), name + ".ts"), globals),
  });
  return exports;
}
function handler(file, name, globals) {
  const source = ts.createSourceFile(file, readFileSync(file, "utf8"), 99, true, ts.ScriptKind.TSX);
  let fn;
  function visit(node) {
    if (ts.isFunctionDeclaration(node) && node.name?.text === name) fn = node.getText(source);
    ts.forEachChild(node, visit);
  }
  visit(source);
  assert.ok(fn, name);
  const context = vm.createContext(globals);
  vm.runInContext(compile(fn), context);
  return context[name];
}

test("null targeting fails closed, without a null dereference", () => {
  const { newsVisibility } = load("src/lib/news-visibility.ts");
  for (const target_languages of [[null], ["ar", null], "ar"]) {
    const result = newsVisibility({ target_languages, category_ar: null, category_en: null, category_fr: null });
    assert.equal(result.visible.length, 0);
  }
  assert.equal(newsVisibility({ target_languages: null }).visible.length, 3);
  assert.equal(newsVisibility({ target_languages: ["fr"] }).visible.join(), "fr");
});

test("malformed statistics and filter options cannot break rendering", () => {
  const { normalizeStats } = load("src/lib/stats-data.ts");
  const { normalizeStatsOptions } = load("src/lib/stats-filter.ts");
  const stats = normalizeStats({ features: [null, { feature: "read", avgMin: null }], daily: [null], totalInstalls: Infinity });
  assert.equal(stats.features[0].avgMin.toFixed(1), "0.0");
  assert.equal(stats.daily.length, 0);
  assert.equal(stats.totalInstalls, 0);
  const options = normalizeStatsOptions({ platforms: null, countries: [null, "FR"], firstDay: {} });
  assert.equal(options.platforms.length, 0);
  assert.equal(options.countries.join(), "FR");
  assert.equal(options.firstDay, null);
});

test("late work cannot replace a newer result or a signed-out state", async () => {
  const { LatestRequest } = load("src/lib/latest-request.ts");
  const gate = new LatestRequest();
  let state = "signed-in";
  let finish;
  const pending = new Promise(resolve => { finish = resolve; });
  const current = gate.begin();
  const old = pending.then(() => { if (current()) state = "old-admin"; });
  gate.invalidate();
  state = "signed-out";
  finish();
  await old;
  assert.equal(state, "signed-out");
  const first = gate.begin();
  const last = gate.begin();
  assert.equal(first(), false);
  assert.equal(last(), true);
});

test("blocked storage leaves preferences usable in memory", () => {
  const storage = { getItem() { throw Error("denied"); }, setItem() { throw Error("quota"); } };
  const { readPreference, writePreference } = load("src/lib/safe-storage.ts", { localStorage: storage });
  assert.equal(readPreference("language"), null);
  assert.doesNotThrow(() => writePreference("language", "ar"));
});

test("AuthProvider ignores profiles after sign-out and preserves forms on same-user refresh", async () => {
  const states = [], effects = [], timers = [], queries = [];
  let onAuth, slot = 0;
  const supabase = {
    auth: {
      getSession: () => new Promise(() => {}),
      onAuthStateChange: cb => { onAuth = cb; return { data: { subscription: { unsubscribe() {} } } }; },
      signOut: async () => ({ error: null }),
    },
    from: () => ({ select() { return this; }, eq() { return this; },
      maybeSingle: () => new Promise(resolve => queries.push(resolve)),
    }),
  };
  const react = {
    createContext: () => ({ Provider: "provider" }),
    useState(initial) {
      const index = slot++;
      states[index] = initial;
      return [initial, v => { states[index] = typeof v === "function" ? v(states[index]) : v; }];
    },
    useRef: current => ({ current }), useCallback: fn => fn, useEffect: fn => effects.push(fn),
  };
  const exports = {};
  vm.runInNewContext(compile(readFileSync("src/lib/auth-context.tsx", "utf8")), {
    exports, setTimeout: fn => timers.push(fn),
    require: name => {
      if (name === "react") return react;
      if (name === "react/jsx-runtime") return { jsx: (type, props) => ({ type, props }) };
      if (name === "./supabase") return { getSupabase: () => supabase };
      if (name === "./latest-request") return load("src/lib/latest-request.ts");
      throw Error(name);
    },
  });
  const provider = exports.AuthProvider({ children: null });
  const cleanup = effects[0]();
  const session = { user: { id: "admin-A" } };
  onAuth("SIGNED_IN", session); timers.shift()();
  queries.shift()({ data: { id: "admin-A", name: "A" }, error: null });
  await new Promise(setImmediate);
  assert.equal(states[0], false);
  assert.equal(states[2].id, "admin-A");
  onAuth("TOKEN_REFRESHED", session); timers.shift()();
  assert.equal(states[0], false, "same-user refresh must not unmount the account form");
  await provider.props.value.signOut();
  queries.shift()({ data: { id: "admin-A", name: "A" }, error: null });
  await new Promise(setImmediate);
  assert.equal(states[1], null);
  assert.equal(states[2], null);
  onAuth("SIGNED_IN", session); timers.shift()();
  cleanup();
  queries.shift()({ data: { id: "admin-A", name: "A" }, error: null });
  await new Promise(setImmediate);
  assert.equal(states[2], null, "unmounted provider must ignore the late profile");
});

function queryMock(response) {
  const calls = [];
  const q = {};
  for (const method of ["from", "insert", "update", "delete", "eq"]) {
    q[method] = (...args) => { calls.push([method, ...args]); return q; };
  }
  q.select = async () => {
    if (response instanceof Error) throw response;
    return response;
  };
  return { q, calls };
}
for (const [label, isNew, response, expected] of [
  ["duplicate insertion", true, { data: null, error: { code: "23505" } }, "duplicate"],
  ["deleted item", false, { data: [], error: null }, "missing"],
  ["network failure", true, new Error("offline"), "failed"],
  ["successful update", false, { data: [{ code: "a" }], error: null }, null],
]) {
  test(`reciter save: ${label}`, async () => {
    const { q, calls } = queryMock(response);
    let error, saved = false, busy;
    const save = handler("src/app/reciters/page.tsx", "save", {
      r: { code: "a", surahs_path: null }, initial: { code: "a" }, isNew, adminName: "Admin",
      supabase: q, t: { duplicateCode: "duplicate", itemMissing: "missing", saveFailed: "failed" },
      setError: v => { error = v; }, setBusy: v => { busy = v; }, onSaved: () => { saved = true; },
    });
    await save({ preventDefault() {} });
    assert.equal(error, expected);
    assert.equal(saved, expected === null);
    assert.equal(busy, false);
    assert.equal(calls.some(c => c[0] === "insert"), isNew);
    assert.equal(calls.some(c => c[0] === "update"), !isNew);
  });
}

for (const [file, name] of [["news", "remove"], ["reciters", "remove"], ["reciters", "disable"]]) {
  for (const response of [{ data: null, error: { message: "denied" } }, { data: [], error: null }, new Error("offline")]) {
    test(`${file}/${name}: failed mutation keeps confirmation open (${response instanceof Error ? "throw" : response.error ? "API" : "zero rows"})`, async () => {
      const { q } = queryMock(response);
      let closed = false, failure = false, success = false, busy;
      const action = handler(`src/app/${file}/page.tsx`, name, {
        supabase: q, t: { reciterDisabled: "disabled" },
        setBusy: v => { busy = v; }, setActionError: v => { failure = v; },
        setPendingDelete: () => { closed = true; }, setNotice: v => { if (v) success = true; },
        load: async () => { throw Error("must not reload after failure"); },
      });
      await action({ id: "a", code: "a" });
      assert.equal(failure, true);
      assert.equal(closed, false);
      assert.equal(success, false);
      assert.equal(busy, false);
    });
  }
}
