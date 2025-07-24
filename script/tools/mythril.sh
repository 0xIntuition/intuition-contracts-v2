#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# CLI flags (only --timeout/-t for now)
###############################################################################
TIMEOUT=60            # default value (seconds per file)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout|-t)
      TIMEOUT="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--timeout <seconds>]"
      exit 0
      ;;
    *)  echo "Unknown option: $1"; exit 1 ;;
  esac
done

#########################################
# CONFIG — tweak as needed
#########################################

# Mythril-specific config
SOLC_VERSION="0.8.27"        # pragma major.minor
TX_COUNT=4                   # max tx sequence length per symbolic execution run
MAX_DEPTH=30                 # intra-tx basic block depth

# Configured paths
SRC_DIR="src"                # where your .sol live
FLAT_DIR="flattened"         # output hierarchy mirrors SRC_DIR
REPORT_DIR="mythril_reports"
SUMMARY_FILE="reports/mythril_report.txt"

#########################################
# 1. Compile once (bytecode + build-info)
#########################################
echo "🔨 Running forge build..."
forge build --build-info

#########################################
# 2. Prep output folders
#########################################
mkdir -p "$FLAT_DIR" "$REPORT_DIR" "$(dirname "$SUMMARY_FILE")"
> "$SUMMARY_FILE"               # truncate previous summary

#########################################
# 3. Flatten + analyse every contract
#########################################
echo "🔍 Scanning Solidity contracts with Mythril..."

find "$SRC_DIR" -type f -name '*.sol' | while read -r SRC_PATH; do
  # Skip only if the file has *no* contract/library, i.e. it’s interface-only
  if grep -q -E '^\s*interface\s' "$SRC_PATH"  && \
    ! grep -q -E '^\s*(contract|library)\s'  "$SRC_PATH"; then
    REL="${SRC_PATH#${SRC_DIR}/}"
    echo "  ↪︎ Skipping pure interface file: $REL"
    continue
  fi

  # Build mirrored paths
  REL_PATH="${SRC_PATH#${SRC_DIR}/}"            # e.g. foo/Bar.sol
  FLAT_FILE="$FLAT_DIR/$REL_PATH"               # flattened/foo/Bar.sol
  REPORT_FILE="$REPORT_DIR/${REL_PATH%.sol}.txt"  # mythril_reports/foo/Bar.txt

  # Ensure sub-dirs exist
  mkdir -p "$(dirname "$FLAT_FILE")" "$(dirname "$REPORT_FILE")"

  echo "  • $REL_PATH"

  # 3-a  Flatten
  forge flatten "$SRC_PATH" > "$FLAT_FILE"

  # 3-b  Mythril analysis
  myth analyze "$FLAT_FILE" \
      --solv "$SOLC_VERSION" \
      -t "$TX_COUNT" \
      --max-depth "$MAX_DEPTH" \
      --execution-timeout "$TIMEOUT" \
      > "$REPORT_FILE" 2>&1 || true   # keep going on Mythril crash

  #######################################
  # 4. Append to summary if issues found
  #######################################
  if ! grep -q "No issues were detected" "$REPORT_FILE"; then
    {
      echo
      echo "========  $REL_PATH  ========"
      cat "$REPORT_FILE"
    } >> "$SUMMARY_FILE"
  fi
done

echo
echo "✅  Finished."
if [ -s "$SUMMARY_FILE" ]; then
  echo "⚠️ Issues found — see $SUMMARY_FILE"
else
  echo "🎉 No issues detected in any flattened contract."
  rm -f "$SUMMARY_FILE"   # remove empty summary if no issues were found
fi
