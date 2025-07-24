#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

###############################################################################
# CONFIG
###############################################################################
VENVDIR="venv"
OUT_DIR="reports"
OUT_FILE="$OUT_DIR/slither_report.txt"

###############################################################################
# 1. Python venv (first run only)
###############################################################################
if [[ ! -d $VENVDIR ]]; then
  echo "• creating python venv '$VENVDIR'"
  python3 -m venv "$VENVDIR"
fi
source "$VENVDIR/bin/activate"
pip install --quiet --upgrade slither-analyzer >/dev/null

###############################################################################
# 2. Make sure Foundry artefacts exist
###############################################################################
echo "🔨Running forge build..."
forge build --build-info

###############################################################################
# 3. Run Slither twice (output completely hidden)
###############################################################################
echo "🔍 Scanning Solidity contracts with Slither..."
mkdir -p "$OUT_DIR"

SUMMARY_TMP=$(mktemp)
DETAIL_TMP=$(mktemp)

set +e                                   # let Slither fail without aborting

slither . --print human-summary   \
        --disable-color           \
        >"$SUMMARY_TMP" 2>&1
STATUS_SUMMARY=$?

slither . --disable-color         \
        >"$DETAIL_TMP" 2>&1
STATUS_DETAILS=$?

set -e                                   # re-enable “fail-fast”

###############################################################################
# 4. Build final report
###############################################################################
cat  "$SUMMARY_TMP"      >  "$OUT_FILE"
printf "\n\n\n"          >> "$OUT_FILE"
cat  "$DETAIL_TMP"       >> "$OUT_FILE"

rm -f "$SUMMARY_TMP" "$DETAIL_TMP"
echo "✓ Report written to $OUT_FILE"

###############################################################################
# 5. propagate Slither’s exit status (so CI still fails on High issues)
###############################################################################
exit $(( STATUS_SUMMARY | STATUS_DETAILS ))
