#!/bin/sh
set -eu

if [ -z "${MATOOL_API_BASE_URL:-}" ]; then
  echo "MATOOL_API_BASE_URL is required"
  exit 1
fi

if [ -z "${MATOOL_USER_GUIDE_URL:-}" ]; then
  echo "MATOOL_USER_GUIDE_URL is required"
  exit 1
fi

if [ -z "${MATOOL_CONTACT_URL:-}" ]; then
  echo "MATOOL_CONTACT_URL is required"
  exit 1
fi

mkdir -p iOSApp/Config
cat > iOSApp/Config/Debug.xcconfig <<EOF
MATOOL_API_BASE_URL = ${MATOOL_API_BASE_URL}
MATOOL_USER_GUIDE_URL = ${MATOOL_USER_GUIDE_URL}
MATOOL_CONTACT_URL = ${MATOOL_CONTACT_URL}
EOF

cat > iOSApp/Config/Release.xcconfig <<EOF
MATOOL_API_BASE_URL = ${MATOOL_API_BASE_URL}
MATOOL_USER_GUIDE_URL = ${MATOOL_USER_GUIDE_URL}
MATOOL_CONTACT_URL = ${MATOOL_CONTACT_URL}
EOF
