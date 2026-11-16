# Command Code as a harness in T3 Code

T3 Code can drive Command Code as a first-class provider, because the `commandcode` CLI already
ships an **ACP agent mode** (`commandcode acp`). No proxy, no wrapper, no browser automation —
T3 speaks the Agent Client Protocol to the CLI over stdio.

So if you pay for a Command Code subscription you get it inside T3 next to your Claude / Codex /
Cursor providers, using the login you already have. No API key, no re-auth.

```
T3 Code  ──ACP (JSON-RPC over stdio)──▶  commandcode acp  ──▶  your subscription
```

## What you get

- **Provider:** `Command Code` in the T3 model picker
- **Models:** whatever Command Code serves (~98 at time of writing; default
  `deepseek/deepseek-v4.1-flash`)
- **Auth:** reuses `~/.commandcode/auth.json` — if you're logged in, T3 just works
- **Modes:** T3's mode switches map onto Command Code's own permission modes
  (Standard, Accept Edits, Plan, Don't Ask, Bypass)

## Requirements

| Thing | Why |
| --- | --- |
| T3 Code (desktop) | Must support the `acpRegistry` (Local ACP) provider driver |
| `commandcode` CLI, logged in | The agent itself |
| Node.js | `install.sh` uses it to edit `settings.json` safely. T3 ships one |

```bash
commandcode --version        # prints a version
commandcode login            # only if you aren't signed in
ls ~/.commandcode/auth.json  # proof the login is stored
```

## Install

```bash
git clone https://github.com/jovylle/t3-command-code-harness.git
cd t3-command-code-harness
./install.sh
```

Open T3, hit the model picker, choose **Command Code**, pick a model.

The script is idempotent. It:

1. locates the `commandcode` binary (or honors `COMMANDCODE_BIN=/path/to/commandcode`)
2. backs up `~/.t3/userdata/settings.json` to a timestamped `.bak`
3. adds one `providerInstances` entry and nothing else
4. waits for T3 to hot-reload and probe the agent, then prints the model count

T3 watches `settings.json`, so no restart is normally needed. If the provider doesn't show up,
restart T3.

### Manual install

Add this under `providerInstances` in `~/.t3/userdata/settings.json`, with your own
`command -v commandcode`:

```json
{
  "providerInstances": {
    "acpRegistry_command_code": {
      "driver": "acpRegistry",
      "displayName": "Command Code",
      "enabled": true,
      "config": {
        "source": "local",
        "commandPath": "/Users/you/.local/bin/commandcode",
        "commandArgs": ["acp"]
      }
    }
  }
}
```

Or from the UI: **Settings → Providers → Local ACP**, executable `commandcode`, argument `acp`.

## Verify

```bash
head -20 ~/.t3/caches/acpRegistry_command_code.json
```

You want `"status": "ready"` plus a populated `models` array. `"status": "error"` means the path
is wrong or the CLI isn't logged in.

## Gotchas

**1. Don't-ask mode silently kills tools.** In a non-prompting permission mode, any tool outside
the allowlist is denied *with no prompt*. It looks like the agent is broken when it's really the
harness refusing. Use a prompting mode (Accept Edits / Plan) or add explicit `permissions.allow`
rules. This bit us on the very first turn after install.

**2. The CLI self-updates.** If it updates mid-thread, the live session can break. Finish or
reopen the thread instead of expecting the old session to keep going.

**3. The model list comes from Command Code, not this repo.** Different plans expose different
models — T3 asks the CLI.

**4. Version drift.** Verified against `command-code` v1.89.1 (ACP handshake + a live turn). If
`acp` ever disappears from `commandcode --help`, the flag was renamed; the fix is one string in
`settings.json`.

## Uninstall

```bash
./uninstall.sh
```

Removes the provider entry (backing up `settings.json` first) and deletes the probe cache. Restart
T3 if it's still listed.

## How it works

`commandcode acp` is an ACP agent on stdio. T3's `acpRegistry` driver spawns it, sends
`initialize`, then `session/new`, and gets back the mode presets plus the model catalog. Every
turn after that is plain ACP traffic. Nothing runs in the background, no port is forwarded.

## License

MIT
