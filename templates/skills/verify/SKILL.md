---
name: verify
description: Drive the real <app/CLI> end-to-end to observe a change working — not the test gate.
---

Verification is not the gate.
`make check` proves the code is well-formed; this skill proves the change behaves in the running <app>.
Fill in each section for this repo and delete the placeholders.

## Launch

<How to start the real thing: the command, required env, and the credential-free mode (fake/echo provider, --dry-run flag) so verification never needs live secrets.>

## A worked recipe

<The canonical end-to-end pass: start it, poke it, observe the effect, with real copy-pasteable commands and the output that proves success.>

## Negative probe

<One thing that must FAIL — bad auth rejected, malformed input refused.
A guard you never see reject anything might not be wired at all.>

## Cleanup and gotchas

<Ports that stay bound, temp dirs, background processes to pkill, ordering constraints.>
