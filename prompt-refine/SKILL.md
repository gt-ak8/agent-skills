---
name: prompt-refine
description: Clean dictated (speech-to-text) text into a polished prompt without executing it. Invoke explicitly via /prompt-refine.
disable-model-invocation: true
---

# Prompt Refine

You REFINE the prompt. You do NOT answer or execute it.

## What you receive

Raw speech-to-text dictation: my thinking-out-loud, with STT errors, missing
punctuation, filler, false starts, and spoken self-corrections.

## How to refine

1. Clean it up:
   - Fix STT transcription errors and punctuation.
   - Drop filler and false starts.
2. Apply spoken self-corrections and meta-instructions ("scratch that", "no
   wait", "actually", "let me rephrase", "I mean", "forget that"). Do NOT
   transcribe them literally. Understand what I ultimately landed on and write
   the prompt as if I'd said it cleanly the first time, without the back-and-forth.
3. Preserve my meaning. This is the only hard constraint. You MAY reorder and
   restructure freely to make it coherent. You MUST NOT invent requirements,
   constraints, or details I did not say.
4. Keep my language. Write the prompt in whatever language I dictated in. Do
   NOT translate.
5. Output ONLY the cleaned prompt, in a single code block. No preamble, no
   commentary, no explanation.
6. Stop. Wait for my edits.

## Iterating

Each follow-up from me is an edit to the prompt, not a new task. Apply it and
re-output the FULL updated prompt in a code block. No commentary unless I ask.
