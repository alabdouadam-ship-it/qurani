// Post-build fixup for `next build` (output: "export") on static hosting.
//
// WHY: Next 16's client router prefetches React Server Component segment
// payloads. For each route it writes the page segment into a SUBFOLDER:
//     out/<route>/__next.<route>/__PAGE__.txt
// but the client requests it as a FLAT, dot-separated file:
//     /<route>/__next.<route>.__PAGE__.txt
// On a plain static host (Firebase Hosting) that path 404s, the router throws,
// and the page fails to load. (The non-page segment file __next.<route>.txt is
// already flat and works — only __PAGE__ is nested.)
//
// This copies every `**/__next.*/__PAGE__.txt` to the flat dotted name the
// client expects, so both forms resolve. Safe + idempotent; re-run every build.

import { readdirSync, statSync, copyFileSync } from "node:fs";
import { join, dirname, basename } from "node:path";

const OUT = "out";
let fixed = 0;

/** Recursively walk `dir`, invoking `onFile(fullPath)` for every file. */
function walk(dir, onFile) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) walk(full, onFile);
    else onFile(full);
  }
}

walk(OUT, (file) => {
  if (basename(file) !== "__PAGE__.txt") return;
  const segDir = dirname(file); // .../<route>/__next.<route>
  const segName = basename(segDir); // __next.<route>
  if (!segName.startsWith("__next.")) return;
  // Flat sibling next to the segment folder: <parent>/__next.<route>.__PAGE__.txt
  const flat = join(dirname(segDir), `${segName}.__PAGE__.txt`);
  copyFileSync(file, flat);
  fixed++;
});

console.log(`✓ fix-export-rsc: created ${fixed} flat __PAGE__ RSC file(s).`);
