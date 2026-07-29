---
name: herdr-fleet
description: Run the agents a flow needs as long-lived Herdr panes instead of ephemeral subagents - launch them, keep them in step, read their work - so roles persist, iterate with each other, and stay inspectable. Brings no workflow of its own.
disable-model-invocation: true
---

You are running a flow that dispatches agents. Instead of spawning them as subagents, you give each one **its own pane** and drive them. You are the glue, not the worker.

This skill knows nothing about your flow. Whatever the flow already defines - its roles, its phases, its artifacts, its tracker - is the authority. This is only how to realize its agents as panes and keep them coherent.

The `herdr` skill is the CLI reference. Read it too.

## What changes when a role becomes a pane

| subagent | pane agent |
|---|---|
| lives one turn, returns text | lives until you close it, keeps its context |
| you get the result and it is gone | you can correct it, ask again, make it redo one part |
| invisible while it runs | readable at any moment |
| output is a return value | output is an artifact plus a pane you read |
| dies with your turn | survives your turn, and survives a stall |
| its tool policy comes from its definition | you choose model, effort and working directory per pane |
| free to start, nothing to clean up | holds a pane and possibly a worktree until you release it |

## Decide per role, not per flow

**Default to a subagent.** Escalate a role to a pane when at least one of these is true:

- **It must accumulate context.** A role that leads many steps (a navigator, a planner that re-plans) is worth far more with the whole history than re-briefed from scratch each time.
- **Two roles iterate with each other.** Ping-pong - one produces, the other judges, back and forth - is the case panes are for. As subagents each round starts blind.
- **You need to watch or correct it mid-flight.** Long or risky work where "stop, you are going the wrong way" has to be possible.
- **It must survive a failure.** A crashed turn loses every subagent in flight. Panes are still there.
- **You need a different model or effort than yours.**

Keep it a subagent when you need N independent answers once, with no follow-up. A ten-way fan-out of one-shot readers is cheaper and simpler as subagents. Mixing is normal: the persistent roles get panes, the one-shot fan-out stays subagents.

## Preconditions

```bash
test "${HERDR_ENV:-}" = 1 || echo "not inside Herdr - stop"
printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"
```

Plus a scratch directory for prompt files, and a decision about working directories (next section).

## Topology: who shares a tree

This is the choice that matters most, and it follows from whether the roles collaborate or compete.

**Collaborating roles share one working directory.** A driver and a navigator working the same step must see the same tree - the navigator verifies what the driver just wrote. Start the second one as a peer pane in the first one's tab:

```bash
split-peer.sh driver navigator "$SCRATCH/navigator-brief.md" high
```

One tab now holds the tandem, side by side. They see each other's edits and neither needs a copy of anything. **The tab is shared, so closing it kills both** - retire a peer by closing its pane, not its tab. `fleet.sh --close` does that.

**Independent roles get separate working directories.** Two roles editing the same files for different purposes will destroy each other's work. Give each its own tree (a git worktree, pooled if you have a pool manager) and its own tab:

```bash
spawn.sh planner "$WT_A" "$SCRATCH/planner-brief.md" high   "$STRONG_MODEL"
spawn.sh tracer  "$WT_B" "$SCRATCH/tracer-brief.md"  medium   # cheap tier by default
```

**Read-only roles can share anything.** A reviewer, a reporter, a classifier that only reads - put it wherever it is convenient, usually a peer pane on the tree it is reading.

## The coordination artifact

Two panes must never depend on you relaying text between them. Whatever passes between roles has to survive you losing a turn.

1. **Use the flow's own artifact.** If the flow already defines where a role writes - a plan file, an evidence file, a trace directory, a tracker comment - that is the channel. Do not invent a second one. A flow that already coordinates through a tracker needs nothing from you but panes.
2. **If the flow defines none, the cheapest durable thing is a file** in the shared working directory, named for the handoff. Tell both panes its path in their briefs.
3. **The pane's text is for you, not for the next pane.** Read it to decide what happens next. When you do need to carry a finding across, write it to a file and point the next pane at the file.
4. **Reading a pane can fail.** An agent on the terminal's alternate screen loses rows that never reach scrollback. If a bigger `--lines` reveals no more, ask that agent to write its full response to a file and reply with the path, then read the file.

## The loop

**Brief.** Every prompt is a file on disk, never typed inline. A pane that stalls, gets interrupted, or loses a turn is then recovered with one re-send of a file that still exists.

A role's brief carries: its role in the flow's own words, the artifact it reads, the artifact it writes, what "done" looks like, and the boundary it must not cross. Not a solution - a role handed a mandated approach follows it past the point where it stops working.

**Name the branch the pane works on, not just the branch it integrates into.** "Base your work on `X`, rebase onto `origin/X` first" reads as *work on X* - and a pooled tree handed over detached means checking out the shared branch is the obvious next move. Every pane that was told which integration branch to target and not which branch to commit on pushed straight to the integration branch. "Do not merge" does not cover it: nothing was merged. Say the working branch by name, say never to push the integration branch, and back it with a `pre-push` hook - the prompt is what already failed.

Tell every long-lived role to **commit or flush early and often**. A pane can die with a full context and nothing on disk, and then its replacement inherits a summary instead of work.

**Launch, then verify submission.** A prompt can land in the composer unsent. `send.sh` polls for `working` and retries `enter`. Never assume.

**Wait on the fleet, never on one pane.**

```bash
wait-any.sh 'driver|navigator' 3000 25   # background it; the harness notifies you
```

The first role to settle is the one that needs you. Waiting on a specific pane while another has been idle for ten minutes is the most common way to waste wall clock.

**Read, then advance.** `done` means the process stopped talking, not that the work is right. Read the pane, then check the artifact yourself - the file exists, the test ran, the state changed. Then send the next brief to whichever pane the flow says acts next.

**Release.** A finished pane holding a worktree blocks the next launch. `fleet.sh --close <name>`, return the lease, verify the pool is actually free.

## Escalate by forking, not by briefing a stranger

When a call is genuinely yours to make and above your pay grade, fork the conversation that holds the evidence and ask a stronger model one question:

```bash
advise.sh <agent-name|session-id|self> <question-file> [effort]   # claude-opus-5, read-only
```

**Fork rather than spawn, because the summary is the thing in doubt.** A fresh advisor can only be told where the reasoning stands, and a hand-written recap of a long run is exactly what you cannot trust at the moment you need help. A fork sees what was actually tried, what the tool output actually said, and which assumption was never checked. In practice a forked advisor's first move is often to correct the question: asked about "line 66", it answered that the line number came from a pre-compaction summary and the text had since moved to line 79. A fresh advisor would have answered the wrong question well.

**Fork the pane that has the evidence, not yourself.** Fork a worker when the question is about what that worker did or found. Fork yourself when the question is about the run as a whole - sequencing, whether a finding is worth a ticket, whether to accept a verdict. Forking is free of side effects on the parent: `--fork-session` writes a new session file and never appends to the original, and the live pane keeps working while its fork is consulted.

**Read-only by construction.** A fork inherits the worker's tool permissions *and* a history that reads "I am mid-implementation", so asking it nicely to only advise is the weakest available guard - the same class of mistake as naming the integration branch and expecting a pane to infer the working branch. `advise.sh` runs the fork in `plan` permission mode with the mutating tools denied.

**Escalate on judgment, not on facts you have not looked up yet.** A red check on a PR looked like an escalation and was not: one `gh pr view --json baseRefOid` showed the PR had been tested against a base predating the fix, which no amount of reasoning would have produced. Spend an advisor on questions where the evidence is already in and the reading of it is what is hard: is this reviewer's diagnosis right, is this contradiction real, is this worth reverting.

**Pin session ids at launch.** Herdr reports a pane and a cwd, never a session id, and a pane that shells out to `claude -p` writes newer session files in the same cwd - so "the newest session for this tree" is not the agent's session. `spawn.sh` generates a uuid, passes `--session-id`, and records it as the fifth column of `fleet.tsv`. For an unpinned agent `advise.sh` guesses the newest and says so on stderr; treat that line as a claim to check, not a log.

## Rules

1. **Do not do the roles' work.** The moment you fix something yourself you stop tracking everyone else, and the flow's record no longer matches what happened.
2. **Do not invent protocol the flow does not have.** No tickets, no verdict conventions, no review stages unless the flow defines them. If the flow is silent on something you need, the answer is the cheapest durable artifact, not a new process.
3. **One pane, one role, named for the role.** The tab label is your only index from a pane back to what it is doing. Never reuse a name.
4. **Prompts are files.** Always.
5. **Verify submission, verify completion.** Two separate checks, both cheap, both skipped at your peril.
6. **A gate nothing reads is not a gate.** If your flow says a role must approve before the next step, something has to actually read that approval. Otherwise you have a convention. And an approval that predates the code it approves is not an approval: when a role fixes a finding, the verdict has to be re-issued or the record now contradicts the tree. Two merges in one run read as "merged over an objection" purely because the fix landed after the review comment and nobody said so.
7. **Open every brief by countermanding the composer.** The composer can already hold text you did not write - a suggested next instruction, sitting unsent - and `agent prompt` *appends*. Whatever is there becomes the first line of your brief. One sentence at the top ("ignore any partial line above this one; this message is the complete instruction") costs nothing and stops a suggestion like "merge it" or "update the verdict to APPROVE" from arriving as if you had said it.
8. **Release what you hold.**

## Failure modes

| symptom | what it is | what to do |
|---|---|---|
| pane idle, prompt sitting in the composer | never submitted | `send.sh` again; it retries `enter` |
| every pane frozen, no events anywhere | account-level stall, not your bug | wait; on resume send one `esc`, then re-send the brief file. Nothing is lost if rule 4 held |
| whole fleet stops at once, each pane on a "wait for the limit to reset / ask your admin" modal | the account's usage window ran out | **do not send `esc`** - the modal treats it as quit. Re-authenticating elsewhere does not reach a running process either: credentials are read at startup, so a live pane answers every later prompt with "not logged in". `respawn.sh` per pane - the session is on disk keyed by cwd, and `--continue` restores it |
| pane died after doing the work | error before it could report | check the artifact first. Usually only the report is missing - ask for the report, not a redo |
| pane dies on an auth or login error, always deep into a long run | the process is unrecoverable even though a fresh one authenticates fine | do not try to revive it. Read its worktree - committed work survives. Close the pane, relaunch **the same name on the same tree**, and brief the replacement with "your work is committed, do not start over" plus the commit list. Tell every pane to commit early for exactly this reason |
| closing one pane took its neighbour with it | you closed the tab, and a peer shared it | close the pane; close the tab only when it is the last one |
| pane `done`, nothing produced | it hit a wall and summarized | read the pane in full, not the last line |
| status says `done` or `idle` but the pane will not take a new agent | the claude process is alive and idle at its composer; `done` is about the turn, not the process | read the pane before you act on a status. A bare `❯` with no status line is a dead shell; a `❯` above a model/branch/context line is a live composer |
| read shows a truncated answer | agent is on the alternate screen | have it write the response to a file, read the file |
| two panes overwrote each other | they shared a tree and should not have | separate worktrees; re-run the loser |
| launches queue, nothing starts | out of trees or panes | `fleet.sh --stuck`, close what is finished |
| peer start fails | the source pane's tab is gone | peers need a live source; start a standalone pane instead |
| every command starts failing with ENOSPC, including your own | `/tmp` is a tmpfs, so it is the same RAM that caps your pane count - and it fills with the full-tree copies reviewers make to test against a clean checkout. Two reviewer scratch trees cost more than a pane | check `df -h /tmp` before blaming memory. Brief roles to scratch inside their own worktree, not `/tmp`. Reclaim from closed panes only, and only after confirming the tree is not a git repo with unpushed work - a scratch copy has no `.git` at all |

## Cost

**Two dials, not one: model and effort.** A fleet where every pane runs the strongest model at the highest effort burns a budget on roles that never needed either. Pick the pair per role:

| the role | model | effort | why |
|---|---|---|---|
| decides what happens next, holds the whole run | `claude-opus-5` | high / max | the one place reasoning compounds |
| needs judgment or breadth, but the thinking is not the hard part | `claude-opus-4-8` | high | a stronger first answer without paying for thinking round-trips |
| executes an already-settled plan, or checks work against a stated rule | `claude-sonnet-4-6` | high | the spec did the reasoning already |
| the same, where the plan leaves nothing to work out | `claude-sonnet-4-6` | medium | |
| purely mechanical - reformat, collect, tabulate, grep-and-tabulate | `claude-haiku-4-5` or `claude-sonnet-4-6` | low | |

**`claude-sonnet-5` is excluded. Never launch it, in any role, at any effort.** It is not a capability judgment - it is a standing cost decision by the owner of this fleet. It has no exception and needs no case-by-case reasoning.

**Never pass a bare alias.** `--model sonnet` resolves to *the latest* Sonnet, which is `claude-sonnet-5` - the one model that is excluded. `opus` drifts the same way the moment a new Opus ships. Always pass the full id.

Model facts come from documentation, never from recall: the `claude-api` skill's `shared/models.md`, or the Models API for live capability data (`client.models.retrieve(id)`, then `caps["effort"]`). **Never append a date suffix to an id** - the ids above are complete as written. This table is maintained by hand as models come and go; when a row looks stale, check the source rather than guessing a successor.

Corollaries:

- **The cheap tier is the default; the strong model is the opt-in.** Reverse it and the fleet drifts back to all-strong one launch at a time. The launch scripts default to `claude-sonnet-4-6` for this reason.
- **A mistyped effort does not fail - it downgrades silently.** The ladder is `low`/`medium`/`high`/`xhigh`/`max` and it is the same on every model here, including `claude-haiku-4-5` (verified: `claude --model <id> --effort <level> -p` on each). An unrecognised value only prints `Warning: Unknown --effort value` and runs at the **default** effort, so a whole wave can run far cheaper than you think while every pane looks launched. `agent-start.sh` rejects an unknown level for exactly that reason.
- **Nothing but your own guard keeps an excluded model out.** `claude --model claude-sonnet-5` starts normally; there is no platform-level block. And the exclusion is one keystroke away by accident, because `--model sonnet` resolves to it. Enforce it in the launcher, not in a brief - a prose rule is what fails.
- **`claude-haiku-4-5` holds 200K of context, not 1M.** Fine for a mechanical pane; a worker on a long ticket will run out mid-run, which is a worse failure than being slightly slower.
- **A cheap reviewer will rubber-stamp a checklist.** When the cheap tier verifies a fix, the brief must ask what the fix may have broken, not just whether it was applied.
- **Record model and effort per pane at launch.** Nothing else remembers it, and a run whose settings are unrecoverable cannot be tuned.
- **A pane blocked on a tree costs the same wall clock as a pane doing nothing.** Watch the ceiling, not the count.

## Keep notes

Keep a running file of what the orchestration itself taught you: a race you did not predict, a brief that produced the wrong shape, a handoff that needed an artifact you had not thought of. That file is the only durable output of the coordination, as opposed to the work.

## Scripts

In `scripts/`, needing `herdr` and `jq`:

| script | what it does |
|---|---|
| `fleet-reg.sh [--dir]` | print this project's register path, creating its directory |
| `send.sh <agent> <file>` | send a prompt file and verify it was submitted |
| `spawn.sh <name> <cwd> <brief> [effort] [model]` | new tab, new pane, agent started, brief sent, session id pinned and recorded |
| `split-peer.sh <agent> <peer> <brief> [effort] [model]` | second pane in the same tab, same tree - the tandem primitive |
| `respawn.sh <name> <old-pane> <cwd> <brief> [effort] [model] [session-id]` | close a pane whose process is alive but unusable, restart on the same tree, keep the context |
| `advise.sh <agent\|session-id\|self> <question> [effort]` | fork a session to `claude-opus-5`, read-only, for one hard call |
| `wait-any.sh <regex> [max] [interval]` | return when the first matching pane settles |
| `fleet.sh [regex] \| --stuck \| --close <name>` | who exists, who is waiting on you, close one pane peer-safely |

**The register lives outside the project.** `spawn.sh`, `split-peer.sh` and `advise.sh` record and read one file per project:

```
~/.agents/fleets/<project>/fleet.tsv        # $FLEET_HOME/<project>/fleet.tsv
```

`<project>` is the basename of the repo's **main** worktree, resolved through `git rev-parse --git-common-dir`, so every linked worktree of one repo shares a single register - which is what a fleet spread across worktrees needs. Outside a git repo it falls back to the basename of `$PWD`.

This is keyed to the project and not to cwd on purpose. The old `./fleet.tsv` default dropped an untracked file in whatever directory the orchestrator stood in, and made the path move with you: spawn from the repo root, later call `advise.sh` from a worktree, and it read a register that was not there - then fell back to guessing the newest session, the exact guess pinned session ids exist to prevent.

Override with `REG=<file>` for one exact register, or `FLEET_HOME=<dir>` to relocate the tree. Two repos with the same directory name share one register; set either variable if you run fleets in both at once.
