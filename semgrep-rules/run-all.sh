#!/usr/bin/env bash
# Beginner-friendly Semgrep runner.
# Usage:
#   ./semgrep-rules/run-all.sh [--custom-only|--with-registry] [source-directory]
set -uo pipefail

MODE="custom"
TARGET="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --custom-only) MODE="custom"; shift ;;
    --with-registry) MODE="registry"; shift ;;
    -h|--help)
      echo "Usage: $0 [--custom-only|--with-registry] [source-directory]"
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      TARGET="$1"; shift
      ;;
  esac
done

if ! command -v semgrep >/dev/null 2>&1; then
  echo "Semgrep is not installed. Install it first: python3 -m pipx install semgrep" >&2
  exit 127
fi
if [[ ! -d "$TARGET" ]]; then
  echo "Target directory does not exist: $TARGET" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUT="$REPO_ROOT/semgrep-results"
mkdir -p "$OUT"

# Run each local rules file separately, so findings are easy to identify.
status=0
for rule_file in "$SCRIPT_DIR"/0*.yaml; do
  name="$(basename "$rule_file" .yaml)"
  echo
  echo "=== Custom rules: $name ==="
  semgrep scan --metrics=off --config "$rule_file" \
    --sarif -o "$OUT/$name.sarif" "$TARGET" || status=$?
done

if [[ "$MODE" == "registry" ]]; then
  echo
  echo "=== Semgrep Registry rules ==="
  semgrep scan --metrics=off \
    --config p/default \
    --config p/security-audit \
    --config p/owasp-top-ten \
    --config p/cwe-top-25 \
    --config p/secrets \
    --sarif -o "$OUT/registry.sarif" "$TARGET" || status=$?
fi

echo
echo "SARIF reports (if generated): $OUT"
echo "Review every finding manually; a match is not proof of a vulnerability."
exit "$status"
