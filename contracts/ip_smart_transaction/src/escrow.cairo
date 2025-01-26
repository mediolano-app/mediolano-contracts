#[starknet::component]
mod ERC721EscrowComponent {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    use openzeppelin_token::erc721::ERC721Component::InternalImpl as ERC721InternalImpl;
    use openzeppelin_token::erc721::ERC721Component::ERC721Impl;
    use openzeppelin_token::erc721::ERC721Component;

    use ip_smart_transaction::interface::ERC721Escrow;

    #[storage]
    struct Storage {
        escrows: Map<ContractAddress, felt252>
    }

    #[embeddable_as(ERC721EscrowImpl)]
    impl ERC721Escrow<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>
    > of ERC721Escrow<ComponentState<TContractState>> {
        fn create_escrow(ref self: TState, amount: u256, recipient: ContractAddress) -> felt252;

        fn update_escrow(ref self: TState, id: felt252, fulfilled: bool);

        fn check_escrow_and_transfer(ref self: TState, id: felt252);

        fn cancel_escrow(ref self: TState, id: felt252);

        fn get_escrow_details(self: @TState, id: felt252) -> (u256, ContractAddress);
    }
}