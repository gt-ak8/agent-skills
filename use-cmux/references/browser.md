# Browser automation

cmux's local app embeds a browser-relay surface — like a headed Playwright. From inside the VM you can open it, drive it, scrape it, and screenshot it. Useful for: clicking through an internal dashboard the agent can't reach over the network, copying a token from an OAuth flow, taking a screenshot for the user, scraping a page behind their SSO.

## Open a browser surface

```sh
CMUX="$HOME/.cmux/bin/cmux"

# Always creates a new browser pane (splits the current pane to the right)
NEW=$("$CMUX" --json browser new | python3 -c 'import json,sys;print(json.load(sys.stdin)["surface_id"])')

# Reuses an existing browser sibling if one exists; creates one otherwise
NEW=$("$CMUX" --json browser open | python3 -c 'import json,sys;print(json.load(sys.stdin)["surface_id"])')

# Create a split with explicit direction
"$CMUX" browser open-split --direction right
```

`browser new` always splits; `browser open` is idempotent — call it twice and the second call just returns the existing surface id (`created_split: false`). Prefer `open` for "give me a browser tab" intent.

## Navigate, reload, history

```sh
"$CMUX" browser navigate --surface "$NEW" --url https://example.com
"$CMUX" browser reload   --surface "$NEW"
"$CMUX" browser back     --surface "$NEW"
"$CMUX" browser forward  --surface "$NEW"
"$CMUX" browser get-url  --surface "$NEW"      # prints current URL
```

RPC equivalents (when you want JSON or to pass extra options):

```sh
"$CMUX" rpc browser.navigate "{\"surface_id\":\"$NEW\",\"url\":\"https://example.com\"}"
"$CMUX" rpc browser.url.get  "{\"surface_id\":\"$NEW\"}"
```

## Interacting (Playwright-like API)

All of these accept `--surface <id>` plus a selector. Selectors mirror Playwright: CSS, text-based (`text=Sign in`), role (`role=button[name="Save"]`), test-id, etc.

```sh
"$CMUX" browser click    --surface "$NEW" --selector 'button#submit'
"$CMUX" browser dblclick --surface "$NEW" --selector 'text=Open'
"$CMUX" browser fill     --surface "$NEW" --selector 'input[name=email]' --value 'a@b.com'
"$CMUX" browser type     --surface "$NEW" --selector 'textarea'         --text 'hello world'
"$CMUX" browser press    --surface "$NEW" --selector 'input'            --key 'Enter'
"$CMUX" browser hover    --surface "$NEW" --selector '.tooltip-target'
"$CMUX" browser focus    --surface "$NEW" --selector 'input[name=q]'
"$CMUX" browser check    --surface "$NEW" --selector '#agree'
"$CMUX" browser uncheck  --surface "$NEW" --selector '#opt-in'
"$CMUX" browser select   --surface "$NEW" --selector 'select[name=country]' --value 'FR'
```

## Scraping

```sh
# Run arbitrary JavaScript in the page; returns its value as JSON
"$CMUX" browser eval --surface "$NEW" --script 'document.title'

# Full snapshot (DOM tree, accessible labels). Big — pipe through jq.
"$CMUX" browser snapshot --surface "$NEW"

# Screenshot (PNG). --path saves to disk; omit to return base64.
"$CMUX" browser screenshot --surface "$NEW" --path /tmp/shot.png
```

For finer-grained reads, the RPC namespace is rich:

```
browser.get.text     browser.get.html     browser.get.attr
browser.get.value    browser.get.styles   browser.get.title
browser.get.box      browser.get.count
browser.is.visible   browser.is.enabled   browser.is.checked
browser.find.text    browser.find.role    browser.find.label
browser.find.testid  browser.find.alt     browser.find.placeholder
```

Example:

```sh
"$CMUX" rpc browser.get.text "{\"surface_id\":\"$NEW\",\"selector\":\"h1\"}"
```

## Waiting and timing

```sh
"$CMUX" browser wait --surface "$NEW" --selector '#results' --state visible
"$CMUX" rpc browser.wait "{\"surface_id\":\"$NEW\",\"selector\":\"#results\",\"state\":\"visible\",\"timeout_ms\":10000}"
```

`state` is one of `attached`, `detached`, `visible`, `hidden`.

## Tabs, cookies, storage

```sh
"$CMUX" rpc browser.tab.list   "{\"surface_id\":\"$NEW\"}"
"$CMUX" rpc browser.tab.new    "{\"surface_id\":\"$NEW\",\"url\":\"https://example.com\"}"
"$CMUX" rpc browser.tab.switch "{\"surface_id\":\"$NEW\",\"index\":1}"
"$CMUX" rpc browser.tab.close  "{\"surface_id\":\"$NEW\",\"index\":1}"

"$CMUX" rpc browser.cookies.get   "{\"surface_id\":\"$NEW\",\"url\":\"https://example.com\"}"
"$CMUX" rpc browser.cookies.set   "{\"surface_id\":\"$NEW\",\"cookies\":[{\"name\":\"k\",\"value\":\"v\",\"domain\":\".example.com\",\"path\":\"/\"}]}"
"$CMUX" rpc browser.cookies.clear "{\"surface_id\":\"$NEW\"}"

"$CMUX" rpc browser.storage.get   "{\"surface_id\":\"$NEW\",\"kind\":\"local\"}"
"$CMUX" rpc browser.storage.set   "{\"surface_id\":\"$NEW\",\"kind\":\"local\",\"items\":{\"k\":\"v\"}}"
"$CMUX" rpc browser.storage.clear "{\"surface_id\":\"$NEW\",\"kind\":\"local\"}"
```

## Login state and host routing

The embedded browser is a fresh Chromium-like profile with **no extensions** — 1Password/Bitwarden/Keychain autofill don't work inside it. Two user-side settings in the cmux app cover this:

- **Browser import** (Settings → Browser): imports cookies, history and sessions from Chrome, Firefox, Arc, Safari and ~20 other browsers, so panes open already authenticated.
- **Host whitelist / external URL bypass** (Settings → Browser → Host Whitelist): hosts that match stay inside cmux; everything else opens in the user's default system browser (where their password manager works). Substring and regex patterns supported.

Neither is configurable from the VM via RPC — they live in the Mac app. If a pane hits a login wall and you don't already have credentials, suggest the user either import the relevant browser or add the host to the bypass list. The programmatic alternatives stay `browser.cookies.set` / `browser.storage.set` with auth state brought in from elsewhere (OAuth device flow, a cookie they pasted, etc.).

## Recording and tracing

```sh
"$CMUX" rpc browser.screencast.start "{\"surface_id\":\"$NEW\",\"path\":\"/tmp/cast.webm\"}"
"$CMUX" rpc browser.screencast.stop  "{\"surface_id\":\"$NEW\"}"
"$CMUX" rpc browser.trace.start      "{\"surface_id\":\"$NEW\",\"path\":\"/tmp/trace.zip\"}"
"$CMUX" rpc browser.trace.stop       "{\"surface_id\":\"$NEW\"}"
```

## Console and network

```sh
"$CMUX" rpc browser.console.list "{\"surface_id\":\"$NEW\"}"  # recent console messages
"$CMUX" rpc browser.errors.list  "{\"surface_id\":\"$NEW\"}"  # JS errors
"$CMUX" rpc browser.network.requests "{\"surface_id\":\"$NEW\"}"
```

## Closing the browser surface

When you spawned a browser pane just for an automation pass and the user doesn't need it visible afterwards, close it:

```sh
"$CMUX" rpc surface.close "{\"surface_id\":\"$NEW\"}"
```

But check first whether the user expects to see the result — leaving the pane open is often the right behavior.
