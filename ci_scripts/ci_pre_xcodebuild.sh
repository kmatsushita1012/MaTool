#!/bin/sh
set -eu

defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES \
  || echo "Warning: unable to configure Xcode macro fingerprint validation"

if [ -z "${AMPLIFY_CONFIGURATION_JSON:-}" ]; then
  echo "AMPLIFY_CONFIGURATION_JSON is required to generate Amplify configuration"
  exit 1
fi

for variable in \
  MATOOL_API_BASE_URL \
  MATOOL_USER_GUIDE_URL \
  MATOOL_CONTACT_URL \
  MATOOL_ADMOB_APP_ID \
  MATOOL_PUBLIC_MAP_INTERSTITIAL_AD_UNIT_ID \
  MATOOL_PUBLIC_MAP_BANNER_AD_UNIT_ID
do
  eval "value=\${$variable:-}"
  if [ -z "$value" ]; then
    echo "$variable is required to generate iOSApp/Config/Release.xcconfig"
    exit 1
  fi
done

repository_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
config_directory="$repository_root/iOSApp/Config"
mkdir -p "$config_directory"

write_xcconfig() {
  configuration_path="$config_directory/$1.xcconfig"
  cat > "$configuration_path" <<EOF
MATOOL_API_BASE_URL = ${MATOOL_API_BASE_URL}
MATOOL_USER_GUIDE_URL = ${MATOOL_USER_GUIDE_URL}
MATOOL_CONTACT_URL = ${MATOOL_CONTACT_URL}
MATOOL_ADMOB_APP_ID = ${MATOOL_ADMOB_APP_ID}
MATOOL_PUBLIC_MAP_INTERSTITIAL_AD_UNIT_ID = ${MATOOL_PUBLIC_MAP_INTERSTITIAL_AD_UNIT_ID}
MATOOL_PUBLIC_MAP_BANNER_AD_UNIT_ID = ${MATOOL_PUBLIC_MAP_BANNER_AD_UNIT_ID}
EOF
}

write_xcconfig Debug
write_xcconfig Release

printf '%s\n' "$AMPLIFY_CONFIGURATION_JSON" > "$repository_root/iOSApp/amplifyconfiguration.json"
printf '%s\n' "$AMPLIFY_CONFIGURATION_JSON" > "$repository_root/iOSApp/amplifyconfiguration.example.json"

echo "Generated iOSApp/Config/Debug.xcconfig"
echo "Generated iOSApp/Config/Release.xcconfig"
echo "Generated iOSApp/amplifyconfiguration.json"
echo "Generated iOSApp/amplifyconfiguration.example.json"
