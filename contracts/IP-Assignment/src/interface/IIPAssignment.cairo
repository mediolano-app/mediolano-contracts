
use starknet::ContractAddress;

/// Data structure defining IP assignment conditions
#[derive(Drop, Serde, Clone, starknet::Store)]
pub struct AssignmentData {
    /// Assignment validity start (UNIX timestamp)
    pub start_time: u64,
    /// Assignment validity end (UNIX timestamp)
    pub end_time: u64,
    /// Royalty percentage in basis points (1% = 100)
    pub royalty_rate: u128,
    /// Percentage of rights transferred (0-100)
    pub rights_percentage: u8,
    /// Exclusive access flag
    pub is_exclusive: bool,
}

/// Contract Interface
#[starknet::interface]
pub trait IIPAssignment<TContractState> {
    // IP Management
    // #[doc = "Creates new IP with caller as owner"]
    fn create_ip(ref self: TContractState, ip_id: felt252);
    // #[doc = "Transfers ownership of an IP asset"]
    fn transfer_ip_ownership(ref self: TContractState, ip_id: felt252, new_owner: ContractAddress);
    
    // Assignment Operations
    // #[doc = "Assigns IP rights under specified conditions"]
    fn assign_ip(
        ref self: TContractState,
        ip_id: felt252,
        assignee: ContractAddress,
        conditions: AssignmentData,
    );
    // #[doc = "Retrieves assignment details for IP-assignee pair"]
    fn get_assignment_data(
        self: @TContractState, ip_id: felt252, assignee: ContractAddress,
    ) -> AssignmentData;
    // #[doc = "Verifies if current conditions are met"]
    fn check_assignment_condition(
        ref self: TContractState, ip_id: felt252, assignee: ContractAddress,
    ) -> bool;
    
    // Financial Operations
    // #[doc = "Process royalty payment distribution"]
    fn receive_royalty(ref self: TContractState, ip_id: felt252, amount: u128);
    // #[doc = "Withdraw accumulated royalties"]
    fn withdraw_royalties(ref self: TContractState, ip_id: felt252);
    
    // Getters
    // #[doc = "Returns contract admin address"]
    fn get_contract_owner(self: @TContractState) -> ContractAddress;
    // #[doc = "Returns current IP owner"]
    fn get_ip_owner(self: @TContractState, ip_id: felt252) -> ContractAddress;
    // #[doc = "Returns claimable royalties for address"]
    fn get_royalty_balance(
        self: @TContractState, ip_id: felt252, beneficiary: ContractAddress,
    ) -> u128;
}