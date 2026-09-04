#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

base_url=${BASE_URL:-http://localhost:3000}
admin_user=${ADMIN_USER:-demo}
admin_password=${ADMIN_PASSWORD:-DemoDelete123!}
release_user=${RELEASE_USER:-releasebot}
release_password=${RELEASE_PASSWORD:-ReleaseBot123!}
developer_user=${DEVELOPER_USER:-developer}
developer_password=${DEVELOPER_PASSWORD:-Developer123!}
org=branch-demo
repo=team-deletion-demo
team=release-managers

for command in docker curl jq; do
  command -v "$command" >/dev/null || { echo "Missing dependency: $command" >&2; exit 1; }
done

dc() {
  docker compose "$@"
}

api_status() {
  curl --silent --output /dev/null --write-out '%{http_code}' \
    --user "$admin_user:$admin_password" "$base_url$1"
}

api_json() {
  local method=$1
  local path=$2
  local data=${3-}
  local args=(--fail-with-body --silent --show-error --user "$admin_user:$admin_password" --request "$method")
  if [[ -n "$data" ]]; then
    args+=(--header 'Content-Type: application/json' --data "$data")
  fi
  curl "${args[@]}" "$base_url$path"
}

ensure_user() {
  local username=$1
  local password=$2
  local email=$3
  shift 3

  if [[ $(api_status "/api/v1/users/$username") == 200 ]]; then
    return
  fi

  dc exec -T gitea /workspace/gitea \
    --work-path /workspace --config /demo/config/app.ini \
    admin user create \
    --username "$username" --password "$password" --email "$email" \
    --must-change-password=false "$@"
}

ensure_branch() {
  local branch=$1
  local encoded
  encoded=$(jq -rn --arg value "$branch" '$value|@uri')
  if [[ $(api_status "/api/v1/repos/$org/$repo/branches/$encoded") == 200 ]]; then
    return
  fi
  api_json POST "/api/v1/repos/$org/$repo/branches" \
    "$(jq -nc --arg branch "$branch" '{new_branch_name:$branch,old_branch_name:"main"}')" >/dev/null
}

dc up -d

echo -n "Waiting for Gitea"
for _ in $(seq 1 60); do
  if curl --fail --silent "$base_url/api/healthz" >/dev/null 2>&1; then
    echo
    break
  fi
  echo -n .
  sleep 1
done
curl --fail --silent "$base_url/api/healthz" >/dev/null || {
  echo "Gitea did not become ready; inspect: docker compose logs gitea" >&2
  exit 1
}

ensure_user "$admin_user" "$admin_password" demo@example.invalid --admin
ensure_user "$release_user" "$release_password" releasebot@example.invalid
ensure_user "$developer_user" "$developer_password" developer@example.invalid

if [[ $(api_status "/api/v1/orgs/$org") != 200 ]]; then
  api_json POST /api/v1/orgs "$(jq -nc --arg org "$org" '{username:$org,visibility:"public"}')" >/dev/null
fi

if [[ $(api_status "/api/v1/repos/$org/$repo") != 200 ]]; then
  api_json POST "/api/v1/orgs/$org/repos" \
    "$(jq -nc --arg repo "$repo" '{name:$repo,auto_init:true,default_branch:"main",private:false}')" >/dev/null
fi

teams=$(api_json GET "/api/v1/orgs/$org/teams")
team_id=$(jq -r --arg team "$team" '.[] | select(.name == $team) | .id' <<<"$teams" | head -n1)
if [[ -z "$team_id" ]]; then
  created_team=$(api_json POST "/api/v1/orgs/$org/teams" \
    "$(jq -nc --arg team "$team" '{name:$team,description:"May delete protected release branches",permission:"write",units:["repo.code","repo.pulls"],includes_all_repositories:false}')")
  team_id=$(jq -r '.id' <<<"$created_team")
fi

api_json PUT "/api/v1/teams/$team_id/members/$release_user" >/dev/null
api_json PUT "/api/v1/teams/$team_id/repos/$org/$repo" >/dev/null
api_json PUT "/api/v1/repos/$org/$repo/collaborators/$developer_user" '{"permission":"write"}' >/dev/null

ensure_branch release/team-1
ensure_branch release/team-2
ensure_branch feature/control

protections=$(api_json GET "/api/v1/repos/$org/$repo/branch_protections")
if ! jq -e '.[] | select(.rule_name == "release/*")' <<<"$protections" >/dev/null; then
  api_json POST "/api/v1/repos/$org/$repo/branch_protections" \
    "$(jq -nc --arg team "$team" '{rule_name:"release/*",enable_push:true,enable_deletion:true,enable_deletion_allowlist:true,deletion_allowlist_teams:[$team]}')" >/dev/null
fi

cat <<EOF
Demo ready at $base_url/$org/$repo

Admin:       $admin_user / $admin_password
Team member: $release_user / $release_password
Developer:   $developer_user / $developer_password

Run ./scripts/smoke-api.sh for deterministic API checks, or follow UI_TESTS.md.
EOF
