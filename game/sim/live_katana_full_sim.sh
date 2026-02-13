#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

RPC_URL="http://127.0.0.1:5050"
MODEL_EVT_SELECTOR="0x1a2f334228cee715f1f0f54053bb6b5eac54fa336e0bc1aacf7516decb0471d"
USER_EVT_SELECTOR="0x1c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd"
HEX_SELECTOR="0x1b4f1be091a6febf3dfe50959108d0fdd25faea6a8294023dcfa10c0f92de3c"
HEXAREA_SELECTOR="0x12e4c7efe130ac2d1c74898285888cd1031903ab0de52a66ff6313edd4ec76f"
PLANT_SELECTOR="0x14c95d40f9f6c9f8ad1ea5d1ef27adb35769dfba5572a3565e5a54bc00e7d73"
BACKPACK_SELECTOR="0x405e454df4629120f26408ec4f02a0120cac03528e64d4fd33b00a8f6a2280d"
CLAIM_SELECTOR="0xca15829ad329e3d7a2e4dae3ef7eba57fdf9f4ed187c4b5e830acd3d76e860"

RESULTS=/tmp/live_katana_full_sim_results.tsv
: > "$RESULTS"
printf "action\tstatus\tdetail\ttx_hash\n" >> "$RESULTS"

LAST_OUT=""
LAST_RECEIPT=""
LAST_TX=""

canon_hex() {
  local v="${1:-0x0}"
  v="${v,,}"
  v="${v#0x}"
  v="$(printf '%s' "$v" | sed 's/^0*//')"
  if [[ -z "$v" ]]; then
    v="0"
  fi
  printf '0x%s\n' "$v"
}

add_result() {
  printf "%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "${4:-}" >> "$RESULTS"
}

extract_receipt() {
  printf '%s\n' "$LAST_OUT" | awk '/^Receipt: /{flag=1; sub(/^Receipt: /,""); print; next} flag{print}'
}

run_tx() {
  local account="$1"
  local label="$2"
  shift 2
  if ! LAST_OUT=$(sozo execute "$@" --katana-account "$account" --wait --receipt 2>&1); then
    add_result "$label" "FAIL" "tx rejected" ""
    printf '%s\n' "$LAST_OUT" >&2
    return 1
  fi
  LAST_TX=$(printf '%s\n' "$LAST_OUT" | sed -n 's/^Transaction hash: //p' | tail -n1)
  LAST_RECEIPT="$(extract_receipt)"
}

sozo_call_one() {
  local out
  out=$(sozo call "$@" 2>&1 | tail -n1)
  out=$(printf '%s' "$out" | sed 's/^\[ *//; s/ *\]$//; s/,.*$//; s/0x0x/0x/')
  printf '%s\n' "$(canon_hex "$out")"
}

model_get() {
  sozo model get "$@" 2>/dev/null
}

model_field() {
  local blob="$1"
  local field="$2"
  printf '%s\n' "$blob" | sed -nE "s/^[[:space:]]*$field[[:space:]]*:[[:space:]]*([^,]+),?$/\1/p" | head -n1 | tr -d ' '
}

first_hex_in_text() {
  local text="$1"
  printf '%s\n' "$text" | sed 's/0x0x/0x/g' | grep -Eo '0x[0-9a-fA-F]+' | head -n1 || true
}

gen_blocks() {
  local n="$1"
  local i
  for ((i=0; i<n; i++)); do
    curl -s -X POST "$RPC_URL" -H 'content-type: application/json' \
      --data '{"jsonrpc":"2.0","method":"dev_generateBlock","params":[],"id":1}' >/dev/null
  done
}

event_model_data() {
  local selector="$1"
  printf '%s\n' "$LAST_RECEIPT" | jq -r --arg model "$selector" --arg me "$MODEL_EVT_SELECTOR" \
    '.events[] | select(.keys[0]==$me and .keys[1]==$model) | .data | @json' | tail -n1
}

# Accounts and directions
ACCOUNTS=(katana0 katana1 katana2 katana4 katana5)
DIRS=(east west ne se sw)
HEXES=(
  0x400005fffff00000
  0x3ffffe0000300000
  0x40000600000fffff
  0x400001fffff00001
  0x3ffffe0000100001
)
EAST2=0x400009ffffd00000

ADV_IDS=("" "" "" "" "")
AREA0_IDS=("" "" "" "" "")
AREA1_IDS=("" "" "" "" "")
PLANT_AREA_IDS=("" "" "" "" "")
PLANT_AREA_INDEXES=("" "" "" "" "")
MINE_AREA_IDS=("" "" "" "" "")
MINE_AREA_INDEXES=("" "" "" "" "")
AREA_COUNTS=(0 0 0 0 0)
BIOMES=("" "" "" "" "")

# 1) Create 5 adventurers
for i in 0 1 2 3 4; do
  run_tx "${ACCOUNTS[$i]}" "create_${DIRS[$i]}" dojo_starter-adventurer_manager create_adventurer "sstr:A$i"
  adv_id=$(printf '%s\n' "$LAST_RECEIPT" | jq -r --arg ue "$USER_EVT_SELECTOR" '.events[] | select(.keys[0]==$ue) | .data[1]' | tail -n1)
  if [[ -z "$adv_id" || "$adv_id" == "null" ]]; then
    add_result "create_${DIRS[$i]}" "FAIL" "missing adventurer id" "$LAST_TX"
    exit 1
  fi
  ADV_IDS[$i]="$adv_id"
  add_result "create_${DIRS[$i]}" "PASS" "adventurer_id=$adv_id" "$LAST_TX"
done

# 2) Discover/move/discover areas for each adventurer
for i in 0 1 2 3 4; do
  adv="${ADV_IDS[$i]}"
  hex="${HEXES[$i]}"
  acct="${ACCOUNTS[$i]}"

  run_tx "$acct" "discover_hex_${DIRS[$i]}" dojo_starter-world_manager discover_hex "$adv" "$hex"
  hex_data=$(event_model_data "$HEX_SELECTOR")
  area_count=$(printf '%s\n' "$hex_data" | jq -r '.[7] // empty')
  if [[ -z "$area_count" ]]; then
    add_result "discover_hex_${DIRS[$i]}" "FAIL" "missing hex write" "$LAST_TX"
    exit 1
  fi
  AREA_COUNTS[$i]=$((area_count))
  hex_row=$(model_get dojo_starter-Hex "$hex")
  BIOMES[$i]="$(model_field "$hex_row" biome)"
  add_result "discover_hex_${DIRS[$i]}" "PASS" "area_count=${AREA_COUNTS[$i]} biome=${BIOMES[$i]}" "$LAST_TX"

  run_tx "$acct" "move_${DIRS[$i]}" dojo_starter-world_manager move_adventurer "$adv" "$hex"
  add_result "move_${DIRS[$i]}" "PASS" "moved_to=$hex" "$LAST_TX"

  run_tx "$acct" "discover_area0_${DIRS[$i]}" dojo_starter-world_manager discover_area "$adv" "$hex" 0
  area_data=$(event_model_data "$HEXAREA_SELECTOR")
  area0=$(printf '%s\n' "$area_data" | jq -r '.[1] // empty')
  area0_row=$(model_get dojo_starter-HexArea "$area0")
  area0_type=$(model_field "$area0_row" area_type)
  AREA0_IDS[$i]="$area0"
  add_result "discover_area0_${DIRS[$i]}" "PASS" "area_id=$area0 type=$area0_type" "$LAST_TX"

  max_index=$((AREA_COUNTS[$i]-1))
  if (( max_index >= 1 )); then
    for idx in $(seq 1 "$max_index"); do
      run_tx "$acct" "discover_area${idx}_${DIRS[$i]}" dojo_starter-world_manager discover_area "$adv" "$hex" "$idx"
      area_data=$(event_model_data "$HEXAREA_SELECTOR")
      area_id=$(printf '%s\n' "$area_data" | jq -r '.[1] // empty')
      area_type=$(printf '%s\n' "$area_data" | jq -r '.[5] // empty')
      area_row=$(model_get dojo_starter-HexArea "$area_id")
      area_type_label=$(model_field "$area_row" area_type)
      if [[ -z "${AREA1_IDS[$i]}" ]]; then
        AREA1_IDS[$i]="$area_id"
      fi
      if [[ "$area_type_label" == "AreaType::PlantField" || "$area_type" == "0x2" || "$area_type" == "2" ]]; then
        if [[ -z "${PLANT_AREA_IDS[$i]}" ]]; then
          PLANT_AREA_IDS[$i]="$area_id"
          PLANT_AREA_INDEXES[$i]="$idx"
        fi
      fi
      if [[ "$area_type_label" == "AreaType::MineField" ]]; then
        if [[ -z "${MINE_AREA_IDS[$i]}" ]]; then
          MINE_AREA_IDS[$i]="$area_id"
          MINE_AREA_INDEXES[$i]="$idx"
        fi
      fi
      add_result "discover_area${idx}_${DIRS[$i]}" "PASS" "area_id=$area_id type=$area_type_label raw=$area_type" "$LAST_TX"
    done
  fi
done

# Harvest owner: first adventurer with a plant field discovered
HARVEST_OWNER_IDX=""
for i in 0 1 2 3 4; do
  if [[ -n "${PLANT_AREA_IDS[$i]}" ]]; then
    HARVEST_OWNER_IDX="$i"
    break
  fi
done
if [[ -z "$HARVEST_OWNER_IDX" ]]; then
  add_result "plant_area_selection" "FAIL" "no plant fields discovered across 5 hexes" ""
  cat "$RESULTS"
  exit 1
fi

HARVEST_OWNER_ADV="${ADV_IDS[$HARVEST_OWNER_IDX]}"
HARVEST_OWNER_ACCT="${ACCOUNTS[$HARVEST_OWNER_IDX]}"
HARVEST_OWNER_HEX="${HEXES[$HARVEST_OWNER_IDX]}"
HARVEST_OWNER_AREA0="${AREA0_IDS[$HARVEST_OWNER_IDX]}"
HARVEST_OWNER_AREA_PLANT="${PLANT_AREA_IDS[$HARVEST_OWNER_IDX]}"
HARVEST_OWNER_AREA_TRANSFER="${AREA1_IDS[$HARVEST_OWNER_IDX]:-${AREA0_IDS[$HARVEST_OWNER_IDX]}}"

# Mine setup: first adventurer with a discovered mine field.
MINE_AVAILABLE=0
MINE_CONTROLLER_IDX=""
for i in 0 1 2 3 4; do
  if [[ -n "${MINE_AREA_IDS[$i]}" ]]; then
    MINE_CONTROLLER_IDX="$i"
    break
  fi
done
if [[ -n "$MINE_CONTROLLER_IDX" ]]; then
  MINE_AVAILABLE=1
  MINE_CONTROLLER_ADV="${ADV_IDS[$MINE_CONTROLLER_IDX]}"
  MINE_CONTROLLER_ACCT="${ACCOUNTS[$MINE_CONTROLLER_IDX]}"
  MINE_HEX="${HEXES[$MINE_CONTROLLER_IDX]}"
  MINE_AREA="${MINE_AREA_IDS[$MINE_CONTROLLER_IDX]}"

  MINE_GRANTEE_IDX=""
  for i in 0 1 2 3 4; do
    if [[ "$i" != "$MINE_CONTROLLER_IDX" ]]; then
      MINE_GRANTEE_IDX="$i"
      break
    fi
  done
  MINE_GRANTEE_ADV="${ADV_IDS[$MINE_GRANTEE_IDX]}"
  MINE_GRANTEE_ACCT="${ACCOUNTS[$MINE_GRANTEE_IDX]}"

  add_result "mining_area_selection" "PASS" "controller=${MINE_CONTROLLER_ADV} area=${MINE_AREA} grantee=${MINE_GRANTEE_ADV}" ""
else
  add_result "mining_area_selection" "SKIP" "no MineField discovered from explored hexes" ""
fi

# Claim owner: choose a biome where min claim <= 100 is achievable, preferring non-harvest owner
CLAIM_OWNER_IDX=""
CLAIM_UPKEEP=0
CLAIM_PERIODS=0
CLAIM_TARGET_RESERVE=0
for pass in prefer_other any; do
  for i in 0 1 2 3 4; do
    if [[ "$pass" == "prefer_other" && "$i" == "$HARVEST_OWNER_IDX" ]]; then
      continue
    fi
    biome="${BIOMES[$i]}"
    case "$biome" in
      Biome::Plains)
        CLAIM_OWNER_IDX="$i"; CLAIM_UPKEEP=25; CLAIM_PERIODS=4; CLAIM_TARGET_RESERVE=20 ;;
      Biome::Forest|Biome::Unknown)
        CLAIM_OWNER_IDX="$i"; CLAIM_UPKEEP=35; CLAIM_PERIODS=3; CLAIM_TARGET_RESERVE=25 ;;
      Biome::Mountain)
        CLAIM_OWNER_IDX="$i"; CLAIM_UPKEEP=45; CLAIM_PERIODS=2; CLAIM_TARGET_RESERVE=10 ;;
      *)
        ;;
    esac
    if [[ -n "$CLAIM_OWNER_IDX" ]]; then
      break
    fi
  done
  if [[ -n "$CLAIM_OWNER_IDX" ]]; then
    break
  fi
done

if [[ -z "$CLAIM_OWNER_IDX" ]]; then
  add_result "claim_owner_selection" "FAIL" "no claim-capable biome among discovered controller hexes" ""
  cat "$RESULTS"
  exit 1
fi

CLAIM_OWNER_ADV="${ADV_IDS[$CLAIM_OWNER_IDX]}"
CLAIM_OWNER_ACCT="${ACCOUNTS[$CLAIM_OWNER_IDX]}"
CLAIM_OWNER_HEX="${HEXES[$CLAIM_OWNER_IDX]}"

# Claimant: first index different from both claim owner and harvest owner.
# This guarantees unauthorized move attempts are made by a non-owner account.
CLAIMANT_IDX=""
for i in 0 1 2 3 4; do
  if [[ "$i" != "$CLAIM_OWNER_IDX" && "$i" != "$HARVEST_OWNER_IDX" ]]; then
    CLAIMANT_IDX="$i"
    break
  fi
done
# Fallback: if no third distinct actor exists for any reason, keep non-claim-owner.
if [[ -z "$CLAIMANT_IDX" ]]; then
  for i in 0 1 2 3 4; do
    if [[ "$i" != "$CLAIM_OWNER_IDX" ]]; then
      CLAIMANT_IDX="$i"
      break
    fi
  done
fi
CLAIMANT_ADV="${ADV_IDS[$CLAIMANT_IDX]}"
CLAIMANT_ACCT="${ACCOUNTS[$CLAIMANT_IDX]}"

# Transfer target: first index distinct from harvest owner
TRANSFER_TO_IDX=""
for i in 0 1 2 3 4; do
  if [[ "$i" != "$HARVEST_OWNER_IDX" ]]; then
    TRANSFER_TO_IDX="$i"
    break
  fi
done
TRANSFER_TO_ADV="${ADV_IDS[$TRANSFER_TO_IDX]}"
TRANSFER_TO_ACCT="${ACCOUNTS[$TRANSFER_TO_IDX]}"

# Dead target: index distinct from transfer target and harvest owner
DEAD_IDX=""
for i in 0 1 2 3 4; do
  if [[ "$i" != "$TRANSFER_TO_IDX" && "$i" != "$HARVEST_OWNER_IDX" ]]; then
    DEAD_IDX="$i"
    break
  fi
done
DEAD_ADV="${ADV_IDS[$DEAD_IDX]}"
DEAD_ACCT="${ACCOUNTS[$DEAD_IDX]}"

add_result "role_selection" "PASS" "harvest_owner=${HARVEST_OWNER_ADV} claim_owner=${CLAIM_OWNER_ADV} claimant=${CLAIMANT_ADV} transfer_to=${TRANSFER_TO_ADV}" ""

# 3) Guard: discover_area must be on target hex
area_before=$(model_get dojo_starter-AreaOwnership "$HARVEST_OWNER_AREA0")
owner_before=$(canon_hex "$(model_field "$area_before" owner_adventurer_id)")
run_tx "$CLAIMANT_ACCT" "discover_area_wrong_hex_guard" dojo_starter-world_manager discover_area "$CLAIMANT_ADV" "$HARVEST_OWNER_HEX" 0
area_after=$(model_get dojo_starter-AreaOwnership "$HARVEST_OWNER_AREA0")
owner_after=$(canon_hex "$(model_field "$area_after" owner_adventurer_id)")
if [[ "$owner_before" == "$owner_after" ]]; then
  add_result "discover_area_wrong_hex_guard" "PASS" "owner unchanged=$owner_after" "$LAST_TX"
else
  add_result "discover_area_wrong_hex_guard" "FAIL" "owner changed $owner_before->$owner_after" "$LAST_TX"
fi

# 4) Guard: init harvesting on non-plant control area should not write PlantNode
run_tx "$HARVEST_OWNER_ACCT" "init_harvest_non_plant_guard" dojo_starter-harvesting_manager init_harvesting "$HARVEST_OWNER_HEX" "$HARVEST_OWNER_AREA0" 1
nonplant_write=$(printf '%s\n' "$LAST_RECEIPT" | jq -r --arg me "$MODEL_EVT_SELECTOR" --arg ps "$PLANT_SELECTOR" --arg a "$HARVEST_OWNER_AREA0" '.events[] | select(.keys[0]==$me and .keys[1]==$ps) | select(.data[4]==$a) | .data[1]' | head -n1)
if [[ -z "$nonplant_write" ]]; then
  add_result "init_harvest_non_plant_guard" "PASS" "no PlantNode write on control area" "$LAST_TX"
else
  add_result "init_harvest_non_plant_guard" "FAIL" "unexpected PlantNode write=$nonplant_write" "$LAST_TX"
fi

# 5) Harvest lifecycle success on harvest owner's plant field
PLANT_ID=1
run_tx "$HARVEST_OWNER_ACCT" "init_harvest" dojo_starter-harvesting_manager init_harvesting "$HARVEST_OWNER_HEX" "$HARVEST_OWNER_AREA_PLANT" "$PLANT_ID"
plant_data=$(event_model_data "$PLANT_SELECTOR")
PLANT_KEY=$(printf '%s\n' "$plant_data" | jq -r '.[1] // empty')
if [[ -z "$PLANT_KEY" ]]; then
  add_result "init_harvest" "FAIL" "missing PlantNode write" "$LAST_TX"
  cat "$RESULTS"
  exit 1
fi
add_result "init_harvest" "PASS" "plant_key=$PLANT_KEY" "$LAST_TX"

run_tx "$HARVEST_OWNER_ACCT" "start_harvest_complete_path" dojo_starter-harvesting_manager start_harvesting "$HARVEST_OWNER_ADV" "$HARVEST_OWNER_HEX" "$HARVEST_OWNER_AREA_PLANT" "$PLANT_ID" 3
add_result "start_harvest_complete_path" "PASS" "amount=3" "$LAST_TX"

gen_blocks 7
run_tx "$HARVEST_OWNER_ACCT" "complete_harvest" dojo_starter-harvesting_manager complete_harvesting "$HARVEST_OWNER_ADV" "$HARVEST_OWNER_HEX" "$HARVEST_OWNER_AREA_PLANT" "$PLANT_ID"
item_data=$(event_model_data "$BACKPACK_SELECTOR")
ITEM_ID=$(printf '%s\n' "$item_data" | jq -r --arg adv "$HARVEST_OWNER_ADV" 'select(.[1]==$adv) | .[2] // empty')
if [[ -z "$ITEM_ID" ]]; then
  add_result "complete_harvest" "FAIL" "missing backpack item write" "$LAST_TX"
  cat "$RESULTS"
  exit 1
fi
add_result "complete_harvest" "PASS" "item_id=$ITEM_ID" "$LAST_TX"

run_tx "$HARVEST_OWNER_ACCT" "start_harvest_cancel_path" dojo_starter-harvesting_manager start_harvesting "$HARVEST_OWNER_ADV" "$HARVEST_OWNER_HEX" "$HARVEST_OWNER_AREA_PLANT" "$PLANT_ID" 4
add_result "start_harvest_cancel_path" "PASS" "amount=4" "$LAST_TX"

gen_blocks 2
run_tx "$HARVEST_OWNER_ACCT" "cancel_harvest" dojo_starter-harvesting_manager cancel_harvesting "$HARVEST_OWNER_ADV" "$HARVEST_OWNER_HEX" "$HARVEST_OWNER_AREA_PLANT" "$PLANT_ID"
add_result "cancel_harvest" "PASS" "partial_yield_path" "$LAST_TX"

inspect_blob=$(sozo call dojo_starter-harvesting_manager inspect_plant "$HARVEST_OWNER_HEX" "$HARVEST_OWNER_AREA_PLANT" "$PLANT_ID" 2>&1 | tail -n1)
if printf '%s' "$inspect_blob" | grep -qi "plant_key"; then
  add_result "inspect_plant" "PASS" "inspect returned struct" ""
else
  add_result "inspect_plant" "PASS" "inspect returned tuple data" ""
fi

# 6) Convert items + maintenance payment
run_tx "$HARVEST_OWNER_ACCT" "convert_items_to_energy" dojo_starter-economic_manager convert_items_to_energy "$HARVEST_OWNER_ADV" "$ITEM_ID" 2
add_result "convert_items_to_energy" "PASS" "quantity=2" "$LAST_TX"

run_tx "$HARVEST_OWNER_ACCT" "pay_hex_maintenance" dojo_starter-economic_manager pay_hex_maintenance "$HARVEST_OWNER_ADV" "$HARVEST_OWNER_HEX" 10
add_result "pay_hex_maintenance" "PASS" "amount=10" "$LAST_TX"

if (( MINE_AVAILABLE == 1 )); then
  # 6b) Mining lifecycle on a discovered mine field
  run_tx "$MINE_CONTROLLER_ACCT" "init_mining" dojo_starter-mining_manager init_mining "$MINE_HEX" "$MINE_AREA" 0
  inspect_mine_blob=$(sozo call dojo_starter-mining_manager inspect_mine "$MINE_HEX" "$MINE_AREA" 0 2>&1 | tail -n1)
  MINE_KEY="$(first_hex_in_text "$inspect_mine_blob")"
  if [[ -z "$MINE_KEY" ]]; then
    add_result "init_mining" "FAIL" "inspect_mine missing mine key" "$LAST_TX"
    cat "$RESULTS"
    exit 1
  fi
  MINE_KEY="$(canon_hex "$MINE_KEY")"
  mine_row=$(model_get dojo_starter-MineNode "$MINE_KEY")
  mine_threshold=$(model_field "$mine_row" collapse_threshold)
  if [[ -z "$mine_threshold" || "$mine_threshold" == "0" || "$mine_threshold" == "0x0" ]]; then
    add_result "init_mining" "FAIL" "mine node not initialized mine_key=$MINE_KEY" "$LAST_TX"
    cat "$RESULTS"
    exit 1
  fi
  add_result "init_mining" "PASS" "mine_key=$MINE_KEY threshold=$mine_threshold" "$LAST_TX"

  run_tx "$MINE_CONTROLLER_ACCT" "grant_mine_access" dojo_starter-mining_manager grant_mine_access "$MINE_CONTROLLER_ADV" "$MINE_KEY" "$MINE_GRANTEE_ADV"
  add_result "grant_mine_access" "PASS" "grantee=$MINE_GRANTEE_ADV" "$LAST_TX"

  # Guard: grantee cannot start from a different hex.
  grantee_before=$(model_get dojo_starter-Adventurer "$MINE_GRANTEE_ADV")
  grantee_lock_before=$(model_field "$grantee_before" activity_locked_until)
  run_tx "$MINE_GRANTEE_ACCT" "start_mining_wrong_hex_guard" dojo_starter-mining_manager start_mining "$MINE_GRANTEE_ADV" "$MINE_HEX" "$MINE_AREA" 0
  grantee_after=$(model_get dojo_starter-Adventurer "$MINE_GRANTEE_ADV")
  grantee_lock_after=$(model_field "$grantee_after" activity_locked_until)
  if [[ "${grantee_lock_before:-0}" == "${grantee_lock_after:-0}" ]]; then
    add_result "start_mining_wrong_hex_guard" "PASS" "grantee lock unchanged=${grantee_lock_after:-0}" "$LAST_TX"
  else
    add_result "start_mining_wrong_hex_guard" "FAIL" "grantee lock changed ${grantee_lock_before:-0}->${grantee_lock_after:-0}" "$LAST_TX"
    cat "$RESULTS"
    exit 1
  fi

  # Use controller for deterministic mining lifecycle (actor already on mine hex).
  MINE_MINER_ADV="$MINE_CONTROLLER_ADV"
  MINE_MINER_ACCT="$MINE_CONTROLLER_ACCT"

  miner_before=$(model_get dojo_starter-Adventurer "$MINE_MINER_ADV")
  miner_before_energy=$(model_field "$miner_before" energy)
  miner_before_lock=$(model_field "$miner_before" activity_locked_until)
  inv_before_row=$(model_get dojo_starter-Inventory "$MINE_MINER_ADV")
  inv_before=$(model_field "$inv_before_row" current_weight)
  inv_before=${inv_before:-0}

  run_tx "$MINE_MINER_ACCT" "start_mining" dojo_starter-mining_manager start_mining "$MINE_MINER_ADV" "$MINE_HEX" "$MINE_AREA" 0
  miner_after_start=$(model_get dojo_starter-Adventurer "$MINE_MINER_ADV")
  miner_after_start_lock=$(model_field "$miner_after_start" activity_locked_until)
  if [[ "$miner_after_start_lock" != "18446744073709551615" && "$miner_after_start_lock" != "0xffffffffffffffff" ]]; then
    add_result "start_mining" "FAIL" "lock not applied value=$miner_after_start_lock" "$LAST_TX"
    cat "$RESULTS"
    exit 1
  fi
  add_result "start_mining" "PASS" "lock=$miner_after_start_lock prev_lock=${miner_before_lock:-0}" "$LAST_TX"

  gen_blocks 1
  run_tx "$MINE_MINER_ACCT" "continue_mining_1" dojo_starter-mining_manager continue_mining "$MINE_MINER_ADV" "$MINE_KEY"
  add_result "continue_mining_1" "PASS" "mine_key=$MINE_KEY" "$LAST_TX"

  run_tx "$MINE_MINER_ACCT" "stabilize_mine" dojo_starter-mining_manager stabilize_mine "$MINE_MINER_ADV" "$MINE_KEY"
  add_result "stabilize_mine" "PASS" "mine_key=$MINE_KEY" "$LAST_TX"

  gen_blocks 1
  run_tx "$MINE_MINER_ACCT" "continue_mining_2" dojo_starter-mining_manager continue_mining "$MINE_MINER_ADV" "$MINE_KEY"
  add_result "continue_mining_2" "PASS" "mine_key=$MINE_KEY" "$LAST_TX"

  run_tx "$MINE_MINER_ACCT" "exit_mining" dojo_starter-mining_manager exit_mining "$MINE_MINER_ADV" "$MINE_KEY"
  miner_after_exit=$(model_get dojo_starter-Adventurer "$MINE_MINER_ADV")
  miner_after_exit_energy=$(model_field "$miner_after_exit" energy)
  miner_after_exit_lock=$(model_field "$miner_after_exit" activity_locked_until)
  inv_after_row=$(model_get dojo_starter-Inventory "$MINE_MINER_ADV")
  inv_after=$(model_field "$inv_after_row" current_weight)
  inv_after=${inv_after:-0}
  if (( inv_after > inv_before )) && [[ "$(canon_hex "${miner_after_exit_lock:-0x0}")" == "0x0" ]]; then
    add_result "exit_mining" "PASS" "inv ${inv_before}->${inv_after} energy ${miner_before_energy:-0}->${miner_after_exit_energy:-0}" "$LAST_TX"
  else
    add_result "exit_mining" "FAIL" "inv ${inv_before}->${inv_after} lock=${miner_after_exit_lock}" "$LAST_TX"
    cat "$RESULTS"
    exit 1
  fi
fi

# 7) Unauthorized move check
owner_before_move=$(model_get dojo_starter-Adventurer "$HARVEST_OWNER_ADV")
hex_before=$(canon_hex "$(model_field "$owner_before_move" current_hex)")
run_tx "$CLAIMANT_ACCT" "unauthorized_move_attempt" dojo_starter-world_manager move_adventurer "$HARVEST_OWNER_ADV" "$EAST2"
owner_after_move=$(model_get dojo_starter-Adventurer "$HARVEST_OWNER_ADV")
hex_after=$(canon_hex "$(model_field "$owner_after_move" current_hex)")
if [[ "$hex_before" == "$hex_after" ]]; then
  add_result "unauthorized_move_attempt" "PASS" "position unchanged=$hex_after" "$LAST_TX"
else
  add_result "unauthorized_move_attempt" "FAIL" "position changed $hex_before->$hex_after" "$LAST_TX"
fi

# 8) Claim path on claim-capable biome hex
# Build reserve to target and process exact number of periods.
claim_state_before=$(model_get dojo_starter-HexDecayState "$CLAIM_OWNER_HEX")
reserve_before=$(model_field "$claim_state_before" current_energy_reserve)
reserve_before=${reserve_before:-0}
prep_payment=0
if (( reserve_before < CLAIM_TARGET_RESERVE )); then
  prep_payment=$((CLAIM_TARGET_RESERVE - reserve_before))
fi
if (( prep_payment > 0 )); then
  run_tx "$CLAIM_OWNER_ACCT" "claim_prep_pay" dojo_starter-economic_manager pay_hex_maintenance "$CLAIM_OWNER_ADV" "$CLAIM_OWNER_HEX" "$prep_payment"
  add_result "claim_prep_pay" "PASS" "amount=$prep_payment biome=${BIOMES[$CLAIM_OWNER_IDX]}" "$LAST_TX"
else
  add_result "claim_prep_pay" "PASS" "skipped reserve_before=$reserve_before" ""
fi

gen_blocks $((CLAIM_PERIODS * 100))

run_tx "$CLAIM_OWNER_ACCT" "regen_claim_owner_before_claim" dojo_starter-adventurer_manager regenerate_energy "$CLAIM_OWNER_ADV"
add_result "regen_claim_owner_before_claim" "PASS" "claim owner regen" "$LAST_TX"
run_tx "$CLAIMANT_ACCT" "regen_claimant_before_claim" dojo_starter-adventurer_manager regenerate_energy "$CLAIMANT_ADV"
add_result "regen_claimant_before_claim" "PASS" "claimant regen" "$LAST_TX"

run_tx "$CLAIM_OWNER_ACCT" "process_hex_decay" dojo_starter-economic_manager process_hex_decay "$CLAIM_OWNER_HEX"
claim_state=$(model_get dojo_starter-HexDecayState "$CLAIM_OWNER_HEX")
decay_level=$(model_field "$claim_state" decay_level)
claimable_since=$(canon_hex "$(model_field "$claim_state" claimable_since_block)")
add_result "process_hex_decay" "PASS" "decay=$decay_level claimable_since=$claimable_since" "$LAST_TX"

if [[ "$claimable_since" == "0x0" ]]; then
  add_result "initiate_hex_claim" "FAIL" "hex not claimable after prep (biome=${BIOMES[$CLAIM_OWNER_IDX]} decay=$decay_level)" ""
  cat "$RESULTS"
  exit 1
fi

run_tx "$CLAIMANT_ACCT" "initiate_hex_claim" dojo_starter-economic_manager initiate_hex_claim "$CLAIMANT_ADV" "$CLAIM_OWNER_HEX" 100
claim_data=$(event_model_data "$CLAIM_SELECTOR")
CLAIM_ID=$(printf '%s\n' "$claim_data" | jq -r '.[1] // empty')
if [[ -z "$CLAIM_ID" ]]; then
  add_result "initiate_hex_claim" "FAIL" "missing claim escrow write (biome=${BIOMES[$CLAIM_OWNER_IDX]} decay=$decay_level)" "$LAST_TX"
  cat "$RESULTS"
  exit 1
fi
add_result "initiate_hex_claim" "PASS" "claim_id=$CLAIM_ID" "$LAST_TX"

run_tx "$CLAIM_OWNER_ACCT" "defend_hex_from_claim" dojo_starter-economic_manager defend_hex_from_claim "$CLAIM_OWNER_ADV" "$CLAIM_OWNER_HEX" 100
claim_row=$(model_get dojo_starter-ClaimEscrow "$CLAIM_ID")
claim_status=$(model_field "$claim_row" status)
if [[ "$claim_status" == "3" || "$claim_status" == "Resolved" || "$claim_status" == "ClaimEscrowStatus::Resolved" ]]; then
  add_result "defend_hex_from_claim" "PASS" "escrow_resolved status=$claim_status" "$LAST_TX"
else
  add_result "defend_hex_from_claim" "FAIL" "unexpected escrow status=$claim_status" "$LAST_TX"
fi

# 9) Ownership get + transfer success
owner_before_transfer=$(sozo_call_one dojo_starter-ownership_manager get_owner "$HARVEST_OWNER_AREA_TRANSFER")
run_tx "$HARVEST_OWNER_ACCT" "transfer_ownership" dojo_starter-ownership_manager transfer_ownership "$HARVEST_OWNER_AREA_TRANSFER" "$TRANSFER_TO_ADV"
owner_after_transfer=$(sozo_call_one dojo_starter-ownership_manager get_owner "$HARVEST_OWNER_AREA_TRANSFER")
if [[ "$(canon_hex "$owner_after_transfer")" == "$(canon_hex "$TRANSFER_TO_ADV")" ]]; then
  add_result "transfer_ownership" "PASS" "owner $owner_before_transfer -> $owner_after_transfer" "$LAST_TX"
else
  add_result "transfer_ownership" "FAIL" "owner stayed $owner_after_transfer" "$LAST_TX"
fi

# 10) Consume + regen explicit action on claimant
run_tx "$CLAIMANT_ACCT" "consume_energy" dojo_starter-adventurer_manager consume_energy "$CLAIMANT_ADV" 20
add_result "consume_energy" "PASS" "amount=20" "$LAST_TX"

gen_blocks 120
run_tx "$CLAIMANT_ACCT" "regenerate_energy" dojo_starter-adventurer_manager regenerate_energy "$CLAIMANT_ADV"
add_result "regenerate_energy" "PASS" "post-consume regen" "$LAST_TX"

# 11) Kill adventurer + dead move guard
run_tx "$DEAD_ACCT" "kill_adventurer" dojo_starter-adventurer_manager kill_adventurer "$DEAD_ADV" sstr:TEST
dead_row=$(model_get dojo_starter-Adventurer "$DEAD_ADV")
dead_alive=$(model_field "$dead_row" is_alive)
if [[ "$dead_alive" == "0" || "$dead_alive" == "0x0" || "$dead_alive" == "false" ]]; then
  add_result "kill_adventurer" "PASS" "is_alive=0" "$LAST_TX"
else
  add_result "kill_adventurer" "FAIL" "is_alive=$dead_alive" "$LAST_TX"
fi

dead_hex_before=$(model_field "$dead_row" current_hex)
run_tx "$DEAD_ACCT" "dead_move_guard" dojo_starter-world_manager move_adventurer "$DEAD_ADV" "$EAST2"
dead_row_after=$(model_get dojo_starter-Adventurer "$DEAD_ADV")
dead_hex_after=$(model_field "$dead_row_after" current_hex)
if [[ "$(canon_hex "$dead_hex_before")" == "$(canon_hex "$dead_hex_after")" ]]; then
  add_result "dead_move_guard" "PASS" "dead adventurer cannot move" "$LAST_TX"
else
  add_result "dead_move_guard" "FAIL" "dead adventurer moved" "$LAST_TX"
fi

# 12) Ownership to dead should fail
run_tx "$TRANSFER_TO_ACCT" "transfer_to_dead_guard" dojo_starter-ownership_manager transfer_ownership "$HARVEST_OWNER_AREA_TRANSFER" "$DEAD_ADV"
owner_after_dead_transfer=$(sozo_call_one dojo_starter-ownership_manager get_owner "$HARVEST_OWNER_AREA_TRANSFER")
if [[ "$(canon_hex "$owner_after_dead_transfer")" == "$(canon_hex "$TRANSFER_TO_ADV")" ]]; then
  add_result "transfer_to_dead_guard" "PASS" "owner unchanged=$owner_after_dead_transfer" "$LAST_TX"
else
  add_result "transfer_to_dead_guard" "FAIL" "unexpected owner=$owner_after_dead_transfer" "$LAST_TX"
fi

# 13) Mining collapse attempt (single locked miner, long shift)
if (( MINE_AVAILABLE == 1 )); then
  # Regenerate to ensure enough energy for repeated continue attempts.
  gen_blocks 600
  run_tx "$MINE_CONTROLLER_ACCT" "regen_before_collapse_attempt" dojo_starter-adventurer_manager regenerate_energy "$MINE_CONTROLLER_ADV"
  add_result "regen_before_collapse_attempt" "PASS" "controller regen before collapse attempt" "$LAST_TX"

  mine_actor_row=$(model_get dojo_starter-Adventurer "$MINE_CONTROLLER_ADV")
  mine_actor_alive=$(model_field "$mine_actor_row" is_alive)
  if [[ "$mine_actor_alive" != "1" && "$mine_actor_alive" != "0x1" && "$mine_actor_alive" != "true" ]]; then
    add_result "mine_collapse_attempt" "SKIP" "controller dead before collapse attempt" ""
  else
    run_tx "$MINE_CONTROLLER_ACCT" "start_mining_for_collapse" dojo_starter-mining_manager start_mining "$MINE_CONTROLLER_ADV" "$MINE_HEX" "$MINE_AREA" 0
    mine_lock_now=$(model_field "$(model_get dojo_starter-Adventurer "$MINE_CONTROLLER_ADV")" activity_locked_until)
    if [[ "$mine_lock_now" != "18446744073709551615" && "$mine_lock_now" != "0xffffffffffffffff" ]]; then
      add_result "start_mining_for_collapse" "FAIL" "lock not applied value=$mine_lock_now" "$LAST_TX"
      cat "$RESULTS"
      exit 1
    fi
    add_result "start_mining_for_collapse" "PASS" "lock applied" "$LAST_TX"

    collapsed=0
    attempts=0
    for attempt in 1 2 3 4 5 6; do
      attempts=$attempt
      gen_blocks 400
      run_tx "$MINE_CONTROLLER_ACCT" "continue_mining_collapse_try_${attempt}" dojo_starter-mining_manager continue_mining "$MINE_CONTROLLER_ADV" "$MINE_KEY"
      mine_row_after_try=$(model_get dojo_starter-MineNode "$MINE_KEY")
      mine_repair_needed=$(model_field "$mine_row_after_try" repair_energy_needed)
      mine_stress=$(model_field "$mine_row_after_try" mine_stress)
      mine_thresh=$(model_field "$mine_row_after_try" collapse_threshold)
      mine_repair_needed=${mine_repair_needed:-0}
      if [[ "$mine_repair_needed" != "0" && "$mine_repair_needed" != "0x0" ]]; then
        add_result "continue_mining_collapse_try_${attempt}" "PASS" "collapsed stress=${mine_stress:-0} threshold=${mine_thresh:-0} repair=${mine_repair_needed}" "$LAST_TX"
        collapsed=1
        break
      fi
      add_result "continue_mining_collapse_try_${attempt}" "PASS" "no collapse stress=${mine_stress:-0} threshold=${mine_thresh:-0}" "$LAST_TX"
    done

    if (( collapsed == 1 )); then
      mine_actor_post=$(model_get dojo_starter-Adventurer "$MINE_CONTROLLER_ADV")
      mine_actor_post_alive=$(model_field "$mine_actor_post" is_alive)
      if [[ "$mine_actor_post_alive" == "0" || "$mine_actor_post_alive" == "0x0" || "$mine_actor_post_alive" == "false" ]]; then
        add_result "mine_collapse_attempt" "PASS" "mine collapsed in ${attempts} attempts and miner died" ""
      else
        add_result "mine_collapse_attempt" "FAIL" "mine collapsed but miner alive=$mine_actor_post_alive" ""
      fi
    else
      add_result "mine_collapse_attempt" "FAIL" "mine did not collapse after ${attempts} attempts" ""
    fi
  fi
else
  add_result "mine_collapse_attempt" "SKIP" "no mine available for collapse attempt" ""
fi

# Summary
pass_count=$(awk -F'\t' 'NR>1 && $2=="PASS" {c++} END{print c+0}' "$RESULTS")
fail_count=$(awk -F'\t' 'NR>1 && $2=="FAIL" {c++} END{print c+0}' "$RESULTS")

echo "PASS_COUNT=$pass_count"
echo "FAIL_COUNT=$fail_count"
cat "$RESULTS"
