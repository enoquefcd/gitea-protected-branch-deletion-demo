#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
base_url=${BASE_URL:-http://localhost:3000}
admin_user=${ADMIN_USER:-demo}
admin_password=${ADMIN_PASSWORD:-DemoDelete123!}
release_user=${RELEASE_USER:-releasebot}
release_password=${RELEASE_PASSWORD:-ReleaseBot123!}
developer_user=${DEVELOPER_USER:-developer}
developer_password=${DEVELOPER_PASSWORD:-Developer123!}
org=branch-demo
repo=team-deletion-demo

expect_delete() {
  local actor=$1
  local password=$2
  local branch=$3
  local expected=$4
  local encoded
  encoded=$(jq -rn --arg value "$branch" '$value|@uri')
  status=$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --user "$actor:$password" --request DELETE \
    "$base_url/api/v1/repos/$org/$repo/branches/$encoded")
  if [[ "$status" != "$expected" ]]; then
    echo "FAIL: $actor deleting $branch returned $status; expected $expected" >&2
    exit 1
  fi
  echo "PASS: $actor deleting $branch -> $status"
}

"$repo_root/scripts/bootstrap.sh" >/dev/null

expect_delete "$developer_user" "$developer_password" release/team-1 403
expect_delete "$release_user" "$release_password" release/team-1 204
expect_delete "$developer_user" "$developer_password" feature/control 204

"$repo_root/scripts/bootstrap.sh" >/dev/null

team_id=$(curl --fail --silent --user "$admin_user:$admin_password" \
  "$base_url/api/v1/orgs/$org/teams" | jq -r '.[] | select(.name == "release-managers") | .id')
curl --fail --silent --user "$admin_user:$admin_password" --request DELETE \
  "$base_url/api/v1/teams/$team_id/members/$release_user" >/dev/null
expect_delete "$release_user" "$release_password" release/team-2 403
curl --fail --silent --user "$admin_user:$admin_password" --request PUT \
  "$base_url/api/v1/teams/$team_id/members/$release_user" >/dev/null
expect_delete "$release_user" "$release_password" release/team-2 204

"$repo_root/scripts/bootstrap.sh" >/dev/null
echo "All protected-branch deletion smoke checks passed."
