use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC721Nft<TState> {
    fn mint(ref self: TState, to: ContractAddress, token_id: u256);
}

#[starknet::interface]
pub trait ERC721EscrowMixin<TState> {
    fn mint(ref self: TState, to: ContractAddress, token_id: u256);

    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;

    fn create_escrow(ref self: TState, amount: u256, recipient: ContractAddress) -> felt252;
    fn update_escrow(ref self: TState, id: felt252, fulfilled: bool);
    fn check_escrow_and_transfer(ref self: TState, id: felt252);
    fn cancel_escrow(ref self: TState, id: felt252);
    fn get_escrow_details(self: @TState, id: felt252) -> (u256, ContractAddress);
}

#[starknet::contract]
pub mod ERC721EscrowSmartTransaction {
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use ip_smart_transaction::escrow::ERC721EscrowComponent;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: ERC721EscrowComponent, storage: escrow, event: ERC721EscrowEvent);

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721EscrowMixinImpl = ERC721EscrowComponent::ERC721EscrowImpl<ContractState>;
    impl ERC721EscrowInternalImpl = ERC721EscrowComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        escrow: ERC721EscrowComponent::Storage,
    }

    #[event]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC721EscrowEvent: ERC721EscrowComponent::Event,
    }

    #[constructor]
    fn constructor() {
        self.erc721.initializer(name, symbol, base_uri);
    }

    #[abi(embed_v0)]
    impl IERC721NftImpl of super::IERC721Nft<ContractState> {
        self.erc721.mint(to, token_id);
    }
}