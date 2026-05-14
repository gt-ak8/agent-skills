# Paired-agent launchers

cmux ships wrappers that launch popular coding agents *as a paired surface* inside the user's local cmux UI, with the agent's process running on the remote VM. The agent's output appears as a native cmux split — clicks, notifications, and keyboard navigation behave like any other surface.

| Command | Agent | Local binary needed |
| --- | --- | --- |
| `cmux claude-teams [args...]` | Claude Code (teammate mode) | `claude` |
| `cmux omo [args...]` | OpenCode (`opencode-ai`) | `opencode` |
| `cmux omx [args...]` | Oh My Codex | `codex` |
| `cmux omc [args...]` | Oh My Claude Code | `claude` |

These pass through their args. For example:

```sh
"$HOME/.cmux/bin/cmux" claude-teams --print "Summarize TODOs in this repo"
"$HOME/.cmux/bin/cmux" omo run "fix the failing test"
```

If the underlying binary isn't installed on the remote, the wrapper prints an install hint and exits non-zero. The CLI does **not** install agents for you.

## When to use

- The user wants to delegate a sub-task to another agent and watch it in a side surface.
- The user wants to compare two agents on the same prompt.
- The user explicitly says "open this in claude-teams" / "run with opencode".

Don't auto-route requests to these launchers without the user asking. They create real surfaces.
