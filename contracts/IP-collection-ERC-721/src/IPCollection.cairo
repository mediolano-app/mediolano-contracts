// SPDX-License-Identifier: MIT
#[starknet::contract]
mod IPCollection {
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::extensions::ERC721EnumerableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721EnumerableImpl = ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721_enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        token_id_count: u256,
        community_count: u256,
        community_names: LegacyMap<u256, ByteArray>,
        community_descriptions: LegacyMap<u256, ByteArray>,
        community_entry_fees: LegacyMap<u256, u256>,
        community_fee_tokens: LegacyMap<u256, ContractAddress>,
        community_fee_recipients: LegacyMap<u256, ContractAddress>,
        community_ip_nft_addresses: LegacyMap<u256, ContractAddress>,
        community_ip_nft_token_ids: LegacyMap<u256, u256>,
        token_community: LegacyMap<u256, u256>,
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
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[external(v0)]
    impl IIPCollection of super::IIPCollection<ContractState> {
        fn mint(ref self: ContractState, community_id: u256) -> u256 {
            let caller = get_caller_address();
            assert(caller.is_non_zero(), 'Caller is zero address');
            assert(community_id <= self.community_count.read(), 'Community does not exist');

            let entry_fee = self.community_entry_fees.read(community_id);
            let fee_token = self.community_fee_tokens.read(community_id);
            let fee_recipient = self.community_fee_recipients.read(community_id);

            let erc20 = IERC20Dispatcher { contract_address: fee_token };
            let success = erc20.transfer_from(caller, fee_recipient, entry_fee);
            assert(success, 'Fee transfer failed');

            let token_id = self.token_id_count.read() + 1;
            self.token_id_count.write(token_id);

            self.erc721.mint(caller, token_id);
            self.token_community.write(token_id, community_id);

            token_id
        }

        fn burn(ref self: ContractState, token_id: u256) {
            self.ownable.assert_only_owner();
            self.erc721.burn(token_id);
        }

        fn list_user_tokens(self: @ContractState, owner: ContractAddress) -> Array<u256> {
            let balance = self.erc721.balance_of(owner);
            let mut token_ids: Array<u256> = array![];
            let mut i = 0;
            loop {
                if i >= balance {
                    break;
                }
                let token_id = self.erc721_enumerable.token_of_owner_by_index(owner, i);
                token_ids.append(token_id);
                i += 1;
            };
            token_ids
        }

        fn transfer(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self.erc721.transfer(to, token_id);
        }

        fn create_community(
            ref self: ContractState,
            name: ByteArray,
            description: ByteArray,
            entry_fee: u256,
            fee_token: ContractAddress,
            fee_recipient: ContractAddress,
            ip_nft_address: ContractAddress,
            ip_nft_token_id: u256,
        ) -> u256 {
            let caller = get_caller_address();
            assert(caller.is_non_zero(), 'Caller is zero address');

            let community_id = self.community_count.read() + 1;
            self.community_count.write(community_id);

            self.community_names.write(community_id, name);
            self.community_descriptions.write(community_id, description);
            self.community_entry_fees.write(community_id, entry_fee);
            self.community_fee_tokens.write(community_id, fee_token);
            self.community_fee_recipients.write(community_id, fee_recipient);
            self.community_ip_nft_addresses.write(community_id, ip_nft_address);
            self.community_ip_nft_token_ids.write(community_id, ip_nft_token_id);

            community_id
        }

        fn is_member(self: @ContractState, user: ContractAddress, community_id: u256) -> bool {
            let balance = self.erc721.balance_of(user);
            let mut i = 0;
            loop {
                if i >= balance {
                    break false;
                }
                let token_id = self.erc721_enumerable.token_of_owner_by_index(user, i);
                if self.token_community.read(token_id) == community_id {
                    break true;
                }
                i += 1;
            }
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.erc721.initializer("IP CLUB", "IPC", "");
    }
}

#[starknet::interface]
trait IIPCollection<TContractState> {
    fn mint(ref self: TContractState, community_id: u256) -> u256;
    fn burn(ref self: TContractState, token_id: u256);
    fn list_user_tokens(self: @TContractState, owner: ContractAddress) -> Array<u256>;
    fn transfer(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn create_community(
        ref self: TContractState,
        name: ByteArray,
        description: ByteArray,
        entry_fee: u256,
        fee_token: ContractAddress,
        fee_recipient: ContractAddress,
        ip_nft_address: ContractAddress,
        ip_nft_token_id: u256,
    ) -> u256;
    fn is_member(self: @TContractState, user: ContractAddress, community_id: u256) -> bool;
}

#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer_from(
        ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    ) -> bool;
}