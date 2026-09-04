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

test_cpus=${TEST_CPUS:-2}
nice_level=${NICE_LEVEL:-15}

cd "$GITEA_SOURCE_DIR"
nice -n "$nice_level" env \
  GOMAXPROCS="$test_cpus" \
  GOMEMLIMIT=1GiB \
  GOFLAGS=-p=1 \
  make test-integration#TestAPIBranchProtection
nice -n "$nice_level" env \
  GOMAXPROCS="$test_cpus" \
  GOMEMLIMIT=1GiB \
  GOFLAGS=-p=1 \
  make test-integration#TestProtectedBranchDeletionByDeployKey
