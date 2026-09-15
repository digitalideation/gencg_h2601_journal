#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREVIEW_DIR="$REPO_ROOT/.quartz-preview"
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

if [ ! -d "$PREVIEW_DIR/node_modules" ]; then
  bash "$REPO_ROOT/scripts/setup-preview.sh"
fi

echo "Synchronizing journal content..."

rm -rf "$PREVIEW_DIR/content"
mkdir -p "$PREVIEW_DIR/content"

rsync -a --delete \
  --exclude='.git/' \
  --exclude='.github/' \
  --exclude='.devcontainer/' \
  --exclude='.obsidian/' \
  --exclude='.trash/' \
  --exclude='.quartz-preview/' \
  --exclude='scripts/' \
  --exclude='quartz.config.yaml' \
  --exclude='quartz-plugins/' \
  --exclude='quartz-custom/' \
  --exclude='weeks/*/sketches/' \
  "$REPO_ROOT/" "$PREVIEW_DIR/content/"

cp "$REPO_ROOT/quartz.config.yaml" "$PREVIEW_DIR/quartz.config.yaml"
cp "$REPO_ROOT/quartz-custom/custom.scss" "$PREVIEW_DIR/quartz/styles/custom.scss"

rm -rf "$PREVIEW_DIR/quartz-plugins"
cp -R "$REPO_ROOT/quartz-plugins" "$PREVIEW_DIR/quartz-plugins"

if [ -n "${CODESPACE_NAME:-}" ]; then
  BASE_URL="${CODESPACE_NAME}-8080.app.github.dev"
else
  BASE_URL="localhost:8080"
fi

sed -i "s|__BASE_URL__|$BASE_URL|" "$PREVIEW_DIR/quartz.config.yaml"

echo "Installing configured Quartz plugins..."

(
  cd "$PREVIEW_DIR"
  npx quartz plugin install --clean
  npx quartz plugin install --from-config
)

echo "Starting Quartz preview..."

(
  cd "$PREVIEW_DIR"
  npx quartz build --serve --port 8080
) &

SERVER_PID=$!

READY=false
for _ in $(seq 1 120); do
  if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    wait "$SERVER_PID"
    exit $?
  fi

  if [ -f "$PREVIEW_DIR/public/index.html" ]; then
    READY=true
    break
  fi

  sleep 1
done

if [ "$READY" != true ]; then
  echo "Quartz did not finish its initial build within two minutes." >&2
  exit 1
fi

if [ -d "$REPO_ROOT/weeks" ]; then
  while IFS= read -r -d '' sketches_dir; do
    relative_path="${sketches_dir#"$REPO_ROOT/"}"
    mkdir -p "$PREVIEW_DIR/public/$relative_path"
    rsync -a "$sketches_dir/" "$PREVIEW_DIR/public/$relative_path/"
  done < <(find "$REPO_ROOT/weeks" -type d -name sketches -print0)
fi

echo
echo "Quartz preview is ready."
echo "Open the forwarded 'Quartz Preview' port in the Codespaces PORTS panel."
echo "Press Ctrl+C to stop. Rerun this script after editing source files."
echo

wait "$SERVER_PID"
