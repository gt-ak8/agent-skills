# CLI subcommand reference

Top-level usage:

```
cmux [--socket <path>] [--json] <command> [args...]
```

Global flags:

- `--socket <path>` — override the relay socket (otherwise read from `~/.cmux/socket_addr`).
- `--json` — emit compact JSON instead of pretty-printed JSON. Most commands already return JSON; this just removes whitespace.

Commands accept positional args and an inline JSON object; for anything the wrapper doesn't expose cleanly, fall back to `cmux rpc`.

## Connectivity

| Command | Purpose | Notes |
| --- | --- | --- |
| `ping` | Health check | Prints `PONG` on success. |
| `capabilities` | Server capabilities + RPC method list | Returns `protocol`, `access_mode`, `methods[]`, `socket_path`. |

## Workspaces and surfaces

| Command | Purpose |
| --- | --- |
| `list-workspaces` | All workspaces, their remotes, titles, selection state |
| `new-window` | Create a new window in the local app |
| `new-workspace` | Create a workspace; returns ids |
| `new-surface` | Create a new terminal surface in the current workspace |
| `new-split` | Split an existing surface — requires `--direction left\|right\|up\|down` (or the RPC equivalent) |
| `close-surface <surface_id>` | Close a surface (cannot close the last one in a workspace) |
| `close-workspace` | Close a workspace — pass `{"workspace_id":"..."}` via rpc or the positional id |
| `select-workspace <workspace_id>` | Switch focus to a workspace |

The "open" operations all return ids you should hang on to if you intend to clean up. Closing the last surface in a workspace is refused with `invalid_state`.

## Text and key injection

| Command | Purpose | Required |
| --- | --- | --- |
| `send` | Send literal text to a surface | text + target |
| `send-key` | Send a named key (`enter`, `tab`, `ctrl-c`, …) | key + target |

Both default the target to the currently focused surface. **That includes your own Claude Code surface — never send to self.** See `workspaces-and-surfaces.md` for the safe pattern (find a sibling surface first).

The corresponding RPC methods take a `surface_id` parameter you control:

```sh
cmux rpc surface.send_text '{"surface_id":"<other>","text":"ls -la\n"}'
cmux rpc surface.send_key  '{"surface_id":"<other>","key":"ctrl-c"}'
```

## Notifications

| Command | Purpose |
| --- | --- |
| `notify --title <T> --body <B>` | Create a local notification, anchored to the current surface |

Detailed flags, anchoring to a specific surface, dismissal, and listing live in `notifications.md`.

## Browser

`cmux browser <sub>` covers the browser surface family. The subcommands are:

```
back, check, click, dblclick, eval, fill, focus, forward, get-url,
goto, hover, key, keydown, keyup, navigate, new, open, open-split,
press, reload, screenshot, select, snapshot, type, uncheck, url, wait
```

`new` creates a new browser surface (splits the current pane). `open` reuses an existing browser sibling if one exists. After that, most subcommands need a `--surface <id>` (or the RPC `surface_id`). Full details in `browser.md`.

## Agent launchers

| Command | What it does | Requirements |
| --- | --- | --- |
| `claude-teams [args...]` | Spawn Claude Code in teammate mode | Claude Code binary |
| `omo [args...]` | Launch OpenCode with cmux integration | `opencode` in PATH |
| `omx [args...]` | Launch Oh My Codex with cmux integration | codex binary |
| `omc [args...]` | Launch Oh My Claude Code with cmux integration | Claude Code |

These run a paired agent and wire its surface/notifications into cmux. See `agents.md`.

## Raw RPC

```
cmux rpc <method> [json-params]
```

`<method>` is one of ~180 methods (`cmux capabilities` lists them). Params is a single JSON object, e.g. `'{"surface_id":"...","text":"hi"}'`. Returns one JSON object on stdout. This is the escape hatch — use it whenever the high-level subcommand doesn't expose the parameter you need, or when the method doesn't have a wrapper at all (e.g., `file.open`, `markdown.open`, `feed.*`, `pane.*`, `vm.*`).

See `rpc-reference.md` for the catalog grouped by namespace.

## Exit codes and error format

On success, commands print JSON or human-readable output and exit 0. On failure the wrapper prints `cmux: server error [<code>]: <message>` to stderr and exits non-zero. Common codes:

- `invalid_params` — missing/wrong-shaped argument
- `invalid_state` — the operation isn't valid in current state (e.g. closing the last surface)
- `vm_error` — VM management needs auth or the VM isn't reachable

When scripting, capture stderr separately and branch on exit code.
