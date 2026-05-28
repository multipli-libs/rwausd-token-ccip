#!/usr/bin/env bash
set -euo pipefail

TYPE=""
MSG=""

# First arg will already be --type=patch from package.json
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type=*)
      TYPE="${1#*=}"
      shift
      ;;
    -t)
      TYPE="$2"
      shift 2
      ;;
    -m)
      MSG="$2"
      shift 2
      ;;
    *)
      if [[ -z "${MSG}" ]]; then
        MSG="$1"
      else
        MSG="${MSG} $1"
      fi
      shift
      ;;
  esac
done

if [[ -z "${TYPE}" ]]; then
  echo "Error: --type (major|minor|patch) is required."
  exit 1
fi

if [[ "${TYPE}" != "major" && "${TYPE}" != "minor" && "${TYPE}" != "patch" ]]; then
  echo "Error: invalid type '${TYPE}'. Expected: major, minor, or patch."
  exit 1
fi

if [[ -z "${MSG}" ]]; then
  MSG="Version bump (${TYPE})"
fi

echo "Bumping ${TYPE} with message: '${MSG}'"

npm version "${TYPE}" -m "v%s: ${MSG}"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin "${CURRENT_BRANCH}"
git push origin --tags