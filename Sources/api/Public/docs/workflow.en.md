# Workflows

Think about how work actually gets done at your company. A VP sets a direction, tech makes it happen, marketing hypes it. Architect talks systems, designer enforces consistent branding, frontend/mobile/backend/ml devs make things happen, CEO inspires.

**Workflows encode exact processes as AI automation.**

## What is a workflow?

A workflow defines *what work happens*, *who does it*, and *how often*. It's an automated meeting structure—except instead of people in a conference room, you have AI personas working through levels in a waterfall-like structure.

Each workflow has:
1. **A schedule** — Daily standup? Weekly code review? Hourly monitoring? One-time feature request?
2. **Levels of personas** — Who participates, in what order, building on each other's work

## How levels work (this is the magic)

Levels run sequentially. Level 0 goes first. Level 1 sees Level 0's output and builds on it. Level 2 sees Level 1 work and so on.

This mirrors how work actually flows:

| Real World | OpenLoop |
|------------|----------|
| Gathering research | Level 0: Researcher persona + VP idea guy |
| Making Decision | Level 1: Architect persona + UIX Designer |
| Implementing | Level 2: Frontend persona + Backend persona |

Each level provides expertise. Each persona sees what came before and does their specific job with it.


## From Idea to Shipped: The Iteration Model

Think about how a feature actually travels through a company:

```
💡 CEO (dreamer) has a vision
    ↓
🔍 CTO/Research investigates feasibility
    ↓
📋 Business writes the plan, researches competition
    ↓
📢 Marketing flags constraints: "we can't say that"
    ↓
🎨 Design creates mockups
    ↓
💻 Developers build it
    ↓
✅ QA tests it
```

Each level is an **iteration**—the feature gets more refined as it passes through different hands. Level 0 is raw input ("build feature X"). Level 1 is analysis ("here how we could approach this in a unique way"). Next Level ("make it", or "ship it" or "fix this first"). 

It's waterfall—each stage hands off to the next.

## The Sandbox: Design Any Flow

Here's where it gets interesting. OpenLoop is a **process sandbox**. You're not stuck with how your company works—you can model how you *wish* it worked.

**What if...**

- You added a security reviewer before development happens?
- You removed the CTO signoff bottleneck—what breaks?
- You discovered you're missing a role—maybe a technical writer?
- Design reviewed code for UX implications?

The workflow editor is your organizational laboratory. Instead of endless meetings arguing about "how should this work?", you design the flow once, hit play, and watch different stakeholders interact. See what works. Learn from the simulation.

This is the point—OpenLoop lets you experiment with organizational structures without real-world fallout. Your personas will collaborate authentically within their expertise, just like real people would.

## How workflows fit together

- **[Personas](persona)** are the workers assigned to each level—they're the "who"
- **[Instances](instance)** run workflows on schedule—they're the "where and when"

Workflows are the bridge between "how our team actually works" and "automated execution that works the same way."

## Levels & Isolation

The information passed down from upper level to the next. There can be 1 or more personas on each level. Personas from the same level do not cooperate - they only see the context information from the level above and the main ask that you (user) specified.

## Multi-Persona Levels Run in Read-Only Mode

When a level contains **2 or more personas**, all personas in that level execute in **read-only (RO) mode**. They operate in a *reporting, research, and planning* capacity — analyzing, synthesizing, and producing reports without making changes to the codebase or project files.

**Why?** Multiple personas running in read-write mode simultaneously would create conflicting changes. Instead, they collaborate by producing individual reports and recommendations.

The next level — if it contains a **single persona** — can run in **read-write (RW) mode**. That persona receives the collective output from the previous level's research and reports, then acts on it with full write access.

This RO → RW cascade ensures clean, conflict-free execution: **many minds analyze, then one hand acts.**
