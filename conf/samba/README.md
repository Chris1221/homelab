# Samba — Time Machine & shares

Samba runs **natively** on the host (`smbd`/`nmbd` + `avahi-daemon`), not in the
compose stack. SMB needs host ports 137-139/445 and mDNS on 5353, and there is
nothing for Traefik to route, so it stays on the host. This directory tracks the
Time Machine and 8TB-share additions; the base `/etc/samba/smb.conf` is stock
Ubuntu plus the pre-existing `[belvale_2tb]` share (`/media/med_2tb`, guest, rw).

## Layout

| Piece | Purpose |
|---|---|
| `timemachine.conf` | `smb.conf` fragment: global `vfs_fruit` settings + the `[timemachine]` share |
| `avahi-timemachine.service` | mDNS `_adisk._tcp` advertisement so macOS auto-discovers the target |
| `store_share.conf` | `smb.conf` fragment: the `[share]` share — a general-purpose guest/rw share, same style as `[belvale_2tb]`, on the 8TB drive |

Backing store: `/srv/store/timemachine` and `/srv/store/share` — ext4 on the
8 TB drive (`srv-store.mount`).

## Deploy / update

`scripts/install_host_config.sh` does everything below idempotently (and also
installs the med_2tb mirror units). It reads the `tm` password from
`op://homelab/homelab_env/SAMBA_TM_PASS` (or `.env`, or prompts). The manual
steps are kept here for reference:

```bash
# 1. Dedicated Samba user (system account, no login). One-time.
sudo useradd -r -M -d /srv/store/timemachine -s /usr/sbin/nologin tm
sudo smbpasswd -a tm            # set a password; store it in 1Password
sudo chown -R tm:tm /srv/store/timemachine
sudo chmod 700 /srv/store/timemachine

# 2. smb.conf fragment
sudo install -m 0644 conf/samba/timemachine.conf /etc/samba/timemachine.conf
#    Add this line inside the [global] section of /etc/samba/smb.conf (once):
#        include = /etc/samba/timemachine.conf

# 3. mDNS advertisement
sudo install -m 0644 conf/samba/avahi-timemachine.service \
    /etc/avahi/services/timemachine.service

# 3b. General-purpose 8TB share
sudo mkdir -p /srv/store/share
sudo chown chris:chris /srv/store/share
sudo install -m 0644 conf/samba/store_share.conf /etc/samba/store_share.conf
#    Add this line at the end of /etc/samba/smb.conf (once):
#        include = /etc/samba/store_share.conf

# 4. Validate and reload
sudo testparm -s
sudo systemctl reload smbd
sudo systemctl restart avahi-daemon   # restart, not reload - reload does not always pick up new files

# 5. Firewall: ufw is default-deny inbound. Allow SMB + mDNS from the LAN.
#    (Tailnet clients are already allowed by Tailscale's own rules.)
sudo ufw allow from 192.168.2.0/24 to any port 445 proto tcp comment 'SMB LAN'
sudo ufw allow from 192.168.2.0/24 to any port 5353 proto udp comment 'mDNS LAN'

# 6. Pin avahi to the real NIC so it stops advertising on every Docker veth.
#    In /etc/avahi/avahi-daemon.conf under [server]:
#        allow-interfaces=enp1s0f0
#    then: sudo systemctl restart avahi-daemon
```

The `include` line goes at the **end** of `/etc/samba/smb.conf`, not inside the
`[global]` block — `timemachine.conf` ends with the `[timemachine]` share
section, so an include mid-`[global]` would re-scope every following stock
global setting (`map to guest`, PAM, …) into the share.

## Verify

```bash
# share is visible and fruit is loaded
smbclient -L localhost -U tm
sudo testparm -sv | grep -Ei 'fruit|vfs objects|time machine'

# from the Mac: Finder should show the host under Locations; then
# System Settings > Time Machine > Add Backup Disk > "timemachine" on <host>
```

## Notes

- `fruit:time machine max size = 2T` in `timemachine.conf` caps the sparsebundle.
  Adjust to ~2-3x the Mac's internal disk.
- The global `vfs objects = catia fruit streams_xattr` also applies to
  `[belvale_2tb]`. That is intentional and generally beneficial for Mac clients;
  if it ever causes trouble on that share, move the `vfs objects` line out of
  `[global]` and into `[timemachine]` only.
- `dk0=adVN=timemachine` in the avahi file must match the share name.
- The avahi file has no `_device-info._tcp` block: GNOME/gvfs already publishes
  one for this host and the name collision makes avahi discard the whole file
  (`Failed to add service ... Local name collision ... ignoring service group`).
- avahi spams the journal registering/withdrawing mDNS on every Docker `veth`.
  To quiet it, set `allow-interfaces=<lan-nic>` (or `deny-interfaces=veth*`) in
  `/etc/avahi/avahi-daemon.conf` and restart. Cosmetic, not required.
