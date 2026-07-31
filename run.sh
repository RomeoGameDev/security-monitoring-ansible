#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

DATA_ROOT=""
HTTPS_MODE=""
CREATED_VARS=false

show_help() {
  cat <<'HELP'
Użycie:
  ./run.sh [opcje]

Opcje:
  -d, --data-root ŚCIEŻKA  Zapisz dane stosu pod wskazaną ścieżką,
                           np. /data/security-monitoring
  -n, --no-https          Nie generuj ani nie podpinaj certyfikatu self-signed
      --no-self-signed    Alias opcji --no-https
      --https             Włącz zarządzany certyfikat self-signed
  -h, --help              Pokaż pomoc

Przykłady:
  ./run.sh
  ./run.sh -d /data/security-monitoring
  ./run.sh -d /data/security-monitoring -n

Podane opcje są zapisywane w group_vars/all.yml i obowiązują także przy
kolejnych uruchomieniach bez argumentów.
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--data-root)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "BŁĄD: opcja $1 wymaga ścieżki."
        exit 2
      fi
      DATA_ROOT="$2"
      shift 2
      ;;
    -n|--no-https|--no-self-signed)
      HTTPS_MODE="disabled"
      shift
      ;;
    --https)
      HTTPS_MODE="enabled"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "BŁĄD: nieznana opcja: $1"
      echo
      show_help
      exit 2
      ;;
  esac
done

if [[ -n "$DATA_ROOT" ]]; then
  DATA_ROOT="${DATA_ROOT%/}"
  if [[ "$DATA_ROOT" != /* || "$DATA_ROOT" == "/" ]]; then
    echo "BŁĄD: --data-root musi być bezwzględną ścieżką inną niż /."
    exit 2
  fi
  if [[ "$DATA_ROOT" =~ [[:space:]] ]]; then
    echo "BŁĄD: --data-root nie może zawierać spacji."
    exit 2
  fi
fi

if [[ ! -f group_vars/all.yml ]]; then
  cp group_vars/all.yml.example group_vars/all.yml
  chmod 600 group_vars/all.yml
  CREATED_VARS=true
fi

# Zapisuje wybrane opcje w istniejącym YAML bez przebudowywania komentarzy i kolejności.
if [[ -n "$DATA_ROOT" || -n "$HTTPS_MODE" ]]; then
  DATA_ROOT="$DATA_ROOT" HTTPS_MODE="$HTTPS_MODE" python3 - <<'PY'
import json
import os
import re
from pathlib import Path

path = Path("group_vars/all.yml")
lines = path.read_text(encoding="utf-8").splitlines()
updates = {}

data_root = os.environ.get("DATA_ROOT", "")
https_mode = os.environ.get("HTTPS_MODE", "")

if data_root:
    updates.update(
        {
            "security_monitoring_data_root": json.dumps(data_root),
            "security_monitoring_bind_persistent_data": "true",
            "shared_database_directory": json.dumps(f"{data_root}/shared-database"),
            "npm_directory": json.dumps(f"{data_root}/nginx-proxy-manager"),
            "wazuh_directory": json.dumps(f"{data_root}/wazuh"),
            "wazuh_persistent_directory": json.dumps(f"{data_root}/wazuh-persistent"),
            "socfortress_directory": json.dumps(f"{data_root}/wazuh-socfortress"),
            "zabbix_directory": json.dumps(f"{data_root}/zabbix"),
        }
    )

if https_mode == "disabled":
    updates["npm_self_signed_enabled"] = "false"
    updates["npm_force_ssl"] = "false"
elif https_mode == "enabled":
    updates["npm_self_signed_enabled"] = "true"
    updates["npm_force_ssl"] = "false"

seen = set()
result = []
pattern = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:")
deletions = {"security_monitoring_required_mountpoint"}

for line in lines:
    match = pattern.match(line)
    key = match.group(1) if match else None
    if key in deletions:
        continue
    if key in updates:
        if key not in seen:
            result.append(f"{key}: {updates[key]}")
            seen.add(key)
        continue
    result.append(line)

missing = [key for key in updates if key not in seen]
if missing:
    if result and result[-1] != "":
        result.append("")
    result.append("# Ustawienia zapisane przez run.sh")
    result.extend(f"{key}: {updates[key]}" for key in missing)

path.write_text("\n".join(result) + "\n", encoding="utf-8")
PY
  chmod 600 group_vars/all.yml
fi

if [[ "$CREATED_VARS" == "true" ]]; then
  echo "Utworzono group_vars/all.yml i zapisano podane opcje."
  echo "Sprawdź hasła i pozostałe ustawienia, a następnie uruchom ./run.sh ponownie."
  exit 1
fi

if grep -q "CHANGE_ME" group_vars/all.yml; then
  echo "BŁĄD: zmień wszystkie wartości CHANGE_ME w group_vars/all.yml."
  exit 1
fi

if [[ -n "$DATA_ROOT" ]]; then
  echo "Katalog danych zapisany w group_vars/all.yml: $DATA_ROOT"
fi
if [[ "$HTTPS_MODE" == "disabled" ]]; then
  echo "Self-signed HTTPS wyłączony w group_vars/all.yml."
elif [[ "$HTTPS_MODE" == "enabled" ]]; then
  echo "Self-signed HTTPS włączony w group_vars/all.yml."
fi

echo
echo "============================================================"
echo " Instalacja kolekcji Ansible"
echo "============================================================"
ansible-galaxy collection install \
  --requirements-file requirements.yml \
  --upgrade

echo
echo "============================================================"
echo " Sprawdzenie inventory i składni"
echo "============================================================"
ansible-inventory --list --yaml >/dev/null
ansible-playbook deploy.yml --syntax-check

echo
echo "============================================================"
echo " Wdrożenie"
echo "============================================================"
if [[ "$(id -u)" -eq 0 ]]; then
  ansible-playbook deploy.yml
else
  ansible-playbook deploy.yml --ask-become-pass
fi
