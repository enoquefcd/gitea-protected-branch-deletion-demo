#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -f "$repo_root/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$repo_root/.env"
  set +a
fi

: "${GITEA_SOURCE_DIR:?Copy .env.example to .env and set GITEA_SOURCE_DIR}"

build_cpus=${BUILD_CPUS:-2}
nice_level=${NICE_LEVEL:-15}

echo "Building Gitea with ${build_cpus} workers and nice level ${nice_level}..."
cd "$GITEA_SOURCE_DIR"
nice -n "$nice_level" env \
  GOMAXPROCS="$build_cpus" \
  GOFLAGS="-p=$build_cpus" \
  NODE_OPTIONS="--max-old-space-size=1024" \
  UV_THREADPOOL_SIZE="$build_cpus" \
  make frontend
nice -n "$nice_level" env \
  GOMAXPROCS="$build_cpus" \
  GOFLAGS="-p=$build_cpus" \
  make backend

echo "Built $GITEA_SOURCE_DIR/gitea"
