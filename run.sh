#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo
echo "============================================================"
echo " Instalacja kolekcji Ansible"
echo "============================================================"
ansible-galaxy collection install \
  --requirements-file requirements.yml \
  --upgrade

echo
echo "============================================================"
echo " Sprawdzenie składni"
echo "============================================================"
ansible-playbook deploy.yml --syntax-check

echo
echo "============================================================"
echo " Wdrożenie"
echo "============================================================"
ansible-playbook deploy.yml --ask-become-pass
