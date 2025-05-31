//! Programmable IP Assignment Contract
//! 
//! Enables conditional IP rights management with configurable terms including
//! time-based access, revenue sharing, exclusivity, and partial rights transfers.
//! 
//! Features:
//! - Secure IP creation and ownership transfer
//! - Programmable assignment conditions with enforcement
//! - Royalty distribution system
//! - Exclusive rights management
//! - Partial rights tracking
//! - Event-driven architecture

/// Main Contract Implementation
#[starknet::contract]
pub mod IPAssignment {
    use starknet::storage::StoragePathEntry;
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StorableStoragePointerReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait},
    };
    use core::num::traits::Zero;
    use programmable_ip_assignment::interface::IIPAssignment::IIPAssignment;
    use programmable_ip_assignment::interface::IIPAssignment::AssignmentData;
    use core::array::ArrayTrait;
    use core::traits::Into;

    ///////////////////
    // Storage
    ///////////////////
    #[storage]
    pub struct Storage {
        // Administration
        contract_owner: ContractAddress,
        
        // IP Management
        ip_owner: Map<felt252, ContractAddress>,
        ip_created_at: Map<felt252, u64>,
        
        // Assignments
        assignments: Map<(felt252, ContractAddress), AssignmentData>,
        assignees_list: Map<felt252, Vec<ContractAddress>>,
        exclusive_assignee: Map<felt252, ContractAddress>,
        assignees: Map<(felt252, ContractAddress), bool>,
        total_assigned_rights: Map<felt252, u8>,
        
        // Financials
        royalty_balances: Map<(felt252, ContractAddress), u128>,
        total_royalty_reserve: Map<felt252, u128>,
    }

    ///////////////////
    // Events
    ///////////////////
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        IPCreated: IPCreated,
        IPAssigned: IPAssigned,
        IPOwnershipTransferred: IPOwnershipTransferred,
        RoyaltyReceived: RoyaltyReceived,
        RoyaltyWithdrawn: RoyaltyWithdrawn,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPCreated {
        pub ip_id: felt252,
        pub owner: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPAssigned {
        pub ip_id: felt252,
        pub assignee: ContractAddress,
        pub conditions: AssignmentData,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPOwnershipTransferred {
        pub ip_id: felt252,
        pub previous_owner: ContractAddress,
        pub new_owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoyaltyReceived {
        pub ip_id: felt252,
        pub amount: u128,
        pub recipient: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoyaltyWithdrawn {
        pub ip_id: felt252,
        pub beneficiary: ContractAddress,
        pub amount: u128,
    }

    ///////////////////
    // Constructor
    ///////////////////
    #[constructor]
    fn constructor(ref self: ContractState, initial_owner: ContractAddress) {
        self.contract_owner.write(initial_owner);
    }

    ///////////////////
    // Internal Logic
    ///////////////////
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        /// IP owner access control
        fn only_ip_owner(self: @ContractState, ip_id: felt252) {
            let caller = get_caller_address();
            assert(
                self.ip_owner.read(ip_id) == caller,
                'IP: Caller not owner'
            );
        }

        /// Contract owner access control
        fn only_contract_owner(self: @ContractState) {
            assert(
                self.contract_owner.read() == get_caller_address(),
                'IP: Caller not admin'
            );
        }

        /// Validate assignment parameters
        fn validate_conditions(self: @ContractState, conditions: AssignmentData) {
            let _now = get_block_timestamp();
            assert(
                conditions.end_time > conditions.start_time,
                'IP: Invalid time range'
            );
            assert(
                conditions.rights_percentage <= 100,
                'IP: Rights exceed 100%'
            );
            assert(
                conditions.royalty_rate <= 10000,
                'IP: Royalty rate too high'
            );
        }

        /// Calculate royalty distribution
        fn distribute_royalties(
            ref self: ContractState,
            ip_id: felt252,
            amount: u128
        ) -> u128 {
            let mut remaining = amount;
            let total_rate = self.calculate_total_royalty(ip_id);
            
            if total_rate > 0 {
                let owner = self.ip_owner.read(ip_id);
                let owner_share = amount * (10000 - total_rate) / 10000;
                
                // Credit owner's share
                self.royalty_balances.write((ip_id, owner), 
                    self.royalty_balances.read((ip_id, owner)) + owner_share);
                remaining -= owner_share;
                
                // Distribute to assignees
                let assignees = self.get_active_assignees(ip_id);

                for i in  0..assignees.len() {
                    let assignee = assignees.at(i);
                    let data = self.assignments.read((ip_id, *assignee));
                    let share = amount * data.royalty_rate / 10000;
                    self.royalty_balances.write((ip_id, *assignee), 
                        self.royalty_balances.read((ip_id, *assignee)) + share);
                    remaining -= share;
                }
            }
            remaining
        }

        /// Calculate total royalty obligations
        fn calculate_total_royalty(self: @ContractState, ip_id: felt252) -> u128 {
            let mut total = 0;
            let assignees = self.get_active_assignees(ip_id);
            for assignee in assignees {
                let data = self.assignments.read((ip_id, assignee));
                total += data.royalty_rate;
            };
            total
        }

        fn get_active_assignees(self: @ContractState, ip_id: felt252) -> Array<ContractAddress> {
            let mut active = array![];
            let now = get_block_timestamp();
            
            let assignees = self.assignees_list.entry(ip_id);
            let len = assignees.len();
            
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                let assignee = assignees.at(i).read();
                let data = self.assignments.read((ip_id, assignee));
                
                // Check time validity
                let time_valid = now >= data.start_time && now <= data.end_time;
                
                // Check exclusivity compliance
                let exclusive_valid = if data.is_exclusive {
                    self.exclusive_assignee.read(ip_id) == assignee
                } else {
                    true
                };
                
                if time_valid && exclusive_valid {
                    active.append(assignee);
                }
                i += 1;
            };
            active
        }
    }

    ///////////////////
    // External Functions
    ///////////////////
    #[abi(embed_v0)]
    pub impl IPAssignmentImpl of IIPAssignment<ContractState> {
        // IP Creation
        fn create_ip(ref self: ContractState, ip_id: felt252) {
            assert(
                self.ip_owner.read(ip_id) == Zero::zero(),
                'IP: Already exists'
            );
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            
            self.ip_owner.write(ip_id, caller);
            self.ip_created_at.write(ip_id, timestamp);
            
            self.emit(Event::IPCreated(IPCreated {
                ip_id,
                owner: caller,
                timestamp
            }));
        }

        // IP Ownership Transfer
        fn transfer_ip_ownership(
            ref self: ContractState,
            ip_id: felt252,
            new_owner: ContractAddress
        ) {
            self.only_ip_owner(ip_id);
            assert(new_owner != Zero::zero(), 'IP: Invalid owner');
            
            let previous_owner = self.ip_owner.read(ip_id);
            self.ip_owner.write(ip_id, new_owner);
            
            self.emit(Event::IPOwnershipTransferred(IPOwnershipTransferred {
                ip_id,
                previous_owner,
                new_owner
            }));
        }

        // IP Assignment
        fn assign_ip(
            ref self: ContractState,
            ip_id: felt252,
            assignee: ContractAddress,
            conditions: AssignmentData
        ) {
            self.only_ip_owner(ip_id);
            assert(assignee != Zero::zero(), 'IP: Invalid assignee');
            self.validate_conditions(conditions.clone());
            
            // Check exclusivity
            if conditions.is_exclusive {
                let existing = self.exclusive_assignee.read(ip_id);
                assert(existing == Zero::zero(), 'IP: Exclusive exists');
                self.exclusive_assignee.write(ip_id, assignee);
            }
            
            // Check rights allocation
            let total = self.total_assigned_rights.read(ip_id) 
                + conditions.rights_percentage;
            assert(total <= 100, 'IP: Rights exceeded');
            self.total_assigned_rights.write(ip_id, total);
            
            // Record assignment
            self.assignments.write((ip_id, assignee), conditions.clone());
            self.assignees.write((ip_id, assignee), true);
            
            self.emit(Event::IPAssigned(IPAssigned {
                ip_id,
                assignee,
                conditions
            }));
        }

        // Royalty Handling
        fn receive_royalty(ref self: ContractState, ip_id: felt252, amount: u128) {
            assert(amount > 0, 'IP: Invalid amount');
            
            let remaining = self.distribute_royalties(ip_id, amount);
            self.total_royalty_reserve.write(ip_id,
                self.total_royalty_reserve.read(ip_id) + remaining);
            
            self.emit(Event::RoyaltyReceived(RoyaltyReceived {
                ip_id,
                amount,
                recipient: get_caller_address()
            }));
        }

        // Royalty Withdrawal
        fn withdraw_royalties(ref self: ContractState, ip_id: felt252) {
            let caller = get_caller_address();
            let balance = self.royalty_balances.read((ip_id, caller));
            assert(balance > 0, 'IP: No balance');
            
            // Transfer logic would interface with token contract here
            self.royalty_balances.write((ip_id, caller), 0);
            
            self.emit(Event::RoyaltyWithdrawn(RoyaltyWithdrawn {
                ip_id,
                beneficiary: caller,
                amount: balance
            }));
        }

        // Getters
        fn get_assignment_data(
            self: @ContractState,
            ip_id: felt252,
            assignee: ContractAddress
        ) -> AssignmentData {
            self.assignments.read((ip_id, assignee))
        }

        fn check_assignment_condition(
            ref self: ContractState,
            ip_id: felt252,
            assignee: ContractAddress
        ) -> bool {
            // Read each field individually from storage
            let start_time = self.assignments.read((ip_id, assignee)).start_time;
            let end_time = self.assignments.read((ip_id, assignee)).end_time;
            let is_exclusive = self.assignments.read((ip_id, assignee)).is_exclusive;
        
            let now = get_block_timestamp();
        
            let mut valid = true;
            valid = valid && now >= start_time;
            valid = valid && now <= end_time;
        
            if is_exclusive {
                valid = valid && self.exclusive_assignee.read(ip_id) == assignee;
            }
        
            valid
        }

        fn get_contract_owner(self: @ContractState) -> ContractAddress {
            self.contract_owner.read()
        }

        fn get_ip_owner(self: @ContractState, ip_id: felt252) -> ContractAddress {
            self.ip_owner.read(ip_id)
        }

        fn get_royalty_balance(
            self: @ContractState,
            ip_id: felt252,
            beneficiary: ContractAddress
        ) -> u128 {
            self.royalty_balances.read((ip_id, beneficiary))
        }
    }
}