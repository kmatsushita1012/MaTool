#!/bin/sh
set -eu

if [ -z "${MATOOL_API_BASE_URL:-}" ]; then
  echo "MATOOL_API_BASE_URL is required"
  exit 1
fi

mkdir -p iOSApp/Config
printf 'MATOOL_API_BASE_URL = %s\n' "$MATOOL_API_BASE_URL" > iOSApp/Config/Debug.xcconfig
printf 'MATOOL_API_BASE_URL = %s\n' "$MATOOL_API_BASE_URL" > iOSApp/Config/Release.xcconfig
