#!/usr/bin/env bash
set -euo pipefail

echo "UWAGA: skrypt usuwa dane Wazuh, Zabbix, NPM i wspólnej MariaDB."
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

# Stary wariant z dodatkowym gatewayem.
compose_down /opt/path-gateway

compose_down /opt/zabbix
compose_down /opt/wazuh/single-node \
  -f docker-compose.yml \
  -f docker-compose.proxy.yml
compose_down /opt/nginx-proxy-manager
compose_down /opt/shared-database

docker rm -f \
  path-gateway \
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
  proxy \
  database \
  npm_internal \
  zabbix_internal 2>/dev/null || true

rm -rf \
  /opt/path-gateway \
  /opt/zabbix \
  /opt/wazuh \
  /opt/wazuh-persistent \
  /opt/wazuh-socfortress \
  /opt/nginx-proxy-manager \
  /opt/shared-database

echo "Dane kontenerów zostały usunięte."
echo "Docker i Zabbix Agent 2 pozostają zainstalowane."
