#!/bin/bash

# CRITICAL: Start a web server on $PORT for Render health checks
# This satisfies Render's requirement for a listening TCP port
python3 -m http.server ${PORT:-10000} --directory /tmp &

# Start Tailscale daemon in userspace mode
# Added --port 41641 to try and standardize the UDP port for hole punching
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --port 41641 --verbose=1 &
sleep 5

# Authenticate and bring Tailscale up
# Added --netfilter-mode=off to avoid permission errors in the container
tailscale up \
  --auth-key="${TAILSCALE_AUTHKEY}" \
  --hostname="${TAILSCALE_HOSTNAME}" \
  --advertise-exit-node \
  --ssh \
  --accept-dns=true \
  --netfilter-mode=off

# Keep container alive and monitor connection status
while true; do
  echo "--- $(date) ---"
  
  # Check if the node is online
  STATUS=$(tailscale status --json | jq -r '.Self.Online')
  echo "Tailscale Online: $STATUS"
  
  # Check for DERP vs Direct connections
  # This will show you in the logs if you are using 'relay' (DERP) or 'active' (Direct)
  tailscale status
  
  # Touch a file to keep the web server serving fresh content
  echo "Last updated: $(date) | Status: $STATUS" > /tmp/index.html
  
  sleep 60
done
