# Workflow Schedule

## Repeat Interval (every_secs)

The `every_secs` field defines the minimum time between workflow runs.

| Value | Behavior |
|-------|----------|
| **0** | Manual — workflow runs once when triggered, never repeats |
| **1** | Continuous — will schedule next run immediately after workflow finished |
| **60** | Every minute |
| **300** | Every 5 minutes |
| **600** | Every 10 minutes |
| **3600** | Every hour |
| **86400** | Every day |

## When to use what

- **0 (Manual)**: One-off analyses, on-demand reports, workflows you trigger manually
- **1 (Continuous)**: Real-time monitoring, event-driven processing, continuous integration
- **60-300**: Frequent checks (PR monitoring, build status, service health)
- **600-3600**: Periodic summaries, scheduled reports, regular maintenance
- **3600+**: Daily digests, weekly reviews, long-running batch processes

## How it works

Workflows run every N seconds. Different workflows run in parallel. But a single workflow will not begin until its previous run completed.
