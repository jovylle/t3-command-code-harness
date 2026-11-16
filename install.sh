#!/usr/bin/env bash
# Register the Command Code CLI as a local ACP provider in T3 Code.
set -euo pipefail

SETTINGS="${T3_SETTINGS:-$HOME/.t3/userdata/settings.json}"
KEY="acpRegistry_command_code"
CACHE_DIR="${T3_CACHE_DIR:-$HOME/.t3/caches}"
CACHE="$CACHE_DIR/$KEY.json"

die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

[ -f "$SETTINGS" ] || die "T3 settings not found at $SETTINGS (is T3 Code installed? pass T3_SETTINGS=/path/to/settings.json)"

find_commandcode() {
  local c
  for c in "$(command -v commandcode 2>/dev/null || true)" \
           "$HOME/.local/bin/commandcode" "$HOME/bin/commandcode" \
           "/usr/local/bin/commandcode" "/opt/homebrew/bin/commandcode"; do
    if [ -n "$c" ] && [ -x "$c" ]; then printf '%s\n' "$c"; return 0; fi
  done
  return 1
}

BIN="${COMMANDCODE_BIN:-$(find_commandcode || true)}"
[ -n "$BIN" ] && [ -x "$BIN" ] || die "commandcode not found; install it or run: COMMANDCODE_BIN=/path/to/commandcode ./install.sh"
info "commandcode: $BIN"

command -v node >/dev/null || die "node not found (needed to edit settings.json safely)"

node - "$SETTINGS" "$BIN" "$KEY" <<'NODE'
const fs = require('fs');
const [settingsPath, bin, key] = process.argv.slice(2);

let cfg;
try {
  cfg = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
} catch (e) {
  console.error(`error: ${settingsPath} is not valid JSON: ${e.message}`);
  process.exit(1);
}

const wanted = {
  driver: 'acpRegistry',
  displayName: 'Command Code',
  enabled: true,
  config: { source: 'local', commandPath: bin, commandArgs: ['acp'] },
};

cfg.providerInstances = cfg.providerInstances || {};
const existing = cfg.providerInstances[key];
const merged = {
  ...(existing || {}),
  ...wanted,
  config: { ...((existing && existing.config) || {}), ...wanted.config },
};

if (existing && JSON.stringify(existing) === JSON.stringify(merged)) {
  console.log('already configured - nothing to change');
  process.exit(0);
}

const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const backup = `${settingsPath}.bak.${stamp}`;
fs.copyFileSync(settingsPath, backup);
console.log(`backup: ${backup}`);

cfg.providerInstances[key] = merged;
fs.writeFileSync(settingsPath, JSON.stringify(cfg, null, 2) + '\n');
console.log(`${existing ? 'updated' : 'added'} providerInstances.${key}`);
NODE

info "waiting for T3 to probe the agent (hot reload)..."
for _ in $(seq 1 40); do
  if [ -f "$CACHE" ]; then
    status=$(node -e 'try{process.stdout.write(String(require(process.argv[1]).status||"unknown"))}catch(e){process.stdout.write("unreadable")}' "$CACHE" 2>/dev/null || echo unreadable)
    if [ "$status" = "ready" ]; then
      node -e 'const d=require(process.argv[1]);console.log("ready - "+d.models.length+" models");console.log("first: "+d.models.slice(0,5).map(m=>m.slug).join(", "))' "$CACHE"
      printf '\nDone. In T3 Code open the model picker and choose Command Code.\n'
      exit 0
    fi
    info "status: $status"
  fi
  sleep 0.5
done

echo "warning: no ready probe yet. Either T3 needs a restart, or the CLI path is wrong:" >&2
echo "  $BIN acp" >&2
exit 1
