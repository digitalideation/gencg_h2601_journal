#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREVIEW_DIR="$REPO_ROOT/.quartz-preview"

case "$PREVIEW_DIR" in
  "$REPO_ROOT/.quartz-preview") ;;
  *)
    echo "Refusing to use unexpected preview directory: $PREVIEW_DIR" >&2
    exit 1
    ;;
esac

for command_name in git node npm rsync; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

echo "Preparing Quartz v5 in $PREVIEW_DIR"

if [ -d "$PREVIEW_DIR" ]; then
  rm -rf "$PREVIEW_DIR"
fi

git clone --depth 1 --branch v5 https://github.com/jackyzha0/quartz.git "$PREVIEW_DIR"

(
  cd "$PREVIEW_DIR"
  npm ci
)

echo
echo "Quartz preview dependencies are ready."
echo "Run ./scripts/preview.sh to build and open the journal preview."
