use starknet::ContractAddress;

#[starknet::interface]
pub trait IMyNFT<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress) -> u256;
}

#[starknet::contract]
mod MyNFT {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::storage::StoragePointerReadAccess;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::{ContractAddress};

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
        token_count: u256,
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
    fn constructor(ref self: ContractState, owner: ContractAddress,) {
        let token_name: ByteArray = "MY NFT";
        let token_symbol: ByteArray = "MNFT";
        let base_uri: ByteArray = "uri/";
        self.erc721.initializer(token_name, token_symbol, base_uri);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl IMyNFTImpl of super::IMyNFT<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress) -> u256 {
            let mut token_id = self.token_count.read() + 1;
            self.ownable.assert_only_owner();
            assert(!self.erc721.exists(token_id), 'NFT with id already exists');
            self.erc721.mint(recipient, token_id);
            self.token_count.write(token_id);
            token_id
        }
    }
}
