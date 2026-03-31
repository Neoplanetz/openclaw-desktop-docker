#!/bin/bash
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
if [ -r /etc/profile ]; then
    . /etc/profile
fi

# Capture xRDP display (e.g. :10, :11) for display sync
# (mode is read from ~/.openclaw/.env — login shells don't inherit Docker env)
export XRDP_SESSION="${DISPLAY:-}"
openclaw-sync-display "$(whoami)" || true

exec dbus-launch --exit-with-session startxfce4
