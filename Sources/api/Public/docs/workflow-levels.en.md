# Levels in a Workflow

Workflows don't run everything at once. They run in **levels** — sequential stages where each level builds on the output of the one before it.

## What are levels?

A level is a stage in your workflow pipeline. Level 0 runs first. Level 1 runs after Level 0 finishes, using its output. Level 2 builds on Level 1, and so on.

Each level contains one or more [personas](persona.md) — the AI workers who do the actual thinking.

```
Level 0  (Research)     →  output  →
Level 1  (Decision)     →  output  →
Level 2  (Implementation)
```

Every persona sees **only** the output from the level directly above it, plus the original ask you provided. They don't see the full history — just what was handed down.

## Read-only vs Read-write

Here's the critical rule:

- **Multi-persona level** (2+ personas) → all run in **read-only (RO)** mode. They research, analyze, and produce reports — but cannot modify files.
- **Single-persona level** (1 persona) → can run in any: **read-only** or **read-write (RW)** mode (config on web or in json). Full write access to act on what previous levels produced. Persona in the last level always runs with **write** access.

**Why?** Multiple personas writing simultaneously would create conflicts. Instead, the system enforces a clean pattern:

> Many minds analyze, then one hand acts.

## Quick example

Say you have a 3-level workflow:

| Level | Personas | Mode | Role |
|-------|----------|------|------|
| 0 | Researcher + VP | RO | Both investigate independently, produce reports |
| 1 | Architect + Designer | RO | Both plan based on Level 0 output |
| 2 | Developer | RW | Implements based on Level 1 plans |

The researcher and VP never see each other's work — they only see the ask. The architect and designer see Level 0's combined output. The developer sees Level 1's plans and executes.

## Isolation between personas

Personas on the same level don't cooperate with each other. They work independently, each producing their own output. The next level receives all outputs from the level above as combined context.

This isolation is intentional — it prevents groupthink and ensures each persona contributes their unique expertise without being influenced by peers.

## See also

- [Workflows](workflow.md) — the full picture of how workflows work
- [Personas](persona.md) — understanding the workers assigned to each level
