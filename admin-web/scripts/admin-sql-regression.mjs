// Integration test for a disposable LOCAL PostgreSQL instance only.
// Usage: node scripts/admin-sql-regression.mjs <path-to-psql> <local-port>
// Creates a dedicated database; never reads application environment files.
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const [psql, port] = process.argv.slice(2);
assert.ok(psql && /^\d+$/.test(port ?? ""), "Supply psql path and local port");
function sql(input, database = "qurani_admin_regression") {
  return new Promise((resolve, reject) => {
    const child = spawn(psql, ["-X", "-h", "127.0.0.1", "-p", port, "-U", "postgres", "-d", database, "-v", "ON_ERROR_STOP=1", "-At"], { windowsHide: true });
    let out = "", err = "";
    child.stdout.on("data", data => { out += data; });
    child.stderr.on("data", data => { err += data; });
    child.on("error", reject);
    child.on("exit", code => resolve({ code, out: out.trim(), err }));
    child.stdin.end(input);
  });
}
async function ok(input, database) {
  const result = await sql(input, database);
  assert.equal(result.code, 0, result.err);
  return result.out;
}
const a = "00000000-0000-0000-0000-000000000001";
const b = "00000000-0000-0000-0000-000000000002";
await ok("create database qurani_admin_regression;", "postgres");
await ok(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create function auth.role() returns text language sql stable as
    $$ select current_setting('request.jwt.claim.role', true) $$;
  grant usage on schema auth to authenticated;
  create table auth.users(id uuid primary key);
  insert into auth.users values ('${a}'), ('${b}');
  create table public.news_items(id text primary key, target_languages text[] not null default '{}',
    target_countries text[] not null default '{}', excluded_countries text[] not null default '{}', updated_by text);
  create table public.reciters(updated_by text);
`);
const oldAdmin = readFileSync("../supabase/migrations/20260605000004_admin.sql", "utf8");
await ok(oldAdmin.slice(0, oldAdmin.indexOf("-- Change-attribution columns")));
await ok("grant select, insert, update on public.admins to authenticated;");
await ok(readFileSync("../supabase/migrations/20260831000003_attribution_and_last_admin.sql", "utf8"));
await ok(readFileSync("../supabase/migrations/20261104000001_admin_concurrency_and_news_arrays.sql", "utf8"));

function bootstrap(id) {
  return `begin; set local role authenticated;
    set local request.jwt.claim.role = 'authenticated';
    set local request.jwt.claim.sub = '${id}';
    insert into public.admins(id,name) values ('${id}','First');
    select pg_sleep(0.4); commit;`;
}
const first = await Promise.all([sql(bootstrap(a)), sql(bootstrap(b))]);
assert.equal(first.filter(r => r.code === 0).length, 1, JSON.stringify(first));
assert.equal(await ok("select count(*) from public.admins;"), "1");
console.log("PASS: concurrent first-admin registrations admit exactly one account (with RLS).");

await ok(`insert into public.admins(id,name) values ('${a}','A'),('${b}','B')
  on conflict(id) do update set name=excluded.name;`);
assert.equal(await ok("select members from public.admin_membership_guard;"), "2");
console.log("PASS: upsert does not inflate the membership counter.");
const deletes = await Promise.all([a, b].map(id => sql(`begin;
  delete from public.admins where id='${id}'; select pg_sleep(0.4); commit;`)));
assert.equal(deletes.filter(r => r.code === 0).length, 1, JSON.stringify(deletes));
assert.equal(await ok("select count(*) from public.admins;"), "1");
assert.equal(await ok("select members from public.admin_membership_guard;"), "1");
console.log("PASS: concurrent deletions preserve the last admin and a consistent counter.");

assert.notEqual((await sql("delete from auth.users where id in (select id from public.admins);")).code, 0);
assert.notEqual((await sql("truncate public.admins;")).code, 0);
assert.equal(await ok("select count(*) from public.admins;"), "1");
console.log("PASS: auth-user cascade and TRUNCATE cannot remove the last admin.");

await ok(`insert into public.admins(id,name) values ('${a}','A'),('${b}','B')
  on conflict(id) do update set name=excluded.name;`);
await ok(`begin; delete from public.admins where id='${a}'; rollback;`);
assert.equal(await ok("select members from public.admin_membership_guard;"), "2");
assert.notEqual((await sql("set role authenticated; update public.admin_membership_guard set members=100;")).code, 0);
console.log("PASS: rollback restores the counter; browser roles cannot change it.");

await ok("insert into news_items(id,target_languages) values ('good',array['ar']);");
assert.notEqual((await sql("insert into news_items(id,target_languages) values ('bad',array[null]::text[]);")).code, 0);
console.log("PASS: null targeting elements are rejected, valid targeting is accepted.");
