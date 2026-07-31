#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f group_vars/all.yml ]]; then
  cp group_vars/all.yml.example group_vars/all.yml
  chmod 600 group_vars/all.yml
  echo "Utworzono group_vars/all.yml. Ustaw hasła CHANGE_ME i uruchom skrypt ponownie."
  exit 1
fi

if grep -q "CHANGE_ME" group_vars/all.yml; then
  echo "BŁĄD: zmień wszystkie wartości CHANGE_ME w group_vars/all.yml."
  exit 1
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
