use starknet::ContractAddress;

#[starknet::interface]
pub trait IAssetNFT<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256, amount: u256);
}

#[starknet::contract]
mod AssetNFT {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_uri: ByteArray) {
        // Initialize ERC-1155 with metadata URI
        self.erc1155.initializer(token_uri);
    }

    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155MixinImpl<ContractState>;

    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl AssetNFTImpl of super::IAssetNFT<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256, amount: u256) {
            // restrict to syndicate contract
            self.erc1155.mint_with_acceptance_check(recipient, token_id, amount, array![].span());
        }
    }
}
