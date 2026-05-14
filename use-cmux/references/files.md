# Opening files and markdown in the local UI

The VM-side filesystem and the Mac-side filesystem are different. `file.open` and `markdown.open` use **local (Mac) paths**, not VM paths — the local cmux app opens the file. If the file only exists on the VM, copy it across first (e.g. via the SSH session's `scp`, or by writing to a shared mount).

## file.open

```sh
CMUX="$HOME/.cmux/bin/cmux"

"$CMUX" rpc file.open '{"path":"/Users/me/project/README.md"}'

# Multiple files at once
"$CMUX" rpc file.open '{"paths":["/Users/me/a.txt","/Users/me/b.txt"]}'
```

This routes through the user's configured opener (Finder default, or whatever they've wired up — often VS Code or their editor). It is **not** an in-cmux editor; it's the OS-level "open file" action.

If you only have the VM path, ask the user for the Mac-side path, or determine it via known mount points. Don't guess.

## markdown.open

For markdown specifically, the local cmux app has an in-app markdown surface (renders in a side pane rather than launching an external editor).

```sh
"$CMUX" rpc markdown.open '{"path":"/Users/me/docs/plan.md"}'
```

Useful for: showing the user a write-up the agent just produced (after saving it to a path they can reach), surfacing release notes, or pulling up a CONTEXT.md.

## settings.open and feedback.open

Two adjacent commands worth knowing:

```sh
"$CMUX" rpc settings.open    # open the cmux settings panel
"$CMUX" rpc feedback.open    # open the cmux feedback panel
```

These rarely belong inside an automation, but the user might ask "open settings" — that's the call.
