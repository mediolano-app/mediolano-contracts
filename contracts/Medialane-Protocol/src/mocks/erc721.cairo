use starknet::ContractAddress;

// https://wizard.openzeppelin.com/cairo#erc721
#[starknet::contract]
pub mod MockERC721 {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use super::*;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // External
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer("MyNFT", "MT", "");
        self.ownable.initializer(owner);
    }


    #[abi(embed_v0)]
    impl MockERC721Impl of super::IMockERC721<ContractState> {
        fn mint_token(ref self: ContractState, recepient: ContractAddress, token_id: u256) {
            self.ownable.assert_only_owner();
            self.erc721.mint(recepient, token_id);
        }

        fn approve_token(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self.erc721.approve(to, token_id);
        }

        fn get_owner(ref self: ContractState, token_id: u256) -> ContractAddress {
            self.erc721.owner_of(token_id)
        }
    }
}

#[starknet::interface]
pub trait IMockERC721<TContractState> {
    fn mint_token(ref self: TContractState, recepient: ContractAddress, token_id: u256);
    fn approve_token(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn get_owner(ref self: TContractState, token_id: u256) -> ContractAddress;
}
