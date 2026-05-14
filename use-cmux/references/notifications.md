# Notifications

Notifications are the cheapest, safest way to ping the user from inside the VM. They appear in the local cmux sidebar (Cmd+Shift+U opens it on Mac) and don't disturb any terminal.

## Quick send

```sh
CMUX="$HOME/.cmux/bin/cmux"
"$CMUX" notify --title "Build done" --body "All tests passed in 4m12s"
```

Returns JSON with the created `surface_id` (where it was anchored) and `workspace_id`. The notification is anchored to whatever surface called the CLI — so by default, your own.

## Anchor to a specific surface or workspace

When the user is in a different workspace, anchor the notification there so it lights up *their* sidebar entry instead of yours. Use the RPC form, which accepts more parameters than the subcommand:

```sh
"$CMUX" rpc notification.create '{
  "title": "Deploy ready",
  "body": "Click to view logs",
  "surface_id": "<target surface uuid>"
}'
```

Variants:

- `notification.create_for_workspace` — anchor to a workspace rather than a surface
- `notification.create_for_caller` — explicitly the calling surface (default)
- `notification.create_for_target` — explicit target, fails if not reachable

Find candidate surfaces with `cmux --json rpc surface.list` and `workspace.list`.

## Listing and dismissing

```sh
"$CMUX" rpc notification.list                 # all notifications
"$CMUX" rpc notification.dismiss '{"id":"..."}' # dismiss one
"$CMUX" rpc notification.mark_read '{"id":"..."}'
"$CMUX" rpc notification.clear                # clear all
"$CMUX" rpc notification.jump_to_unread       # focus the next unread
```

`notification.list` returns an array of `{id, title, body, subtitle, surface_id, workspace_id, is_read, created_at}`. Use `id` for subsequent calls.

## Tips

- Keep titles short (< ~40 chars). The body is more forgiving but truncated in the sidebar list.
- Don't spam — one notification per finished task is the right granularity. If you need progress updates, prefer writing to a surface.
- If you create a test/debug notification, dismiss it before finishing the task. The user shouldn't have to clean up after the agent.
