#!/usr/bin/env bash
# Copy Docker image tarballs to hosts from ips.txt and load them with sudo docker load.
# Run from the directory that contains ips.txt and the .tar files.
# Requires: passwordless SSH (e.g. ssh-copy-id) and passwordless sudo for docker on remotes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IP_FILE="ips.txt"
REMOTE_USER="${REMOTE_USER:-ubuntu}"
REMOTE_DIR="/tmp/docker-load-$$"

# Read IPs: skip comments and empty lines
mapfile -t IPS < <(grep -v '^#' "$IP_FILE" | grep -v '^[[:space:]]*$' || true)
if [[ ${#IPS[@]} -eq 0 ]]; then
  echo "No IPs found in $IP_FILE"
  exit 1
fi

# All .tar files in current directory
TARS=(*.tar)
if [[ ! -f "${TARS[0]}" ]]; then
  echo "No .tar files in $SCRIPT_DIR"
  exit 1
fi

echo "IPs: ${IPS[*]}"
echo "Tarballs: ${TARS[*]}"
echo "SSH user: $REMOTE_USER"
echo

for ip in "${IPS[@]}"; do
  echo "=== $ip ==="
  echo "  Creating $REMOTE_DIR and copying tarballs..."
  ssh -o StrictHostKeyChecking=accept-new "$REMOTE_USER@$ip" "mkdir -p $REMOTE_DIR"
  scp -o StrictHostKeyChecking=accept-new "${TARS[@]}" "$REMOTE_USER@$ip:$REMOTE_DIR/"

  echo "  Loading images (sudo docker load)..."
  ssh "$REMOTE_USER@$ip" "cd $REMOTE_DIR && for f in *.tar; do sudo docker load -i \"\$f\"; done"

  echo "  Cleaning up..."
  ssh "$REMOTE_USER@$ip" "rm -rf $REMOTE_DIR"
  echo "  Done."
  echo
done

echo "All hosts finished."

