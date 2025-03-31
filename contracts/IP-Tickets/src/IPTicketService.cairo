#[starknet::contract]
pub mod IPTicketService {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use core::traits::Into;
    use core::array::ArrayTrait;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use ip_ticket::interface::IIPTicketService;
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};

    #[storage]
    struct Storage {
        name: ByteArray,
        symbol: ByteArray,
        payment_token: ContractAddress,
        next_ip_asset_id: u256,
        next_token_id: u256,
        total_supply: u256,
        ip_assets: Map<u256, IPAsset>,
        token_to_ip_asset: Map<u256, u256>,
        user_ip_asset_balance: Map<(ContractAddress, u256), u256>,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        IPAssetCreated: IPAssetCreated,
        TicketMinted: TicketMinted,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPAssetCreated {
        pub ip_asset_id: u256,
        pub owner: ContractAddress,
        pub price: u256,
        pub max_supply: u256,
        pub expiration: u256,
        pub royalty_percentage: u256,
        pub metadata_uri: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TicketMinted {
        pub token_id: u256,
        pub ip_asset_id: u256,
        pub owner: ContractAddress,
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct IPAsset {
        pub owner: ContractAddress,
        pub price: u256,
        pub max_supply: u256,
        pub tickets_minted: u256,
        pub expiration: u256,
        pub royalty_percentage: u256,
        pub metadata_uri: felt252,
    }

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);


    // External
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;

    // Internal
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        payment_token: ContractAddress,
        token_uri: ByteArray,
    ) {
        self.name.write(name.clone());
        self.symbol.write(symbol.clone());
        self.payment_token.write(payment_token);
        self.next_ip_asset_id.write(1);
        self.next_token_id.write(1);
        self.erc721.initializer(name, symbol, token_uri);
    }

    #[abi(embed_v0)]
    pub impl IPTicketImpl of IIPTicketService<ContractState> {
        fn create_ip_asset(
            ref self: ContractState,
            price: u256,
            max_supply: u256,
            expiration: u256,
            royalty_percentage: u256,
            metadata_uri: felt252,
        ) -> u256 {
            let ip_asset_id = self.next_ip_asset_id.read();
            self.next_ip_asset_id.write(ip_asset_id + 1);
            let caller = get_caller_address();

            self
                .ip_assets
                .write(
                    ip_asset_id,
                    IPAsset {
                        owner: caller,
                        price,
                        max_supply,
                        tickets_minted: 0,
                        expiration,
                        royalty_percentage,
                        metadata_uri,
                    },
                );

            self
                .emit(
                    Event::IPAssetCreated(
                        IPAssetCreated {
                            ip_asset_id,
                            owner: caller,
                            price,
                            max_supply,
                            expiration,
                            royalty_percentage,
                            metadata_uri,
                        },
                    ),
                );
            ip_asset_id
        }

        fn mint_ticket(ref self: ContractState, ip_asset_id: u256) {
            let mut ip_asset = self.ip_assets.read(ip_asset_id);
            assert(ip_asset.tickets_minted < ip_asset.max_supply, 'Max supply reached');

            let caller = get_caller_address();
            let payment_token = IERC20Dispatcher { contract_address: self.payment_token.read() };
            payment_token.transfer_from(caller, ip_asset.owner, ip_asset.price);

            let token_id = self.next_token_id.read();
            self.next_token_id.write(token_id + 1);

            self.erc721.mint(caller, token_id);

            self.token_to_ip_asset.write(token_id, ip_asset_id);
            self
                .user_ip_asset_balance
                .write(
                    (caller, ip_asset_id),
                    self.user_ip_asset_balance.read((caller, ip_asset_id)) + 1,
                );
            self.total_supply.write(self.total_supply.read() + 1);
            ip_asset.tickets_minted += 1;
            self.ip_assets.write(ip_asset_id, ip_asset);

            self.emit(Event::TicketMinted(TicketMinted { token_id, ip_asset_id, owner: caller }));
        }

        fn has_valid_ticket(
            self: @ContractState, user: ContractAddress, ip_asset_id: u256,
        ) -> bool {
            let ip_asset = self.ip_assets.read(ip_asset_id);
            let current_time: u256 = get_block_timestamp().into();
            if current_time >= ip_asset.expiration {
                return false;
            }
            self.user_ip_asset_balance.read((user, ip_asset_id)) > 0
        }

        fn royaltyInfo(
            self: @ContractState, token_id: u256, sale_price: u256,
        ) -> (ContractAddress, u256) {
            let ip_asset_id = self.token_to_ip_asset.read(token_id);
            let ip_asset = self.ip_assets.read(ip_asset_id);
            let royalty_amount = (sale_price * ip_asset.royalty_percentage) / 10000; // Basis points
            (ip_asset.owner, royalty_amount)
        }
    }
}
