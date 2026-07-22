#!/usr/bin/env node
"use strict";

// Regenerate the plugin marketplace payloads from the skill source of truth.
//
// Each skill is authored once under skills/<name>/. The GitHub /plugin
// marketplace route (`/plugin marketplace add ehmo/slopkit`) reads files
// straight from plugins/<name>/skills/<name>/ in a plain clone, so those files
// must physically exist in the repo. Rather than hand-copy them — which drifts
// (the mirror lost the v1.4.0 Orwell docs once) — this script derives them.
//
// The plugin payload is skills/<name>/ minus:
//   - *.ps1            plugins run the Python scripts; the PowerShell twins are
//                      only for the native PowerShell edition
//   - repo/package tooling scripts that never run for an installed skill
//   - Python bytecode caches
//
// CI runs this then `git diff --exit-code -- plugins/`; a non-empty diff means
// someone edited skills/ without regenerating the mirror.

const fs = require("fs");
const path = require("path");
const { SKILLS, includeInPluginPayload } = require("../bin/slopkit.js");

const root = path.resolve(__dirname, "..");
const SKILL_NAMES = SKILLS.map((skill) => skill.name);

function regenerate(name) {
  const src = path.join(root, "skills", name);
  const dest = path.join(root, "plugins", name, "skills", name);
  if (!fs.existsSync(src)) {
    throw new Error(`missing skill source: ${path.relative(root, src)}`);
  }
  fs.rmSync(dest, { force: true, recursive: true });
  fs.cpSync(src, dest, { recursive: true, filter: includeInPluginPayload });
}

for (const name of SKILL_NAMES) {
  regenerate(name);
}

console.log(`plugin mirror regenerated from skills/: ${SKILL_NAMES.join(", ")}`);
