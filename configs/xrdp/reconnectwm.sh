#!/bin/bash
# xRDP reconnection hook — sync display when user reconnects to existing session

export XRDP_SESSION="${DISPLAY:-}"
openclaw-sync-display "$(whoami)" || true
