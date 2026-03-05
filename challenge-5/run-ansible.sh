#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

LOG_FILE="ansible.log"

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "ansible-playbook not found."
  read -r -p "Install Ansible now? (yes/no) " ans
  ans="$(printf "%s" "$ans" | tr '[:upper:]' '[:lower:]')"
  if [[ "$ans" != "y" && "$ans" != "yes" && "$ans" != "evet" ]]; then
    echo "Cannot continue without Ansible."
    exit 1
  fi

  if command -v brew >/dev/null 2>&1; then
    brew install ansible
  else
    echo "Homebrew not found. Install Ansible manually (or install brew)."
    exit 1
  fi
fi

echo "Running playbook (local)..."
echo "Log -> $LOG_FILE"
echo

# -v gives more details; debug tasks provide clear evidence in logs.
ansible-playbook -v -i inventory.ini main.yml 2>&1 | tee "$LOG_FILE"

echo
echo "Done."
echo "Saved: $(pwd)/$LOG_FILE"