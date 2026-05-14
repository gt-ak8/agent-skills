# JSON-RPC method catalog

`cmux rpc <method> [json-params]` is the universal escape hatch. Below is the full method set the local daemon exposes, grouped by namespace. Get the live list any time with `cmux capabilities`.

Conventions used by the daemon:

- Targets are passed by UUID. Most read methods accept no params (operate on the caller's context); most write methods require `workspace_id`, `pane_id`, `surface_id`, or `window_id`.
- Errors come back as `cmux: server error [code]: message` on stderr with non-zero exit.
- Pass `--json` if you intend to parse: it strips pretty-printing.

## `system.*` — daemon and host info

| Method | Params | Returns |
| --- | --- | --- |
| `system.ping` | — | `PONG` |
| `system.identify` | — | caller surface + focused surface ids |
| `system.capabilities` | — | RPC method list + protocol + socket path |
| `system.top` | — | aggregate process info (per-window CPU/mem if exposed) |
| `system.tree` | — | full window→workspace→pane→surface tree |

## `window.*`

| Method | Params |
| --- | --- |
| `window.list` | — |
| `window.current` | — |
| `window.create` | `{}` (optional bounds) |
| `window.focus` | `{window_id}` |
| `window.close` | `{window_id}` |

## `workspace.*`

| Method | Params | Notes |
| --- | --- | --- |
| `workspace.list` | — | |
| `workspace.current` | — | |
| `workspace.create` | `{title?, window_id?}` | |
| `workspace.close` | `{workspace_id}` | |
| `workspace.select` | `{workspace_id}` | |
| `workspace.next` / `workspace.previous` / `workspace.last` | — | cycle |
| `workspace.rename` | `{workspace_id, title}` | |
| `workspace.reorder` | `{workspace_id, index}` | |
| `workspace.move_to_window` | `{workspace_id, window_id}` | |
| `workspace.equalize_splits` | `{workspace_id?}` | |
| `workspace.action` | `{workspace_id, action}` | misc actions |
| `workspace.prompt_submit` | `{workspace_id, text}` | submit to a workspace's prompt surface |
| `workspace.remote.status` | `{workspace_id}` | remote daemon health |
| `workspace.remote.configure` | `{workspace_id, ...}` | change SSH config |
| `workspace.remote.reconnect` | `{workspace_id}` | |
| `workspace.remote.disconnect` | `{workspace_id}` | |
| `workspace.remote.foreground_auth_ready` | `{workspace_id}` | reply to auth prompt |
| `workspace.remote.terminal_session_end` | `{workspace_id}` | cleanup |

## `pane.*`

| Method | Params |
| --- | --- |
| `pane.list` | — |
| `pane.create` | `{...}` |
| `pane.focus` | `{pane_id}` |
| `pane.resize` | `{pane_id, weight}` |
| `pane.surfaces` | `{pane_id}` |
| `pane.last` | — |
| `pane.swap` | `{a_pane_id, b_pane_id}` |
| `pane.join` | `{...}` |
| `pane.break` | `{...}` |

## `surface.*`

| Method | Params | Notes |
| --- | --- | --- |
| `surface.list` | — | surfaces in current workspace |
| `surface.current` | — | the surface that called the daemon — i.e. YOU |
| `surface.create` | `{type?, workspace_id?}` | usually a terminal |
| `surface.close` | `{surface_id}` | refuses last surface in a workspace |
| `surface.focus` | `{surface_id}` | |
| `surface.split` | `{surface_id?, direction}` | `left\|right\|up\|down` |
| `surface.split_off` | `{surface_id}` | |
| `surface.move` | `{surface_id, ...}` | |
| `surface.reorder` | `{surface_id, index}` | |
| `surface.drag_to_split` | `{...}` | |
| `surface.send_text` | `{surface_id, text}` | |
| `surface.send_key` | `{surface_id, key}` | |
| `surface.read_text` | `{surface_id}` | returns `text` + `base64` (with ANSI) |
| `surface.refresh` | `{surface_id}` | |
| `surface.clear_history` | `{surface_id}` | clear scrollback |
| `surface.health` | `{surface_id}` | |
| `surface.action` | `{surface_id, action}` | |
| `surface.trigger_flash` | `{surface_id}` | flash to draw attention |
| `surface.ports_kick` | `{surface_id}` | re-detect listening ports |
| `surface.report_shell_state` | `{...}` | shell integration callback |
| `surface.report_tty` | `{...}` | |

## `tab.*`

| Method | Params |
| --- | --- |
| `tab.action` | `{tab_id, action}` |

## `browser.*`

A full catalog is in `browser.md`. Quick index:

- Navigation: `browser.navigate`, `browser.back`, `browser.forward`, `browser.reload`, `browser.url.get`
- Interaction: `browser.click`, `browser.dblclick`, `browser.fill`, `browser.type`, `browser.press`, `browser.hover`, `browser.focus`, `browser.check`, `browser.uncheck`, `browser.select`, `browser.scroll`, `browser.scroll_into_view`
- Inspection: `browser.get.text`, `browser.get.html`, `browser.get.attr`, `browser.get.value`, `browser.get.styles`, `browser.get.title`, `browser.get.box`, `browser.get.count`, `browser.is.visible`, `browser.is.enabled`, `browser.is.checked`
- Locators: `browser.find.text`, `browser.find.role`, `browser.find.label`, `browser.find.testid`, `browser.find.alt`, `browser.find.placeholder`, `browser.find.title`, `browser.find.first`, `browser.find.last`, `browser.find.nth`
- Frames/tabs: `browser.frame.main`, `browser.frame.select`, `browser.tab.list`, `browser.tab.new`, `browser.tab.switch`, `browser.tab.close`
- Storage: `browser.cookies.get/set/clear`, `browser.storage.get/set/clear`
- I/O: `browser.eval`, `browser.snapshot`, `browser.screenshot`, `browser.highlight`
- Recording: `browser.screencast.start/stop`, `browser.trace.start/stop`
- Logs: `browser.console.list`, `browser.console.clear`, `browser.errors.list`, `browser.network.requests`, `browser.network.route`, `browser.network.unroute`
- Input lower-level: `browser.input_keyboard`, `browser.input_mouse`, `browser.input_touch`, `browser.keydown`, `browser.keyup`, `browser.key`
- Page state: `browser.viewport.set`, `browser.offline.set`, `browser.geolocation.set`, `browser.state.save`, `browser.state.load`, `browser.addinitscript`, `browser.addscript`, `browser.addstyle`
- Dialogs/downloads: `browser.dialog.accept`, `browser.dialog.dismiss`, `browser.download.wait`
- Surfaces: `browser.open_split`, `browser.focus_webview`, `browser.is_webview_focused`
- Waiting: `browser.wait`, `browser.check` (state assertion)

## `notification.*`

| Method | Params |
| --- | --- |
| `notification.create` | `{title, body?, subtitle?, surface_id?}` |
| `notification.create_for_caller` | same |
| `notification.create_for_surface` | `{title, body, surface_id}` |
| `notification.create_for_target` | `{title, body, target}` |
| `notification.list` | — |
| `notification.open` | `{id}` |
| `notification.dismiss` | `{id}` |
| `notification.clear` | — |
| `notification.mark_read` | `{id}` |
| `notification.jump_to_unread` | — |

## `file.*` / `markdown.*` / `settings.*` / `feedback.*`

| Method | Params |
| --- | --- |
| `file.open` | `{path}` or `{paths:[...]}`. **Local Mac paths.** |
| `markdown.open` | `{path}`. Opens cmux's in-app markdown surface. |
| `settings.open` | — |
| `feedback.open` | — |
| `feedback.submit` | `{...}` |

## `feed.*` — agent telemetry / question feed

The "feed" is cmux's internal stream of agent events: prompts, tool uses, permission requests, questions. You usually don't drive this from a coding session, but the methods are exposed:

| Method | Purpose |
| --- | --- |
| `feed.list` | List recent feed items (very chatty) |
| `feed.push` | Append an item |
| `feed.jump` | Focus a specific feed item |
| `feed.permission.reply` | Answer a permission request |
| `feed.question.reply` | Answer a question prompt |
| `feed.exit_plan.reply` | Answer plan-mode exit prompt |

## `events.*`

| Method | Purpose |
| --- | --- |
| `events.stream` | Long-poll for events. The CLI streams; from a script you usually want a different approach. |

## `auth.*`

These talk to cmux cloud (not local-only). Most tasks don't need them.

| Method | Purpose |
| --- | --- |
| `auth.status` | Logged in? |
| `auth.begin_sign_in` | Start OAuth flow |
| `auth.login` | Direct login |
| `auth.sign_out` | Log out |

## `vm.*` — cmux Cloud VMs (requires auth)

These manage cmux's hosted VMs. They are **not** used to manage your local SSH targets; for local Limas/Multipasses/etc., manage with their native tools. All `vm.*` methods will refuse without `cmux auth login`.

| Method | Purpose |
| --- | --- |
| `vm.list` | List VMs |
| `vm.create` | Create one |
| `vm.destroy` | Tear down |
| `vm.exec` | Execute a command remotely |
| `vm.ssh_info` | Print SSH connection info |
| `vm.attach_info` | Print attach info for cmux UI |

## `session.*`, `debug.*`, `app.*`

| Method | Purpose |
| --- | --- |
| `session.restore_previous` | Re-open the last cmux session |
| `debug.terminals` | Debug dump of terminal state |
| `app.focus_override.set` | Force the app to consider a surface focused (for testing) |
| `app.simulate_active` | Mark the app as active (for testing) |

---

When in doubt, run `cmux capabilities | head -200` to see the live method list — it changes as cmux versions bump. Combine with `cmux rpc <method>` and an empty `'{}'` to discover required params (the daemon's error messages name the missing field, e.g. `Missing or invalid surface_id`).
