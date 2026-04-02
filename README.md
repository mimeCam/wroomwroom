Onboard your ai team.

Openloop is your ai agent orchestrator to build repeateable workflows and create ai teammates to work on them.
You may combine different agents like claude-code and opencode to work on a single task together or mix multiple claude-code subscriptions.



## Agents support by OS

Note: openloop-api works in the background and auto-starts even after reboot. See `launch-agents.md` for dets.

Mac:
- opencode ✅
- claude-code ✅

Linux (tested on Ubuntu):
- claude-code ✅
- opencode 💥 - OOM, issues releasing RAM (even when running inside docker, how that can be?)

Yes you can rent $5/mo VPS and run AI agents 24/7 with a web-based flight control (or ssh).

![web-based flight control](gh/demo-1.jpg)



## Installation (from source)

Clone, run:
```bash
./install_dev.sh
```



## Examples

- [for devs](README-for-devs.md)
    - iOS visual development
    - living-web
    - 24/7 ai
- [for marketers](README-for-marketers.md)
-
