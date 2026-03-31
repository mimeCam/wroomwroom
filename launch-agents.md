
## macOS — LaunchAgents

See `~/Library/LaunchAgents/openloop*.plist`

### Commands

```bash
# Register & start
launchctl load ~/Library/LaunchAgents/foo.plist

# Stop & unregister
launchctl unload ~/Library/LaunchAgents/foo.plist

# Stop a service by label (keeps plist)
launchctl remove foo.label

# List loaded services
launchctl list | grep foo

# Start an already-loaded service
launchctl start foo.label
```


## Linux — systemd User Services

Per-user services. Start when the user's systemd instance runs. No root needed.

~/.config/systemd/user/openloop*.service

### Commands

```bash
# Reload after adding/editing unit files
systemctl --user daemon-reload

# Enable (auto-start) + start now
systemctl --user enable --now openloop-api

# Start / stop / restart
systemctl --user start openloop-api
systemctl --user stop openloop-api
systemctl --user restart openloop-api

# List active user services
systemctl --user list-units --type=service

# List all unit files (including inactive)
systemctl --user list-unit-files --type=service

# Check status
systemctl --user status openloop-api

# View logs
journalctl --user -u openloop-api
```

### Boot without login (linger) - Linux

User services only run when the user's systemd session exists. To start at boot without login:

```bash
loginctl enable-linger $(whoami)
```

One-time command per user. Enables systemd --user instance at boot for all user services. No root needed when enabling for yourself.
