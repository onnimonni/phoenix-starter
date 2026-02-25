#!/usr/bin/env bash
set -euo pipefail

json=$(cat)
wt_path=$(echo "$json" | jq -r '.worktree_path')

# Extract worktree name from path
name=$(basename "$wt_path")
db_suffix=$(echo "$name" | tr '-' '_')

# Drop cloned databases
for base in app_dev app_test; do
  clone_db="${base}_${db_suffix}"
  # Terminate connections first
  psql -h 127.0.0.1 -d postgres -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$clone_db' AND pid <> pg_backend_pid();" 2>/dev/null || true
  psql -h 127.0.0.1 -d postgres -c \
    "DROP DATABASE IF EXISTS \"$clone_db\";" 2>/dev/null || true
  echo "Dropped $clone_db" >&2
done

# Remove git worktree
git worktree remove --force "$wt_path" 2>/dev/null || true
git branch -D "worktree/$name" 2>/dev/null || true
