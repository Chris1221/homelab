# systemd units (host)

Hand-deployed host units, tracked here for reference. The host also has
`media-med_2tb.mount` and `srv-store.mount` (not in the repo — plain UUID mounts).

## med_2tb mirror

One-way daily mirror of `/media/med_2tb` (live service data, ntfs-3g) to
`/srv/store/med_2tb_mirror` (ext4, on the 8 TB drive). Local complement to the
weekly off-site restic backup; replaces the old `//raspberrypi/rpi8tb` autofs
mirror (`/etc/auto.rpi8tb`) and the stale `public/med_2tb_backup/` copy on the
8 TB drive.

| File | Installs to |
|---|---|
| `med_2tb_mirror.service` | `/etc/systemd/system/med_2tb_mirror.service` |
| `med_2tb_mirror.timer` | `/etc/systemd/system/med_2tb_mirror.timer` |
| `med_2tb_mirror.exclude` | `/etc/med_2tb_mirror.exclude` |

`rsync -aHx --delete --delete-excluded`. The service refuses to start unless both
`/media/med_2tb` and `/srv/store` are mounted (`RequiresMountsFor` +
`mountpoint` checks) — otherwise `--delete` could wipe the mirror or fill `/`.

### Deploy

`scripts/install_host_config.sh` installs and enables these units (plus the
Samba/Time Machine config) idempotently. Manual steps for reference:

```bash
cd ~/repos/homelab
sudo install -m 0644 conf/systemd/med_2tb_mirror.exclude /etc/med_2tb_mirror.exclude
sudo install -m 0644 conf/systemd/med_2tb_mirror.service /etc/systemd/system/
sudo install -m 0644 conf/systemd/med_2tb_mirror.timer   /etc/systemd/system/
sudo systemctl daemon-reload

# First run: dry-run by hand and eyeball what would copy / delete
sudo rsync -aHx --delete --delete-excluded --numeric-ids \
  --exclude-from=/etc/med_2tb_mirror.exclude --dry-run --stats \
  /media/med_2tb/ /srv/store/med_2tb_mirror/ | tail -30

# Real first run (foreground via the unit), watch the journal
sudo systemctl start med_2tb_mirror.service
journalctl -u med_2tb_mirror.service -f      # Ctrl-C when it finishes

# Enable the daily schedule
sudo systemctl enable --now med_2tb_mirror.timer
systemctl list-timers med_2tb_mirror.timer
```

### Notes

- Runs daily at 03:30 (+ up to 15 min jitter), `Persistent=true` so a missed run
  (host off) fires on next boot. restic runs Sun 00:00 America/Los_Angeles, so no
  overlap.
- Check status: `systemctl status med_2tb_mirror.service`,
  `journalctl -u med_2tb_mirror.service --since -2d`.
- Optional: add an `OnFailure=` unit that pings an uptime-kuma push monitor.
