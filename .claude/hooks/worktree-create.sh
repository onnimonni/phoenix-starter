#!/usr/bin/env bash
set -euo pipefail

json=$(cat)
name=$(echo "$json" | jq -r '.name')
cwd=$(echo "$json" | jq -r '.cwd')

# Create git worktree
wt_dir="$cwd/.claude/worktrees/$name"
git worktree add -b "worktree/$name" "$wt_dir" HEAD >&2

# Sanitize name for SQL identifier (hyphens -> underscores)
db_suffix=$(echo "$name" | tr '-' '_')

# Clone dev and test databases using PostgreSQL TEMPLATE
for base in app_dev app_test; do
  clone_db="${base}_${db_suffix}"
  # Terminate existing connections to source DB so TEMPLATE works
  psql -h 127.0.0.1 -d postgres -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$base' AND pid <> pg_backend_pid();" >&2 2>/dev/null || true
  psql -h 127.0.0.1 -d postgres -c \
    "CREATE DATABASE \"$clone_db\" TEMPLATE \"$base\";" >&2
  echo "Cloned $base -> $clone_db" >&2
done

# Write worktree-local env override so Ecto uses the cloned DBs
cat > "$wt_dir/.env.worktree" <<EOF
export DATABASE_DEV=app_dev_${db_suffix}
export DATABASE_TEST=app_test_${db_suffix}
EOF

# Print the worktree path (this is what Claude Code reads)
echo "$wt_dir"
