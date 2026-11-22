#!/usr/bin/env bash
# Install the host-side config that lives outside the compose stack:
#   - Samba Time Machine share + general-purpose 8TB share  (conf/samba/)
#   - med_2tb -> /srv/store mirror timer  (conf/systemd/)
#
# Idempotent: safe to re-run. Run as your normal user (not root) so the
# 1Password CLI works; privileged steps use sudo.
#
# Assumes disks are already mounted and base packages (samba, rsync,
# avahi-daemon) are installed.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TM_DIR=/srv/store/timemachine
OP_TM_PASS_REF="op://homelab/homelab_env/SAMBA_TM_PASS"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
skip() { printf '    \033[2m(skip) %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root (needed for 'op')"
for c in sudo install rsync smbpasswd pdbedit testparm mountpoint systemctl; do
  command -v "$c" >/dev/null || die "missing command: $c"
done
mountpoint -q /srv/store     || die "/srv/store is not mounted"
mountpoint -q /media/med_2tb || die "/media/med_2tb is not mounted"

say "Caching sudo credentials"
sudo -v

# ---------------------------------------------------------------------------
say "Samba: dedicated 'tm' user"
if id tm &>/dev/null; then
  skip "user tm exists"
else
  sudo useradd -r -M -d "$TM_DIR" -s /usr/sbin/nologin tm
fi

say "Samba: 'tm' SMB password"
if sudo pdbedit -L 2>/dev/null | grep -q '^tm:'; then
  skip "tm already in the Samba passdb"
else
  pw="${SAMBA_TM_PASS:-}"
  if [[ -z "$pw" && -f "$REPO/.env" ]]; then
    pw="$(grep -E '^SAMBA_TM_PASS=' "$REPO/.env" | tail -1 | cut -d= -f2- \
          | sed -e 's/^["'\'']//' -e 's/["'\'']$//' || true)"
  fi
  if [[ -z "$pw" ]] && command -v op >/dev/null; then
    pw="$(op read "$OP_TM_PASS_REF" 2>/dev/null || true)"
  fi
  if [[ -z "$pw" ]]; then
    read -rsp "    New SMB password for 'tm': " pw; echo
    [[ -n "$pw" ]] || die "empty password"
    echo "    -> save this as $OP_TM_PASS_REF and re-run scripts/restore_env.sh"
  fi
  printf '%s\n%s\n' "$pw" "$pw" | sudo smbpasswd -s -a tm >/dev/null
  unset pw
fi

say "Samba: $TM_DIR ownership"
sudo chown -R tm:tm "$TM_DIR"
sudo chmod 700 "$TM_DIR"

say "Samba: smb.conf fragment"
sudo install -m 0644 "$REPO/conf/samba/timemachine.conf" /etc/samba/timemachine.conf
if grep -q 'include = /etc/samba/timemachine.conf' /etc/samba/smb.conf; then
  skip "include line already in smb.conf"
else
  printf '\n# Time Machine share (managed in homelab repo: conf/samba/)\ninclude = /etc/samba/timemachine.conf\n' \
    | sudo tee -a /etc/samba/smb.conf >/dev/null
fi

say "Samba: general-purpose store share"
sudo mkdir -p /srv/store/share
sudo chown chris:chris /srv/store/share
sudo install -m 0644 "$REPO/conf/samba/store_share.conf" /etc/samba/store_share.conf
if grep -q 'include = /etc/samba/store_share.conf' /etc/samba/smb.conf; then
  skip "include line already in smb.conf"
else
  printf '\n# General-purpose share on the 8TB drive (managed in homelab repo: conf/samba/)\ninclude = /etc/samba/store_share.conf\n' \
    | sudo tee -a /etc/samba/smb.conf >/dev/null
fi

say "avahi: Time Machine service"
sudo install -m 0644 "$REPO/conf/samba/avahi-timemachine.service" /etc/avahi/services/timemachine.service

say "avahi: pin to the primary NIC"
NIC="$(ip route show default | awk '{print $5; exit}')"
[[ -n "$NIC" ]] || die "could not determine default NIC"
if grep -q '^allow-interfaces=' /etc/avahi/avahi-daemon.conf; then
  skip "allow-interfaces already set ($(grep '^allow-interfaces=' /etc/avahi/avahi-daemon.conf))"
else
  sudo sed -i "/^\[server\]/a allow-interfaces=$NIC" /etc/avahi/avahi-daemon.conf
fi

say "ufw: allow SMB + mDNS from the LAN"
IP_CIDR="$(ip -o -f inet addr show "$NIC" | awk '{print $4; exit}')"   # e.g. 192.168.2.93/24
ip="${IP_CIDR%/*}"; prefix="${IP_CIDR#*/}"
case "$prefix" in
  24) LAN="${ip%.*}.0/24" ;;
  16) LAN="${ip%.*.*}.0.0/16" ;;
  *)  LAN="$IP_CIDR"; echo "    (note: unusual prefix /$prefix, using $LAN verbatim)" ;;
esac
sudo ufw allow from "$LAN" to any port 445 proto tcp  comment 'SMB LAN'  >/dev/null
sudo ufw allow from "$LAN" to any port 5353 proto udp comment 'mDNS LAN' >/dev/null

# ---------------------------------------------------------------------------
say "systemd: med_2tb mirror units"
sudo install -m 0644 "$REPO/conf/systemd/med_2tb_mirror.exclude" /etc/med_2tb_mirror.exclude
sudo install -m 0644 "$REPO/conf/systemd/med_2tb_mirror.service" /etc/systemd/system/med_2tb_mirror.service
sudo install -m 0644 "$REPO/conf/systemd/med_2tb_mirror.timer"   /etc/systemd/system/med_2tb_mirror.timer
sudo systemctl daemon-reload
sudo systemctl enable --now med_2tb_mirror.timer >/dev/null

# ---------------------------------------------------------------------------
say "Validating and reloading"
sudo testparm -s >/dev/null
sudo systemctl reload smbd
sudo systemctl restart avahi-daemon

cat <<EOF

Done. Next steps (not automated):
  - initial full mirror:   sudo systemctl start med_2tb_mirror.service
                           journalctl -u med_2tb_mirror.service -f
  - verify TM discovery:   avahi-browse -rt _adisk._tcp
  - on the Mac:            add smb://<host>/timemachine as a backup disk (user: tm)
EOF
