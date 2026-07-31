#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARS_FILE="${PROJECT_DIR}/group_vars/all.yml"

eval "$(python3 - "$VARS_FILE" <<'PYVARS'
import shlex
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
data = yaml.safe_load(path.read_text()) if path.exists() else {}
data = data or {}
root = str(data.get('security_monitoring_data_root', '/opt')).rstrip('/') or '/opt'
def value(name, suffix):
    raw = data.get(name)
    if isinstance(raw, str) and '{{' not in raw:
        return raw.rstrip('/')
    return root + suffix

values = {
    'DATA_ROOT': root,
    'SHARED_DB_DIR': value('shared_database_directory', '/shared-database'),
    'NPM_DIR': value('npm_directory', '/nginx-proxy-manager'),
    'WAZUH_DIR': value('wazuh_directory', '/wazuh'),
    'WAZUH_PERSISTENT_DIR': value('wazuh_persistent_directory', '/wazuh-persistent'),
    'SOCFORTRESS_DIR': value('socfortress_directory', '/wazuh-socfortress'),
    'ZABBIX_DIR': value('zabbix_directory', '/zabbix'),
    'PROXY_NETWORK': str(data.get('docker_proxy_network', 'proxy')),
    'DATABASE_NETWORK': str(data.get('docker_database_network', 'database')),
}
for key, val in values.items():
    print(f'{key}={shlex.quote(val)}')
PYVARS
)"

echo "UWAGA: skrypt usuwa dane Wazuh, Zabbix, NPM i wspólnej MariaDB."
echo "Katalog bazowy: ${DATA_ROOT}"
echo "Docker oraz Zabbix Agent 2 na hoście pozostają zainstalowane."
read -r -p "Wpisz USUN, aby kontynuować: " answer

if [[ "$answer" != "USUN" ]]; then
  echo "Anulowano."
  exit 1
fi

compose_down() {
  local directory="$1"
  shift || true
  if [[ -d "$directory" ]]; then
    (
      cd "$directory"
      docker compose "$@" down --volumes --remove-orphans || true
    )
  fi
}

compose_down /opt/path-gateway
compose_down "${DATA_ROOT}/path-gateway"
compose_down "$ZABBIX_DIR"
compose_down "$WAZUH_DIR/single-node" -f docker-compose.yml -f docker-compose.proxy.yml
compose_down "$NPM_DIR"
compose_down "$SHARED_DB_DIR"

docker rm -f \
  path-gateway \
  zabbix-web-nginx \
  zabbix-web \
  zabbix-server \
  zabbix-db \
  shared-db \
  single-node-wazuh.manager-1 \
  single-node-wazuh.indexer-1 \
  single-node-wazuh.dashboard-1 \
  nginx-proxy-manager \
  nginx-proxy-manager-db 2>/dev/null || true

docker volume ls --format '{{.Name}}' \
  | grep -E '^(single-node_|npm_|zabbix_|shared_db_)' \
  | xargs -r docker volume rm -f

docker network rm \
  "$PROXY_NETWORK" \
  "$DATABASE_NETWORK" \
  npm_internal \
  zabbix_internal 2>/dev/null || true

rm -rf \
  /opt/path-gateway \
  "${DATA_ROOT}/path-gateway" \
  "$ZABBIX_DIR" \
  "$WAZUH_DIR" \
  "$WAZUH_PERSISTENT_DIR" \
  "$SOCFORTRESS_DIR" \
  "$NPM_DIR" \
  "$SHARED_DB_DIR"

echo "Dane kontenerów zostały usunięte."
echo "Docker i Zabbix Agent 2 pozostają zainstalowane."
