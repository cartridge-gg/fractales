# Generalized Action Framework

## Vision: Universal Module Interface

Create a standardized action system where:

- **All modules** implement the same action interface
- **Hooks work universally** across any module without modification
- **New modules** can be added without changing core systems
- **Type safety** is maintained while providing flexibility

## Core Action Framework

```python
# Universal action interface that all modules must implement
trait IGameModule:
    fn get_module_id() -> felt252;
    fn get_supported_actions() -> Array<ActionDefinition>;
    fn validate_action(action: ActionRequest) -> ValidationResult;
    fn execute_action(action: ActionRequest) -> ActionResult;
    fn get_action_cost(action: ActionRequest) -> ActionCost;

# Standardized action structure
#[derive(Drop, Serde, starknet::Store)]
struct ActionRequest:
    module_id: felt252,           # "mining", "harvesting", "crafting", etc.
    action_type: felt252,         # "start_mining", "harvest_plant", "craft_item"
    actor_id: felt252,            # adventurer performing the action
    target_id: felt252,           # object being acted upon (vein_id, plant_id, etc.)
    parameters: Array<felt252>,   # action-specific parameters
    context: ActionContext,       # shared context information

#[derive(Drop, Serde, starknet::Store)]
struct ActionContext:
    timestamp: u64,
    block_number: u64,
    caller_address: felt252,
    energy_available: u32,
    inventory_state: felt252,     # hash of current inventory

#[derive(Drop, Serde, starknet::Store)]
struct ActionDefinition:
    action_type: felt252,
    parameter_schema: Array<ParameterDef>,
    energy_cost_formula: felt252,
    time_lock_duration: u64,
    permission_level: PermissionLevel,

enum PermissionLevel:
    Public,           # Anyone can perform
    Restricted,       # Requires specific permissions
    ControllerOnly,   # Only object controller
    ModuleSpecific,   # Custom module validation

# Centralized action dispatcher
#[starknet::contract]
mod ActionDispatcher:
    use super::{IGameModule, IUniversalHook};

    #[storage]
    struct Storage:
        registered_modules: LegacyMap<felt252, felt252>,     # module_id → contract_address
        object_controllers: LegacyMap<felt252, felt252>,     # object_id → controller_address
        object_hooks: LegacyMap<felt252, Array<felt252>>,   # object_id → [hook_addresses]
        active_time_locks: LegacyMap<felt252, TimeLock>,     # actor_id → current_lock

    #[external(v0)]
    fn execute_action(action: ActionRequest) -> ActionResult:
        # 1. Validate module exists
        let module_address = self.registered_modules.read(action.module_id);
        assert module_address != 0.into(), "Module not registered";

        # 2. Check time locks
        assert !is_actor_locked(action.actor_id), "Actor is time-locked";

        # 3. Get module interface
        let module = IGameModuleDispatcher(module_address);

        # 4. Validate action
        let validation = module.validate_action(action);
        assert validation.is_valid, validation.error_message;

        # 5. Run permission hooks
        let hook_result = self.run_permission_hooks(action);
        match hook_result:
            HookResult.Denied(reason) => return ActionResult.PermissionDenied(reason),
            HookResult.RequiresPayment(amount, recipient) => {
                self.process_payment(action.actor_id, recipient, amount);
            },
            HookResult.Approved => {},
        };

        # 6. Execute the action
        let result = module.execute_action(action);

        # 7. Apply time lock if needed
        if result.time_lock_duration > 0:
            self.apply_time_lock(action.actor_id, result.time_lock_duration);
        }

        # 8. Run post-action hooks
        self.run_post_action_hooks(action, result);

        result

    fn run_permission_hooks(action: ActionRequest) -> HookResult:
        let hooks = self.object_hooks.read(action.target_id);

        for hook_address in hooks:
            let hook = IUniversalHookDispatcher(hook_address);
            let permission = hook.before_action(
                action.actor_id,
                action.target_id,
                action.action_type,
                action.parameters.span()
            );

            match permission:
                PermissionResult.Denied(reason) => return HookResult.Denied(reason),
                PermissionResult.RequiresPayment(amount, recipient) => {
                    # Could accumulate multiple payments
                    return HookResult.RequiresPayment(amount, recipient);
                },
                PermissionResult.Custom(custom_action, params) => {
                    # Handle custom permission logic
                    self.handle_custom_permission(custom_action, params);
                },
                _ => continue,
            };
        }

        HookResult.Approved
```

## Module Implementation Pattern

Each game module follows the same pattern:

```python
# Example: Mining Module
#[starknet::contract]
mod MiningModule:
    use super::{IGameModule, ActionRequest, ActionResult};

    impl IGameModule for MiningModule:
        fn get_module_id() -> felt252:
            'mining'

        fn get_supported_actions() -> Array<ActionDefinition>:
            array![
                ActionDefinition(
                    action_type: 'start_mining',
                    parameter_schema: array![
                        ParameterDef('vein_id', 'felt252'),
                        ParameterDef('duration_blocks', 'u64'),
                        ParameterDef('target_amount', 'u32')
                    ],
                    energy_cost_formula: 'target_amount * vein_hardness / 10',
                    time_lock_duration: 0, # Calculated dynamically
                    permission_level: PermissionLevel.Restricted
                ),
                ActionDefinition(
                    action_type: 'collect_ore',
                    parameter_schema: array![
                        ParameterDef('mining_operation_id', 'felt252')
                    ],
                    energy_cost_formula: '0', # No additional cost
                    time_lock_duration: 0,
                    permission_level: PermissionLevel.Public
                )
            ]

        fn validate_action(action: ActionRequest) -> ValidationResult:
            match action.action_type:
                'start_mining' => validate_start_mining(action),
                'collect_ore' => validate_collect_ore(action),
                _ => ValidationResult.Invalid("Unknown action type")
            }

        fn execute_action(action: ActionRequest) -> ActionResult:
            match action.action_type:
                'start_mining' => execute_start_mining(action),
                'collect_ore' => execute_collect_ore(action),
                _ => ActionResult.Error("Unknown action type")
            }

    # Module-specific implementation details
    fn validate_start_mining(action: ActionRequest) -> ValidationResult:
        let vein_id = action.parameters[0];
        let duration = action.parameters[1];
        let target_amount = action.parameters[2];

        # Check vein exists
        let vein = mining_veins.read(vein_id);
        if vein.discovery_block == 0:
            return ValidationResult.Invalid("Vein does not exist");

        # Check vein capacity
        if vein.current_miners >= vein.max_safe_miners + 2:
            return ValidationResult.Invalid("Vein at capacity");

        # Check adventurer energy
        let energy_cost = calculate_mining_energy_cost(target_amount, vein.ore_traits.hardness, duration);
        if action.context.energy_available < energy_cost:
            return ValidationResult.Invalid("Insufficient energy");

        ValidationResult.Valid

    fn execute_start_mining(action: ActionRequest) -> ActionResult:
        # Core mining logic here
        let vein_id = action.parameters[0];
        let duration = action.parameters[1];
        let target_amount = action.parameters[2];

        # Create mining operation
        let operation = create_mining_operation(action.actor_id, vein_id, duration, target_amount);

        # Update vein state
        add_miner_to_vein(vein_id, action.actor_id);

        ActionResult.Success(
            time_lock_duration: duration,
            state_changes: array![
                StateChange('vein_miners', vein_id, get_current_miners(vein_id)),
                StateChange('mining_operation', operation.id, operation)
            ],
            events: array![
                Event('MiningStarted', array![action.actor_id, vein_id, target_amount])
            ]
        )

# Example: Harvesting Module
#[starknet::contract]
mod HarvestingModule:
    impl IGameModule for HarvestingModule:
        fn get_module_id() -> felt252:
            'harvesting'

        fn get_supported_actions() -> Array<ActionDefinition>:
            array![
                ActionDefinition(
                    action_type: 'harvest_plant',
                    parameter_schema: array![
                        ParameterDef('plant_id', 'felt252'),
                        ParameterDef('quantity', 'u32')
                    ],
                    energy_cost_formula: 'quantity * 5',
                    time_lock_duration: 10, # 10 blocks per harvest
                    permission_level: PermissionLevel.Restricted
                ),
                ActionDefinition(
                    action_type: 'explore_area',
                    parameter_schema: array![
                        ParameterDef('hex_coord', 'felt252'),
                        ParameterDef('area_index', 'u32')
                    ],
                    energy_cost_formula: '50',
                    time_lock_duration: 5,
                    permission_level: PermissionLevel.Public
                )
            ]

        fn validate_action(action: ActionRequest) -> ValidationResult:
            match action.action_type:
                'harvest_plant' => validate_harvest_plant(action),
                'explore_area' => validate_explore_area(action),
                _ => ValidationResult.Invalid("Unknown action type")
            }

        fn execute_action(action: ActionRequest) -> ActionResult:
            match action.action_type:
                'harvest_plant' => execute_harvest_plant(action),
                'explore_area' => execute_explore_area(action),
                _ => ActionResult.Error("Unknown action type")
            }

# Example: Crafting Module
#[starknet::contract]
mod CraftingModule:
    impl IGameModule for CraftingModule:
        fn get_module_id() -> felt252:
            'crafting'

        fn get_supported_actions() -> Array<ActionDefinition>:
            array![
                ActionDefinition(
                    action_type: 'craft_combination',
                    parameter_schema: array![
                        ParameterDef('ingredient_1', 'felt252'),
                        ParameterDef('ingredient_2', 'felt252'),
                        ParameterDef('crafting_method', 'felt252')
                    ],
                    energy_cost_formula: '25 + complexity_bonus',
                    time_lock_duration: 20, # Variable based on complexity
                    permission_level: PermissionLevel.Public
                )
            ]

        # Implementation details...
```

## Module Registry & Discovery

```python
# Central module registry
#[starknet::contract]
mod ModuleRegistry:
    #[storage]
    struct Storage:
        registered_modules: LegacyMap<felt252, ModuleInfo>,
        module_count: u32,

    #[derive(Drop, Serde, starknet::Store)]
    struct ModuleInfo:
        contract_address: felt252,
        version: u32,
        registration_block: u64,
        is_active: bool,

    #[external(v0)]
    fn register_module(
        module_id: felt252,
        contract_address: felt252,
        version: u32
    ):
        # Only authorized addresses can register modules
        assert is_authorized_deployer(caller_address()), "Not authorized";

        # Validate module implements interface correctly
        let module = IGameModuleDispatcher(contract_address);
        assert module.get_module_id() == module_id, "Module ID mismatch";

        # Test that all required functions work
        let actions = module.get_supported_actions();
        assert actions.len() > 0, "Module must support at least one action";

        # Register the module
        self.registered_modules.write(module_id, ModuleInfo(
            contract_address: contract_address,
            version: version,
            registration_block: starknet::get_block_info().block_number,
            is_active: true
        ));

        self.module_count.write(self.module_count.read() + 1);

        emit ModuleRegistered(module_id, contract_address, version);

    #[external(v0)]
    fn get_module_info(module_id: felt252) -> ModuleInfo:
        self.registered_modules.read(module_id)

    #[view]
    fn list_all_modules() -> Array<felt252>:
        # Return all registered module IDs
        # Implementation would iterate through storage
```

## Standardized Parameter Handling

```python
# Type-safe parameter extraction utilities
mod ParameterUtils:
    fn extract_felt(params: Span<felt252>, index: u32) -> felt252:
        assert index < params.len(), "Parameter index out of bounds";
        *params.at(index)

    fn extract_u32(params: Span<felt252>, index: u32) -> u32:
        let value = extract_felt(params, index);
        value.try_into().expect('Invalid u32 parameter')

    fn extract_u64(params: Span<felt252>, index: u32) -> u64:
        let value = extract_felt(params, index);
        value.try_into().expect('Invalid u64 parameter')

    fn validate_parameter_count(params: Span<felt252>, expected: u32):
        assert params.len() == expected, "Wrong parameter count";

# Parameter schema validation
fn validate_action_parameters(
    action: ActionRequest,
    schema: Array<ParameterDef>
) -> ValidationResult:
    if action.parameters.len() != schema.len():
        return ValidationResult.Invalid("Wrong parameter count");

    for i in 0..schema.len():
        let param_def = schema.at(i);
        let param_value = action.parameters.at(i);

        if !validate_parameter_type(*param_value, *param_def.param_type):
            return ValidationResult.Invalid("Invalid parameter type");
    }

    ValidationResult.Valid
```

## Hook Compatibility Layer

```python
# Ensure hooks work with any module action
impl IUniversalHook:
    fn before_action(
        caller: felt252,
        target_id: felt252,
        action_type: felt252,
        action_params: Span<felt252>
    ) -> PermissionResult:
        # Hooks receive standardized parameters regardless of module
        # They can inspect action_type to handle different actions differently

        match action_type:
            'start_mining' => self.handle_mining_permission(caller, target_id, action_params),
            'harvest_plant' => self.handle_harvest_permission(caller, target_id, action_params),
            'craft_combination' => self.handle_crafting_permission(caller, target_id, action_params),
            _ => {
                # Default permission logic for unknown actions
                if self.is_whitelisted(caller):
                    PermissionResult.Approved
                } else {
                    PermissionResult.RequiresPayment(self.default_fee(), self.owner())
                }
            }
        }
```

## Benefits of This Architecture

**🔧 Clean Separation**: Core framework vs module-specific logic  
**🔌 Easy Extension**: New modules just implement the interface  
**🎯 Type Safety**: Standardized parameter handling with validation  
**🌐 Universal Hooks**: Hooks work across all modules without modification  
**📊 Introspection**: Modules self-describe their capabilities  
**⚡ Performance**: Optimized dispatch with minimal overhead

## Future Module Examples

With this framework, adding new modules becomes trivial:

```python
# Combat Module
mod CombatModule:
    # Actions: attack_adventurer, defend_position, flee_combat

# Social Module
mod SocialModule:
    # Actions: send_message, form_party, create_guild

# Housing Module
mod HousingModule:
    # Actions: build_structure, upgrade_building, set_permissions

# Research Module
mod ResearchModule:
    # Actions: study_item, unlock_blueprint, share_knowledge
```

Each new module gets **full hook support automatically** without any changes to the core system or existing hooks!

This creates the ultimate **composable, extensible game architecture** where innovation can happen at the module level while maintaining system-wide consistency.
