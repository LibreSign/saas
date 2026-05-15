#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEXTCLOUD_DIRECTORY="$ROOT_DIR/nextcloud-development"
WORDPRESS_DIRECTORY="$ROOT_DIR/wordpress-docker"
NEXTCLOUD_HTTP_PORT="${NEXTCLOUD_HTTP_PORT:-8080}"
NEXTCLOUD_BASE_URL="http://localhost:${NEXTCLOUD_HTTP_PORT}"

nextcloud_compose() {
  HTTP_PORT="$NEXTCLOUD_HTTP_PORT" docker compose -f "$NEXTCLOUD_DIRECTORY/docker-compose.yml" "$@"
}

wordpress_compose() {
  docker compose -f "$WORDPRESS_DIRECTORY/docker-compose.yml" -f "$WORDPRESS_DIRECTORY/docker-compose.override.yml" "$@"
}

nextcloud_occ() {
  nextcloud_compose exec -u www-data nextcloud php occ "$@"
}

wordpress_cli() {
  wordpress_compose exec wordpress wp "$@" --allow-root
}

ensure_repo() {
  local dir="$1"
  local url="$2"
  local branch="$3"

  if [[ ! -d "$dir/.git" ]]; then
    git clone "$url" "$dir"
  fi

  git -C "$dir" fetch origin "$branch"
  git -C "$dir" checkout "$branch"
  git -C "$dir" pull --ff-only origin "$branch"
}

connect_networks() {
  local nextcloud_container_id wordpress_container_id wordpress_network

  nextcloud_container_id="$(nextcloud_compose ps -q nextcloud)"
  wordpress_container_id="$(wordpress_compose ps -q mariadb)"
  wordpress_network="$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{println $k}}{{end}}' "$wordpress_container_id" | head -n1)"

  docker network connect "$wordpress_network" "$nextcloud_container_id" 2>/dev/null || true
}

setup_apps() {
  local nextcloud_apps_directory="$NEXTCLOUD_DIRECTORY/volumes/nextcloud/apps-extra"

  ensure_repo "$nextcloud_apps_directory/wordpress_login_backend" \
    "https://github.com/LibreSign/wordpress_login_backend.git" \
    "main"

  ensure_repo "$nextcloud_apps_directory/admin_group_manager" \
    "https://github.com/LibreSign/admin_group_manager.git" \
    "main"

  nextcloud_occ app:enable wordpress_login_backend >/dev/null || true
  nextcloud_occ app:enable admin_group_manager --force >/dev/null || true
  nextcloud_occ config:system:set wordpress_dsn --value "mysql:host=mariadb;port=3306;dbname=wordpress;user=root;password=root" >/dev/null
}

provision_nextcloud_user() {
  curl -sS -u admin:admin \
    -X POST "$NEXTCLOUD_BASE_URL/ocs/v2.php/apps/admin_group_manager/api/v1/admin-group" \
    -H "OCS-APIREQUEST: true" \
    -d "groupid=admlibrecode" \
    -d "email=adm@librecode.coop" \
    -d "displayname=Adm Librecode" >/dev/null || true
}

cmd_up() {
  wordpress_compose up -d mariadb wordpress nginx
  nextcloud_compose up -d mysql redis nextcloud nginx

  connect_networks
  setup_apps
  provision_nextcloud_user

  echo "Environment up."
}


cmd_down() {
  nextcloud_compose down
  wordpress_compose down
  echo "Environment down."
}

case "${1:-}" in
  up) cmd_up ;;
  down) cmd_down ;;
  *)
    echo "Usage: ./orchestrator.sh {up|down}"
    exit 1
    ;;
esac
