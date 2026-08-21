#!/bin/sh
set -eu
: "${ENV_NAME:?ENV_NAME is required}"
: "${BG_COLOR:?BG_COLOR is required}"
: "${APP_VERSION:?APP_VERSION is required}"
envsubst '${ENV_NAME} ${BG_COLOR} ${APP_VERSION}' \
  < /usr/share/nginx/html/index.html.tmpl \
  > /usr/share/nginx/html/index.html
exec nginx -g 'daemon off;'
