#[starknet::contract]
pub mod MIPListing {
    use contracts::errors::Errors;
    use contracts::interfaces::{
        IERC721Dispatcher, IERC721DispatcherTrait, IMarketplaceDispatcher,
        IMarketplaceDispatcherTrait, IMIPListing
    };
    use core::num::traits::Zero;
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address};
    use starknet::storage::{StoragePointerWriteAccess, StoragePointerReadAccess};


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        ip_asset_address: ContractAddress,
        ip_marketplace_address: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ListingCreated: ListingCreated,
        IPAssetUpdated: IPAssetUpdated,
        IPMarketplaceUpdated: IPMarketplaceUpdated,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct ListingCreated {
        #[key]
        token_id: u256,
        lister: ContractAddress,
        date: u64
    }

    #[derive(Drop, starknet::Event)]
    struct IPAssetUpdated {
        #[key]
        address: ContractAddress,
        date: u64
    }

    #[derive(Drop, starknet::Event)]
    struct IPMarketplaceUpdated {
        #[key]
        address: ContractAddress,
        date: u64
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        ip_asset: ContractAddress,
        ip_marketplace: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self.ip_asset_address.write(ip_asset);
        self.ip_marketplace_address.write(ip_marketplace);
    }

    #[abi(embed_v0)]
    impl IMIPListingImpl of IMIPListing<ContractState> {
        fn create_listing(
            ref self: ContractState,
            tokenId: u256,
            startTime: u256,
            secondsUntilEndTime: u256,
            quantityToList: u256,
            currencyToAccept: ContractAddress,
            buyoutPricePerToken: u256,
            tokenTypeOfListing: u256,
        ) {
            let caller = get_caller_address();
            let ip_asset_address = self.ip_asset_address.read();
            let marketplace_dispatcher = IMarketplaceDispatcher {
                contract_address: self.ip_marketplace_address.read()
            };
            let erc721_dispatcher = IERC721Dispatcher { contract_address: ip_asset_address };
            // check whether asset is IP asset
            assert(erc721_dispatcher.owner_of(tokenId) != Zero::zero(), Errors::INVALID_IP_ASSET);
            // check whether asset is caller asset
            assert(erc721_dispatcher.owner_of(tokenId) == caller, Errors::NOT_OWNER);
            // check whether contract has approval to move asset
            assert(
                erc721_dispatcher.is_approved_for_all(caller, get_contract_address()),
                Errors::NOT_APPROVED
            );
            marketplace_dispatcher
                .create_listing(
                    ip_asset_address,
                    tokenId,
                    startTime,
                    secondsUntilEndTime,
                    quantityToList,
                    currencyToAccept,
                    buyoutPricePerToken,
                    tokenTypeOfListing
                );
            self
                .emit(
                    ListingCreated {
                        token_id: tokenId, lister: caller, date: get_block_timestamp()
                    }
                )
        }

        fn update_ip_asset_address(ref self: ContractState, new_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.ip_asset_address.write(new_address);
            self.emit(IPAssetUpdated { address: new_address, date: get_block_timestamp() });
        }

        fn update_ip_marketplace_address(ref self: ContractState, new_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.ip_marketplace_address.write(new_address);
            self.emit(IPMarketplaceUpdated { address: new_address, date: get_block_timestamp() });
        }
    }
}
