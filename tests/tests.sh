#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
export COMPOSE_PROJECT_NAME=${1:-autoheal-test}
export AUTOHEAL_CONTAINER_LABEL=${AUTOHEAL_CONTAINER_LABEL:-autoheal-test}
expected_restarts=2

cleanup() {
  docker compose stop autoheal >/dev/null 2>&1 || true
  docker compose down --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  docker compose logs autoheal >&2
  exit 1
}

docker compose up --build -d

restarts=0
while read -r service
do
  case "$service" in
    should-keep-restarting)
      restarts=$((restarts + 1))
      echo "OK: restart $restarts of $service"
      ;;
    *)
      fail "unexpected restart of $service"
      ;;
  esac
  if [ "$restarts" -ge "$expected_restarts" ]
  then
    echo "OK: all expected restarts happened"
    exit 0
  fi
done < <(timeout 120 docker events \
  --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME" \
  --filter event=restart \
  --format '{{index .Actor.Attributes "com.docker.compose.service"}}')

fail "only $restarts of $expected_restarts expected restarts within 120s"
