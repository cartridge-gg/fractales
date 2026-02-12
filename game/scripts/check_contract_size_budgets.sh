#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SYSTEM_ARTIFACTS=(
  "target/dev/dojo_starter_world_manager.contract_class.json"
  "target/dev/dojo_starter_adventurer_manager.contract_class.json"
  "target/dev/dojo_starter_harvesting_manager.contract_class.json"
  "target/dev/dojo_starter_economic_manager.contract_class.json"
  "target/dev/dojo_starter_ownership_manager.contract_class.json"
)

ARTIFACT_BUDGETS_BYTES=(
  4700000
  4200000
  6500000
  8000000
  2900000
)

TOTAL_SYSTEM_BUDGET_BYTES=26000000

echo "Building latest artifacts for size checks..."
sozo build >/dev/null

echo "Running P2.2 contract size budget checks..."

total_size=0
for i in "${!SYSTEM_ARTIFACTS[@]}"; do
  artifact="${SYSTEM_ARTIFACTS[$i]}"
  budget="${ARTIFACT_BUDGETS_BYTES[$i]}"

  if [[ ! -f "$artifact" ]]; then
    echo "[FAIL] missing artifact: $artifact"
    exit 1
  fi

  size_bytes="$(wc -c < "$artifact" | tr -d ' ')"
  total_size=$((total_size + size_bytes))

  if (( size_bytes > budget )); then
    echo "[FAIL] $artifact is $size_bytes bytes (budget $budget)"
    exit 1
  fi

  echo "[OK] $artifact is $size_bytes bytes (budget $budget)"
done

if (( total_size > TOTAL_SYSTEM_BUDGET_BYTES )); then
  echo "[FAIL] total system artifact size is $total_size bytes (budget $TOTAL_SYSTEM_BUDGET_BYTES)"
  exit 1
fi

echo "[OK] total system artifact size is $total_size bytes (budget $TOTAL_SYSTEM_BUDGET_BYTES)"
echo "All size budgets passed."
