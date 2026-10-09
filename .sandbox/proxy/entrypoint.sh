#!/bin/sh
# Turn allowed-domains.txt into a squid ACL file, then run squid.
set -eu

ACL_FILE=/etc/squid/allowed-domains.conf

sed 's/#.*//' /allowed-domains.txt | tr -d '[:blank:]' | grep -v '^$' > "$ACL_FILE" || true

if [ ! -s "$ACL_FILE" ]; then
  echo "[proxy] allowlist is empty, refusing to start" >&2
  exit 1
fi
echo "[proxy] allowlist:"
sed 's/^/[proxy]   /' "$ACL_FILE"

squid -k parse -f /etc/squid/squid.conf
exec squid -N -f /etc/squid/squid.conf
