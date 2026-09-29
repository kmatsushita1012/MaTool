#!/bin/sh
set -eu

repository_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
touch "$repository_root/Backend/.env"
