#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEST_IDS=(
  "dojo_starter::tests::unit::harvesting_manager_test::tests::harvesting_manager_start_checks_preconditions_and_spends_energy"
  "dojo_starter::tests::unit::harvesting_manager_test::tests::harvesting_manager_complete_and_cancel_settle_lifecycle"
  "dojo_starter::tests::unit::economic_manager_test::tests::economic_manager_process_decay_sets_claimable_checkpoint"
)

TEST_BUDGETS=(
  450000
  900000
  250000
)

extract_l2_gas() {
  local output="$1"
  printf '%s\n' "$output" | sed -n 's/.*l2_gas: ~\([0-9][0-9]*\).*/\1/p' | tail -n 1
}

check_test_budget() {
  local test_id="$1"
  local budget="$2"
  local output
  local gas

  output="$(snforge test "$test_id" 2>&1)"
  gas="$(extract_l2_gas "$output")"

  if [[ -z "$gas" ]]; then
    printf '%s\n' "$output"
    echo "[FAIL] could not parse l2_gas for $test_id"
    return 1
  fi

  if (( gas > budget )); then
    printf '%s\n' "$output"
    echo "[FAIL] $test_id uses $gas l2_gas (budget $budget)"
    return 1
  fi

  echo "[OK] $test_id uses $gas l2_gas (budget $budget)"
}

echo "Running P2.2 perf budget checks..."

for i in "${!TEST_IDS[@]}"; do
  check_test_budget "${TEST_IDS[$i]}" "${TEST_BUDGETS[$i]}"
done

echo "All perf budgets passed."
