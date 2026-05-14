# Detecting cmux

cmux is "available" in a shell when **both** are true:

1. The CLI wrapper `$HOME/.cmux/bin/cmux` exists and is executable.
2. The daemon answers `ping` (it would say `PONG`).

Either condition can fail. The shell may have been opened outside cmux (regular `ssh` rather than `cmux ssh`), or the relay may have died.

## One-liner check

```sh
CMUX="$HOME/.cmux/bin/cmux"
if [ -x "$CMUX" ] && "$CMUX" ping >/dev/null 2>&1; then
  echo "cmux ready"
else
  echo "cmux unavailable"
fi
```

If you only need a yes/no, this is the whole detection story. The rest of this file is for when the check fails and you want to know why.

## What the wrapper does

`~/.cmux/bin/cmux` is a tiny shell script. It:

1. Reads the socket address from `~/.cmux/socket_addr` (something like `127.0.0.1:62756`).
2. Looks up the matching daemon binary path in `~/.cmux/relay/<port>.daemon_path`.
3. Execs that daemon binary in client mode, passing your args.

So missing pieces give different symptoms:

| Missing | Symptom |
| --- | --- |
| `~/.cmux` directory entirely | You SSH'd in without `cmux ssh`. Skill not applicable. |
| `~/.cmux/bin/cmux` script | Truly broken install; tell the user. |
| `~/.cmux/socket_addr` empty/missing | The relay never connected. `cmux ping` will hang or error. |
| Wrong port in `socket_addr` vs `relay/*.daemon_path` | Stale session. Reconnect via `cmux ssh` from local. |

## Environment hints (none reliable)

cmux does **not** set a `CMUX=1` or similar marker in the shell environment. You can't detect cmux by reading env vars alone. The only authoritative signal is `cmux ping` returning `PONG`.

You can override the relay socket explicitly with `CMUX_SOCKET_PATH=host:port` if you have multiple cmux sessions, but in practice the default file is correct.

## Verifying the daemon is the right one

`cmux capabilities` returns the JSON-RPC method list and the local app's socket path. Useful when troubleshooting:

```sh
"$CMUX" capabilities | head -5
```

A healthy response includes `"protocol": "cmux-socket"` and a non-empty `methods` array. If the method list is short or `access_mode` is something other than `cmuxOnly`, the user may be running an older app.

## When ping works but commands fail

A few subcommands need `cmux auth login` on the *local* app (notably the `vm.*` family — VM lifecycle management). Most everything else works without auth because it's talking to the local app process, not to cmux cloud. If a call fails with `You are not signed in to cmux`, tell the user to run `cmux auth login` from their Mac.
