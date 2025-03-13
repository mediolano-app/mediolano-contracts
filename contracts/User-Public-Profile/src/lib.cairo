#[starknet::contract]
mod SellerMarketplace {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::get_block_timestamp;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[starknet::interface]
    trait ISellerMarketplace<TContractState> {
        fn update_profile(ref self: TContractState, bio: felt252, website: felt252, social: felt252);
        fn create_collection(ref self: TContractState, name: felt252, description: felt252);
        fn list_item(ref self: TContractState, item_id: u32, price: u256, currency: Currency);
        fn record_activity(ref self: TContractState, activity_type: ActivityType, details: felt252);
        fn get_profile(self: @TContractState, user: ContractAddress) -> SellerProfile;
        fn get_collection_count(self: @TContractState, user: ContractAddress) -> u32;
        fn get_collection_details(self: @TContractState, user: ContractAddress, collection_id: u32) -> Collection;
        fn get_listed_items_count(self: @TContractState, user: ContractAddress) -> u32;
        fn get_listing_details(self: @TContractState, user: ContractAddress, listing_id: u32) -> ListedItem;
    }

    #[storage]
    struct Storage {
        seller_profile: Map::<ContractAddress, SellerProfile>,
        seller_collections: Map::<(ContractAddress, u32), Collection>,
        portfolio_items: Map::<(ContractAddress, u32), PortfolioItem>,
        listed_items: Map::<(ContractAddress, u32), ListedItem>,
        activity_log: Map::<(ContractAddress, u32), ActivityLog>,
        collection_count: Map::<ContractAddress, u32>,
        portfolio_count: Map::<ContractAddress, u32>,
        listing_count: Map::<ContractAddress, u32>,
        activity_count: Map::<ContractAddress, u32>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct SellerProfile {
        bio: felt252,
        website: felt252,
        social: felt252,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Collection {
        name: felt252,
        description: felt252,
        created_at: u64,
        total_items: u32,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct PortfolioItem {
        collection_id: u32,
        metadata: felt252,
        created_at: u64,
        status: ItemStatus,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct ListedItem {
        item_id: u32,
        price: u256,
        currency: Currency,
        created_at: u64,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct ActivityLog {
        activity_type: ActivityType,
        timestamp: u64,
        details: felt252,
    }

    #[derive(Drop, Serde, PartialEq, starknet::Store)]
    enum ItemStatus {
        Owned,
        Listed,
        Archived,
    }

    #[derive(Drop, Serde, starknet::Store)]
    enum Currency {
        ETH,
        STRK,
        USD,
    }

    #[derive(Drop, Serde, starknet::Store)]
    enum ActivityType {
        Sale,
        Transfer,
        Listing,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProfileUpdated: ProfileUpdated,
        CollectionAdded: CollectionAdded,
        ItemListed: ItemListed,
        ActivityRecorded: ActivityRecorded,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileUpdated {
        user: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CollectionAdded {
        user: ContractAddress,
        collection_id: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct ItemListed {
        user: ContractAddress,
        listing_id: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct ActivityRecorded {
        user: ContractAddress,
        activity_id: u32,
    }

    #[abi(embed_v0)]
    impl SellerMarketplace of ISellerMarketplace<ContractState> {
        fn update_profile(ref self: ContractState, bio: felt252, website: felt252, social: felt252) {
            let caller = get_caller_address();
            self.seller_profile.write(
                caller,
                SellerProfile { bio: bio, website: website, social: social }
            );
            self.emit(Event::ProfileUpdated(ProfileUpdated { user: caller }));
        }

        fn create_collection(ref self: ContractState, name: felt252, description: felt252) {
            let caller = get_caller_address();
            let current_id = self.collection_count.read(caller);
            let timestamp = get_block_timestamp();
            
            self.seller_collections.write(
                (caller, current_id),
                Collection { 
                    name: name, 
                    description: description, 
                    created_at: timestamp,
                    total_items: 0
                }
            );
            self.collection_count.write(caller, current_id + 1);
            self.emit(Event::CollectionAdded(CollectionAdded { user: caller, collection_id: current_id }));
        }

        fn list_item(ref self: ContractState, item_id: u32, price: u256, currency: Currency) {
            let caller = get_caller_address();
            let current_listings = self.listing_count.read(caller);
            let timestamp = get_block_timestamp();
            
            // Verify item ownership
            let item = self.portfolio_items.read((caller, item_id));
            assert(item.status == ItemStatus::Owned, 'Item must be owned');
            
            // Update item status
            self.portfolio_items.write(
                (caller, item_id),
                PortfolioItem { 
                    collection_id: item.collection_id, 
                    metadata: item.metadata, 
                    created_at: item.created_at, 
                    status: ItemStatus::Listed 
                }
            );
            
            // Create listing
            self.listed_items.write(
                (caller, current_listings),
                ListedItem { item_id: item_id, price: price, currency: currency, created_at: timestamp }
            );
            self.listing_count.write(caller, current_listings + 1);
            self.emit(Event::ItemListed(ItemListed { user: caller, listing_id: current_listings }));
        }

        fn record_activity(ref self: ContractState, activity_type: ActivityType, details: felt252) {
            let caller = get_caller_address();
            let current_activity = self.activity_count.read(caller);
            let timestamp = get_block_timestamp();
            
            self.activity_log.write(
                (caller, current_activity),
                ActivityLog { activity_type: activity_type, timestamp: timestamp, details: details }
            );
            self.activity_count.write(caller, current_activity + 1);
            self.emit(Event::ActivityRecorded(ActivityRecorded { user: caller, activity_id: current_activity }));
        }

        // View functions
        fn get_profile(self: @ContractState, user: ContractAddress) -> SellerProfile {
            self.seller_profile.read(user)
        }

        fn get_collection_count(self: @ContractState, user: ContractAddress) -> u32 {
            self.collection_count.read(user)
        }

        fn get_collection_details(self: @ContractState, user: ContractAddress, collection_id: u32) -> Collection {
            self.seller_collections.read((user, collection_id))
        }

        fn get_listed_items_count(self: @ContractState, user: ContractAddress) -> u32 {
            self.listing_count.read(user)
        }

        fn get_listing_details(self: @ContractState, user: ContractAddress, listing_id: u32) -> ListedItem {
            self.listed_items.read((user, listing_id))
        }
    }
}