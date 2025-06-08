use starknet::ContractAddress;

#[starknet::interface]
pub trait IIPDrop<TContractState> {
    // ERC721 Standard Functions
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
    fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    );
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );

    // IP Drop Specific Functions
    fn claim(ref self: TContractState, quantity: u256);
    fn claim_with_payment(ref self: TContractState, quantity: u256);

    // Admin Functions
    fn set_claim_conditions(ref self: TContractState, conditions: ClaimConditions);
    fn add_to_allowlist(ref self: TContractState, address: ContractAddress);
    fn add_batch_to_allowlist(ref self: TContractState, addresses: Span<ContractAddress>);
    fn remove_from_allowlist(ref self: TContractState, address: ContractAddress);
    fn set_base_uri(ref self: TContractState, base_uri: ByteArray);
    fn set_allowlist_enabled(ref self: TContractState, enabled: bool);
    fn withdraw_payments(ref self: TContractState);

    // View Functions
    fn total_supply(self: @TContractState) -> u256;
    fn max_supply(self: @TContractState) -> u256;
    fn get_claim_conditions(self: @TContractState) -> ClaimConditions;
    fn is_allowlisted(self: @TContractState, address: ContractAddress) -> bool;
    fn is_allowlist_enabled(self: @TContractState) -> bool;
    fn claimed_by_wallet(self: @TContractState, wallet: ContractAddress) -> u256;
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ClaimConditions {
    pub start_time: u64,
    pub end_time: u64,
    pub price: u256,
    pub max_quantity_per_wallet: u256,
    pub payment_token: ContractAddress,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct TokenOwnership {
    pub addr: ContractAddress,
    pub start_timestamp: u64,
}
