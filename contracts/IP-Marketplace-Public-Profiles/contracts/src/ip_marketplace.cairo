use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct SellerPrivateInfo {
    // seller_id: felt252,
    pub seller_address: ContractAddress,
    pub phone_number: felt252,
    pub private_email: felt252,
}

#[derive(Clone, Drop, Serde, starknet::Store)]
pub struct SellerPublicProfile {
    pub seller_address: ContractAddress,
    // seller_id: felt252,
    pub seller_name: felt252,
    pub store_name: felt252,
    pub store_address: ByteArray,
    pub institutional_bio: ByteArray,
    pub business_email: felt252,
}

#[starknet::interface]
pub trait IPublicProfileMarketPlace<TContractState> {
    fn create_seller_profile(
        ref self: TContractState, 
        seller_name: felt252, 
        store_name: felt252, 
        store_address: ByteArray, 
        institutional_bio: ByteArray, 
        business_email: felt252,
        phone_number: felt252,
        private_email: felt252,
    ) -> bool;
    fn update_profile(
        ref self: TContractState, 
        seller_id: u64,
        seller_name: felt252, 
        store_name: felt252, 
        store_address: ByteArray, 
        institutional_bio: ByteArray, 
        business_email: felt252,
        phone_number: felt252,
        private_email: felt252,
    ) -> bool;
    fn get_seller_count(self: @TContractState) -> u64;
    fn get_all_sellers(self: @TContractState) -> Array<SellerPublicProfile>; //gets sellers public profile
    fn get_specific_seller(self: @TContractState, seller_id: u64) -> SellerPublicProfile;
    fn get_private_info(self: @TContractState, seller_id: u64) -> SellerPrivateInfo;
    fn add_social_link(ref self: TContractState, seller_id: u64, link: felt252, platform: felt252);
    fn get_social_links(self: @TContractState, seller_id: u64) -> Array<(felt252, felt252)>;
    // fn get_seller_name
}

#[starknet::contract]
pub mod PublicProfileMarketPlace {
    use starknet::{get_caller_address, ContractAddress};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Vec, MutableVecTrait, VecTrait};
    use super::{SellerPublicProfile, SellerPrivateInfo, IPublicProfileMarketPlace};
    use core::num::traits::Zero;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        sellers: Map::<u64, (SellerPublicProfile, SellerPrivateInfo)>, // Map Seller IDs to sellers
        social_links: Map::<u64, Vec<(felt252, felt252)>>, //Map::<seller_id, (platform, social_link)>
        seller_count: u64,
        registered_users: Vec<ContractAddress>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, seller_count: u64, owner: ContractAddress) {
        self.owner.write(owner);
        self.seller_count.write(seller_count);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ProfileCreated: ProfileCreated,
        ProfileUpdated: ProfileUpdated,
        SocialLinkAdded: SocialLinkAdded,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProfileCreated {
        seller_id: u64,
        seller_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProfileUpdated {
        seller_id: u64,
        seller_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct SocialLinkAdded {
        seller_id: u64,
        seller_address: ContractAddress,
        link: (felt252, felt252)        
    }

    #[abi(embed_v0)]
    impl PublicProfileMarketPlaceImpl of IPublicProfileMarketPlace<ContractState> {
        fn create_seller_profile(
            ref self: ContractState, 
            seller_name: felt252, 
            store_name: felt252, 
            store_address: ByteArray, 
            institutional_bio: ByteArray, 
            business_email: felt252,
            phone_number: felt252,
            private_email: felt252,
        ) -> bool {
            let seller_address = get_caller_address();
            assert(!seller_address.is_zero(), 'Error: Zero Address Caller');
            let mut existing_users = array![];
            for i in 0..self.registered_users.len() {
                existing_users.append(self.registered_users.at(i).read());
            };
            let mut i = 0;
            let mut this_seller_exists = false;
            while (i < self.registered_users.len().try_into().unwrap()) {
                let current_seller_address = existing_users.at(i);
                if current_seller_address == @seller_address {
                    this_seller_exists = true;
                    break;
                } else {
                    this_seller_exists = false;
                }
                i += 1;
            };

            if !this_seller_exists {
                let current_seller_count = self.seller_count.read();
                let seller_id = current_seller_count + 1;
                let seller_public_profile = SellerPublicProfile {
                    seller_address,
                    seller_name,
                    store_name,
                    store_address,
                    institutional_bio,
                    business_email
                };
    
                let seller_private_info = SellerPrivateInfo {
                    seller_address,
                    phone_number,
                    private_email
                };
                self.sellers.entry(seller_id).write((seller_public_profile, seller_private_info));
                self.seller_count.write(current_seller_count + 1);
                self.registered_users.append().write(seller_address);
                self.emit(
                    Event::ProfileCreated(
                        ProfileCreated {
                            seller_id,
                            seller_address
                        }
                    )
                );
                true
            } else {
                false
            }
        }
        fn update_profile(
            ref self: ContractState, 
            seller_id: u64,
            seller_name: felt252, 
            store_name: felt252, 
            store_address: ByteArray, 
            institutional_bio: ByteArray, 
            business_email: felt252,
            phone_number: felt252,
            private_email: felt252,
        ) -> bool {
            let seller_address = get_caller_address();
            assert(!seller_address.is_zero(), 'Error: Zero Address Caller');
            let mut existing_users = array![];
            for i in 0..self.registered_users.len() {
                existing_users.append(self.registered_users.at(i).read());
            };
            let mut i = 0;
            let mut this_seller_exists = false;
            while (i < self.registered_users.len().try_into().unwrap()) {
                let current_seller_address = existing_users.at(i);
                if current_seller_address == @seller_address {
                    this_seller_exists = true;
                    break;
                } else {
                    this_seller_exists = false
                }
                i += 1;
            };
            
            if this_seller_exists {  
                let (old_seller_public_profile, old_seller_private_info) = self.sellers.entry(seller_id).read();
                assert(seller_address == old_seller_public_profile.seller_address, 'Error: Unauthorized caller');
                let new_seller_public_profile = SellerPublicProfile {
                    seller_address: old_seller_public_profile.seller_address,
                    seller_name,
                    store_name,
                    store_address: store_address.clone(),
                    institutional_bio: institutional_bio.clone(),
                    business_email
                };
    
                let new_seller_private_info = SellerPrivateInfo {
                    seller_address: old_seller_private_info.seller_address,
                    phone_number,
                    private_email
                };
                self.sellers.entry(seller_id).write((new_seller_public_profile, new_seller_private_info));
                self.emit(
                    Event::ProfileUpdated(
                        ProfileUpdated {
                            seller_id,
                            seller_address
                        }
                    )
                );
                true
            } else {
                false
            }
        }
        fn get_seller_count(self: @ContractState) -> u64 {
            self.seller_count.read()
        }
        fn get_all_sellers(self: @ContractState) -> Array<SellerPublicProfile> { //gets sellers public profile
            let mut all_sellers: Array<SellerPublicProfile> = array![];
            let seller_count = self.seller_count.read();
            let mut i = 1;

            while i <= seller_count {
                let (current_seller, _) = self.sellers.entry(i).read();
                all_sellers.append(current_seller);
                i+=1;
            };

            all_sellers
        } 
            
        fn get_specific_seller(self: @ContractState, seller_id: u64) -> SellerPublicProfile {
            let (seller, _) = self.sellers.entry(seller_id).read();
            seller
        }
        fn get_private_info(self: @ContractState, seller_id: u64) -> SellerPrivateInfo {
            let (seller_public_profile, seller_private_info) = self.sellers.entry(seller_id).read();
            assert(get_caller_address() == seller_public_profile.seller_address, 'Error: Unauthorized Caller');
            seller_private_info
        }
        fn add_social_link(ref self: ContractState, seller_id: u64, link: felt252, platform: felt252) {
            let (seller, _) = self.sellers.entry(seller_id).read();
            assert(!get_caller_address().is_zero(), 'Error: Zero Address Caller');
            assert(get_caller_address() == seller.seller_address, 'Error: Unauthorized Caller');
            // let mut_links
            self.social_links.entry(seller_id).append().write((link, platform));
            self.emit(
                Event::SocialLinkAdded(
                    SocialLinkAdded {
                        seller_id,
                        seller_address: get_caller_address(),
                        link: (platform, link)
                    }
                )
            );
        }
        fn get_social_links(self: @ContractState, seller_id: u64) -> Array<(felt252, felt252)> {
            // let(seller, _) = self.sellers.entry(seller_id).read();
            assert(!get_caller_address().is_zero(), 'Error: Zero Address Caller');
            let mut social_links: Array<(felt252, felt252)> = array![];
            for i in 0..self.social_links.entry(seller_id).len() {
                social_links.append(self.social_links.entry(seller_id).at(i).read());
            };
            social_links
        }
    }
}
