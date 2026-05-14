# Workspaces, panes, and surfaces

cmux's UI model has four levels:

- **Window** — an OS window of the local cmux app.
- **Workspace** — a tab inside a window. Optionally bound to a remote VM.
- **Pane** — a layout box inside a workspace. A workspace has one or more panes after splits.
- **Surface** — the actual content inside a pane: a terminal session, a browser tab, etc. A pane can hold multiple surfaces in a tab strip.

Every entity has both a stable UUID `id` and a short `ref` (e.g. `surface:5`). Use the UUID for parameters; the ref is for human reading.

## Listing

```sh
CMUX="$HOME/.cmux/bin/cmux"
"$CMUX" --json list-workspaces           # workspaces with full remote info
"$CMUX" --json rpc workspace.list        # same, slightly leaner
"$CMUX" --json rpc surface.list          # surfaces in the current workspace
"$CMUX" --json rpc pane.list             # panes in the current workspace
"$CMUX" --json rpc window.list           # windows
"$CMUX" --json rpc surface.current       # the surface that issued the call (i.e. YOU)
"$CMUX" --json rpc workspace.current     # the workspace that issued the call
"$CMUX" --json rpc system.identify       # caller + focused surface in one shot
```

`surface.current` is critical — it's how you find your own surface so you never send keystrokes to yourself.

## Finding a sibling surface (the "other terminal")

Workflow: the user is in one terminal, you in another. They want you to type into theirs. Get your own id, list surfaces, pick the one that isn't you.

```sh
CMUX="$HOME/.cmux/bin/cmux"

SELF=$("$CMUX" --json rpc surface.current | python3 -c 'import json,sys;print(json.load(sys.stdin)["surface_id"])')

OTHER=$("$CMUX" --json rpc surface.list | SELF="$SELF" python3 -c '
import json, sys, os
self_id = os.environ["SELF"]
surfaces = json.load(sys.stdin)["surfaces"]
candidates = [s for s in surfaces if s["type"] == "terminal" and s["id"] != self_id]
print(candidates[0]["id"] if candidates else "")
')

if [ -z "$OTHER" ]; then
  echo "no sibling terminal found; create one with new-surface or new-split" >&2
  exit 1
fi
```

To search across workspaces (when the target terminal is in a different tab), loop `workspace.list` and call `surface.list` with the workspace id, or use `pane.surfaces` for a specific pane.

## Sending text or keys

```sh
"$CMUX" rpc surface.send_text '{"surface_id":"'"$OTHER"'","text":"echo hello\n"}'
"$CMUX" rpc surface.send_key  '{"surface_id":"'"$OTHER"'","key":"ctrl-c"}'
```

Notes:

- `text` is sent verbatim. Include `\n` if you want the command to execute.
- `key` accepts names like `enter`, `tab`, `escape`, `up`, `down`, `ctrl-c`, `ctrl-d`, `cmd-k`.
- If you omit `surface_id`, the call defaults to the **focused** surface — that is whatever the user clicked on most recently in the cmux app, *not* the surface that called the daemon. If the user switches workspace while your task is running, your call lands in the new workspace. **Always pass an explicit `surface_id`.**

## Reading surface output

```sh
"$CMUX" rpc surface.read_text '{"surface_id":"'"$OTHER"'"}'
```

Returns `text` (the visible buffer as plain text) and `base64` (the same buffer with ANSI sequences intact). Use this to verify a command landed.

## Creating, splitting, closing

```sh
# New empty terminal surface in the current workspace
"$CMUX" new-surface

# Split the current pane and add a surface to the new side.
# Without surface_id this splits the FOCUSED pane (which may not be yours
# if the user switched workspaces). Pass surface_id to pin to YOUR pane:
SELF=$("$CMUX" --json rpc surface.current | python3 -c 'import json,sys;print(json.load(sys.stdin)["surface_id"])')
"$CMUX" rpc surface.split "{\"surface_id\":\"$SELF\",\"direction\":\"right\"}"   # left|right|up|down

# New workspace (a new tab)
"$CMUX" new-workspace

# Close
"$CMUX" close-surface <surface_id>
"$CMUX" rpc workspace.close '{"workspace_id":"..."}'
"$CMUX" rpc window.close '{"window_id":"..."}'
```

`close-surface` refuses to close the last surface in a workspace (`invalid_state`). Close the workspace instead.

## Selecting / focusing

```sh
"$CMUX" select-workspace <workspace_id>          # switch tab
"$CMUX" rpc surface.focus '{"surface_id":"..."}' # focus a surface
"$CMUX" rpc workspace.next                       # cycle
"$CMUX" rpc workspace.previous
"$CMUX" rpc workspace.last
```

## Naming and reordering

```sh
"$CMUX" rpc workspace.rename '{"workspace_id":"...","title":"Backend logs"}'
"$CMUX" rpc workspace.reorder '{"workspace_id":"...","index":0}'
"$CMUX" rpc pane.resize '{"pane_id":"...","weight":0.7}'
```

## Cross-workspace operations

A workspace can be tied to a remote VM (`remote.connected: true`). Useful fields on the workspace object: `remote.destination`, `remote.daemon.state` (`ready`/`unavailable`), `remote.proxy.url` (SOCKS5/HTTP_CONNECT proxy URL the local app exposes for that VM's network).

```sh
"$CMUX" rpc workspace.remote.status '{"workspace_id":"..."}'
"$CMUX" rpc workspace.remote.reconnect '{"workspace_id":"..."}'
"$CMUX" rpc workspace.remote.disconnect '{"workspace_id":"..."}'
```
