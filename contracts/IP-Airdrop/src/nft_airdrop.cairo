#[starknet::contract]
pub mod NFTAirdrop {
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_merkle_tree::merkle_proof;
    use ip_nft_airdrop::interface::INFTAirdrop;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        whitelists: Vec<(ContractAddress, u32)>,
        // Merkle root
        merkle_root: felt252,
        // Next token ID
        next_token_id: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        merkle_root: felt252,
    ) {
        self.ownable.initializer(owner);
        self.erc721.initializer(name, symbol, base_uri);
        self.merkle_root.write(merkle_root);
        self.next_token_id.write(1);
    }

    #[abi(embed_v0)]
    impl NFTAirdropImpl of INFTAirdrop<ContractState> {
        fn whitelist(ref self: ContractState, to: ContractAddress, amount: u32) {
            self.ownable.assert_only_owner();
            let mut whitelist_found = false;
            for i in 0..self.whitelists.len() {
                let whitelist = self.whitelists.at(i);
                let (whitelist_to, _) = whitelist.read();
                if to == whitelist_to {
                    whitelist.write((to, amount));
                    whitelist_found = true;
                }
            };
            if !whitelist_found {
                self.whitelists.append().write((to, amount));
            }
        }

        fn whitelist_balance_of(self: @ContractState, to: ContractAddress) -> u32 {
            let mut i = 0;
            loop {
                if i == self.whitelists.len() {
                    break 0;
                }
                let (whitelist_to, whitelist_amount) = self.whitelists.at(i).read();
                if to == whitelist_to {
                    break whitelist_amount;
                }
                i += 1;
            }
        }

        fn airdrop(ref self: ContractState) {
            self.ownable.assert_only_owner();
            for i in 0..self.whitelists.len() {
                let whitelist = self.whitelists.at(i);
                let (to, amount) = whitelist.read();
                if amount > 0 {
                    self.batch_mint(to, amount);
                    whitelist.write((to, 0));
                }
            };
        }

        fn claim_with_proof(ref self: ContractState, proof: Span<felt252>, amount: u32) {
            let to = get_caller_address();
            let root = self.merkle_root.read();
            let leaf = self.leaf_hash(to, amount);
            assert(merkle_proof::verify_pedersen(proof, root, leaf), 'INVALID_PROOF');
            self.batch_mint(to, amount);
        }
    }

    #[generate_trait]
    impl InternalTraitImpl of InternalTrait {
        fn batch_mint(ref self: ContractState, to: ContractAddress, amount: u32) {
            let token_id = self.next_token_id.read();
            for i in 0..amount {
                self.erc721.mint(to, token_id + i.into());
            };
            self.next_token_id.write(token_id + amount.into());
        }

        fn leaf_hash(self: @ContractState, to: ContractAddress, amount: u32) -> felt252 {
            let hash = PedersenTrait::new(0)
                .update_with(to)
                .update_with(amount)
                .update(2)
                .finalize();
            PedersenTrait::new(0).update(hash).finalize()
        }
    }
}
