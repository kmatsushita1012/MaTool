#!/bin/sh
set -eu

repository_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
touch "$repository_root/Backend/.env"

# Xcode Cloud cannot interact with the first-run approval prompt for SwiftPM build plugins.
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
