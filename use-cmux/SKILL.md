---
name: use-cmux
description: How to drive the cmux app (workspaces, surfaces, browser, notifications, file open) from inside a remote VM that the user reached via `cmux ssh`. Use whenever the user is working inside a cmux-managed shell and asks to notify them, open a file in their editor, send text/keys to another terminal pane, automate a browser tab, list or switch workspaces, or do anything else that crosses from the remote VM back to the local cmux UI. Also use when the user mentions "cmux", "cmuxd", "cmux notify", "cmux browser", a `cmux rpc` call, the cmux socket, or asks "is cmux available here".
---

# use-cmux

`cmux` is a terminal-multiplexer-style app the user runs on their Mac. When they `cmux ssh` into a VM, a small remote daemon (`cmuxd-remote`) is started in the VM and a CLI wrapper at `~/.cmux/bin/cmux` is left behind. That CLI relays JSON-RPC over a TCP tunnel back to the local cmux app, so from inside the VM you can drive the user's local windows, terminals, browser panes, and notifications.

This skill is the index. Read the reference file matching what you need to do.

## When to use this skill

- The user asks to be notified / pinged / told when a long task is done
- The user wants a file opened in their local cmux UI (editor / markdown preview)
- The user wants to interact with another terminal pane (drive a REPL, run a command in a sibling shell)
- The user wants to drive a browser tab (navigate, click, screenshot, scrape) from within their cmux session
- The user mentions cmux, cmuxd, `cmux ssh`, `cmux notify`, `cmux browser`, or asks what cmux can do here
- The user asks how to detect / verify cmux is available in this shell

If the user is just running ordinary commands and there is no cross-boundary action needed, no need to invoke cmux at all.

## Two interfaces, one daemon

Only one transport exists: the local cmux app speaks JSON-RPC over a relay socket. You reach it through the CLI shim at `~/.cmux/bin/cmux`. There is no separate "daemon API" to call directly from the VM — the wrapper IS the way. So "use the daemon or CLI directly depending on what's available" reduces to: **always go through the CLI wrapper, and pick between high-level subcommands or the raw `rpc` escape hatch based on what the operation needs.**

- **High-level subcommands** (`cmux notify`, `cmux browser …`, `cmux send`, `cmux list-workspaces`, …) — convenient, do the right thing for common cases.
- **`cmux rpc <method> [json-params]`** — direct JSON-RPC to any of ~180 methods. Use this when no subcommand exists, when you need a parameter the subcommand doesn't expose, or when you want structured JSON back.

Pass `--json` before the subcommand to get machine-readable output (most subcommands already return JSON; `--json` removes pretty printing).

## Quick start

Before anything else, confirm the CLI exists and the daemon answers. If both work, you can proceed. If not, see `references/detection.md`.

```sh
test -x "$HOME/.cmux/bin/cmux" && "$HOME/.cmux/bin/cmux" ping
# expected: PONG
```

For the rest of this skill, assume the CLI is at `$HOME/.cmux/bin/cmux`. The user does not necessarily have it on `$PATH` — invoke it by full path, or set an alias for the session.

## Reference map

Pick the file matching your task. Each is self-contained.

| File | When to read |
| --- | --- |
| `references/detection.md` | Detecting whether cmux is reachable; troubleshooting the relay socket; environment hints |
| `references/cli-commands.md` | Full list of `cmux <subcommand>` forms with their parameters and example outputs |
| `references/notifications.md` | Pinging the user (`cmux notify`), targeting a specific surface, dismissing |
| `references/workspaces-and-surfaces.md` | Listing workspaces/surfaces/panes, finding "the other terminal", sending text/keys to another surface (never your own!), opening / closing / splitting surfaces |
| `references/browser.md` | Driving a browser tab from the VM: open, navigate, click, fill, screenshot, eval, snapshot |
| `references/files.md` | Opening files (`file.open`) and markdown previews (`markdown.open`) in the local cmux UI |
| `references/rpc-reference.md` | Full catalog of JSON-RPC methods (~180). Use this when no subcommand wraps what you need |
| `references/agents.md` | Launchers for paired-agent flows: `claude-teams`, `omo`, `omx`, `omc` |

## Hard-won safety rules

1. **Omitted `surface_id` means "focused surface", not "caller surface".** Any surface-targeting method (`surface.send_text`, `surface.send_key`, `surface.split`, `surface.close`, `surface.focus`, `notification.create`, …) defaults to whatever the user clicked on last in the cmux app. If they switched workspaces while you were running, your call lands in the *new* workspace. **Always pass an explicit `surface_id`.** Get yours with `cmux rpc surface.current`.
2. **Never `send-text` or `send-key` to your own surface.** It types into the Claude Code prompt and corrupts the session. Compute "my surface id" from `surface.current` and target a *different* surface explicitly.
3. **Most "create" operations are not idempotent.** `cmux new-window`, `new-workspace`, `new-surface`, `browser new`, `surface.split` all create real things in the user's UI. Don't loop them blindly; clean up with the matching `close` / `rpc *.close` if you make a test artifact.
4. **`vm.*` methods require `cmux auth login` on the local app.** Most everything else (workspace, surface, browser, notification, file, rpc) works without auth because it talks to the locally-running app over the relay.
5. **`--json` for parsing.** When you intend to grep or pipe into `jq`/Python, prefix with `--json` so output is one compact line.

## Typical recipes

These are the smallest end-to-end examples. Read the matching reference for parameters and options.

```sh
CMUX="$HOME/.cmux/bin/cmux"

# Notify the user a job finished
"$CMUX" notify --title "Build done" --body "All tests passed"

# Open a file in their local editor
"$CMUX" rpc file.open '{"path":"/Users/me/project/README.md"}'

# Find the other terminal surface in the current workspace and run a command there
SELF=$("$CMUX" --json rpc surface.current | python3 -c "import json,sys;print(json.load(sys.stdin)['surface_id'])")
OTHER=$("$CMUX" --json rpc surface.list | python3 -c "import json,sys,os; sid=os.environ['SELF']; print(next(s['id'] for s in json.load(sys.stdin)['surfaces'] if s['type']=='terminal' and s['id']!=sid))" SELF="$SELF")
"$CMUX" rpc surface.send_text "{\"surface_id\":\"$OTHER\",\"text\":\"echo hello\\n\"}"

# Open a browser pane and navigate
NEW=$("$CMUX" --json browser new | python3 -c "import json,sys;print(json.load(sys.stdin)['surface_id'])")
"$CMUX" rpc browser.navigate "{\"surface_id\":\"$NEW\",\"url\":\"https://example.com\"}"
"$CMUX" rpc browser.screenshot "{\"surface_id\":\"$NEW\",\"path\":\"/tmp/shot.png\"}"
```

For anything beyond these one-liners, jump to the matching reference file — the parameter shapes and edge cases are documented there.
