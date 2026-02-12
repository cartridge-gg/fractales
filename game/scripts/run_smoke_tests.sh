#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEST_IDS=(
  "dojo_starter::tests::integration::world_gen_manager_integration_test::tests::world_gen_manager_integration_initializes_active_config_once"
  "dojo_starter::tests::integration::world_manager_integration_test::tests::world_manager_integration_discover_paths_are_stateful_and_idempotent"
  "dojo_starter::tests::integration::harvesting_manager_integration_test::tests::harvesting_manager_integration_init_start_complete_cancel"
  "dojo_starter::tests::integration::smoke_generation_pipeline_integration_test::tests::smoke_generation_pipeline_config_driven_discovery_and_harvesting"
)

echo "Running smoke integration tests..."
for test_id in "${TEST_IDS[@]}"; do
  echo "- $test_id"
  snforge test "$test_id"
done

echo "Smoke integration tests passed."
