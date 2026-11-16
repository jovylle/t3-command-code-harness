#!/usr/bin/env bash
# Remove the Command Code provider from T3 Code.
set -euo pipefail

SETTINGS="${T3_SETTINGS:-$HOME/.t3/userdata/settings.json}"
KEY="acpRegistry_command_code"
CACHE="${T3_CACHE_DIR:-$HOME/.t3/caches}/$KEY.json"

[ -f "$SETTINGS" ] || { echo "error: $SETTINGS not found" >&2; exit 1; }
command -v node >/dev/null || { echo "error: node not found" >&2; exit 1; }

node - "$SETTINGS" "$KEY" <<'NODE'
const fs = require('fs');
const [p, key] = process.argv.slice(2);

let cfg;
try {
  cfg = JSON.parse(fs.readFileSync(p, 'utf8'));
} catch (e) {
  console.error(`error: ${p} is not valid JSON: ${e.message}`);
  process.exit(1);
}

if (!cfg.providerInstances || !(key in cfg.providerInstances)) {
  console.log(`nothing to remove: providerInstances.${key} absent`);
  process.exit(0);
}

const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const backup = `${p}.bak.${stamp}`;
fs.copyFileSync(p, backup);
console.log(`backup: ${backup}`);

delete cfg.providerInstances[key];
fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + '\n');
console.log(`removed providerInstances.${key}`);
NODE

rm -f "$CACHE" 2>/dev/null || true
echo "Uninstalled. Restart T3 Code if the provider is still listed."
