#[starknet::contract]
pub mod IPSponsorship {
    use ip_sponsorship::interface::IIPSponsorship;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use ip_sponsorship::errors::IPSponsorErrors;

    // Struct to hold intellectual property details
    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct IntellectualProperty {
        owner: ContractAddress,
        metadata: felt252, // IPFS hash or metadata reference
        license_terms: felt252, // License terms reference
        active: bool,
        created_at: u64,
    }

    // Struct to hold sponsorship offer details
    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct SponsorshipOffer {
        ip_id: felt252,
        min_price: u256,
        max_price: u256,
        duration: u64, // Duration in seconds
        author: ContractAddress,
        active: bool,
        specific_sponsor: Option<ContractAddress>, // If Some, only this address can sponsor
        created_at: u64,
    }

    // Struct to hold sponsorship bid information
    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct SponsorshipBid {
        sponsor: ContractAddress,
        amount: u256,
        timestamp: u64,
        accepted: bool,
    }

    // Struct to hold license information
    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct License {
        ip_id: felt252,
        sponsor: ContractAddress,
        original_author: ContractAddress,
        amount_paid: u256,
        issue_date: u64,
        expiry_date: u64,
        active: bool,
        transferable: bool,
    }

    #[storage]
    struct Storage {
        // Core mappings
        intellectual_properties: Map<felt252, IntellectualProperty>,
        sponsorship_offers: Map<felt252, SponsorshipOffer>,
        licenses: Map<felt252, License>,
        
        // Bid tracking
        offer_bids: Map<felt252, Vec<SponsorshipBid>>,
        
        // User mappings for efficient queries
        user_ips: Map<ContractAddress, Vec<felt252>>,
        user_licenses: Map<ContractAddress, Vec<felt252>>,
        user_offers: Map<ContractAddress, Vec<felt252>>,
        
        // Active offers list for marketplace
        active_offers: Vec<felt252>,
        
        // Contract admin
        admin: ContractAddress,
        
        // Counters for ID generation
        next_ip_id: felt252,
        next_offer_id: felt252,
        next_license_id: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        IPRegistered: IPRegistered,
        IPMetadataUpdated: IPMetadataUpdated,
        SponsorshipOfferCreated: SponsorshipOfferCreated,
        SponsorshipOfferCancelled: SponsorshipOfferCancelled,
        SponsorshipOfferUpdated: SponsorshipOfferUpdated,
        SponsorshipBidPlaced: SponsorshipBidPlaced,
        SponsorshipAccepted: SponsorshipAccepted,
        SponsorshipRejected: SponsorshipRejected,
        LicenseTransferred: LicenseTransferred,
        LicenseRevoked: LicenseRevoked,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPRegistered {
        pub ip_id: felt252,
        pub owner: ContractAddress,
        pub metadata: felt252,
        pub license_terms: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IPMetadataUpdated {
        pub ip_id: felt252,
        pub new_metadata: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipOfferCreated {
        pub offer_id: felt252,
        pub ip_id: felt252,
        pub author: ContractAddress,
        pub min_price: u256,
        pub max_price: u256,
        pub duration: u64,
        pub specific_sponsor: Option<ContractAddress>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipOfferCancelled {
        pub offer_id: felt252,
        pub author: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipOfferUpdated {
        pub offer_id: felt252,
        pub new_min_price: u256,
        pub new_max_price: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipBidPlaced {
        pub offer_id: felt252,
        pub sponsor: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipAccepted {
        pub offer_id: felt252,
        pub sponsor: ContractAddress,
        pub license_id: felt252,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipRejected {
        pub offer_id: felt252,
        pub sponsor: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LicenseTransferred {
        pub license_id: felt252,
        pub from: ContractAddress,
        pub to: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LicenseRevoked {
        pub license_id: felt252,
        pub revoker: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        self.next_ip_id.write(1);
        self.next_offer_id.write(1);
        self.next_license_id.write(1);
    }

    #[abi(embed_v0)]
    impl IPSponsorshipImpl of IIPSponsorship<ContractState> {
        // Register a new intellectual property
        fn register_ip(ref self: ContractState, ip_metadata: felt252, license_terms: felt252) -> felt252 {
            let caller = get_caller_address();
            let ip_id = self.next_ip_id.read();
            let current_time = get_block_timestamp();

            let ip = IntellectualProperty {
                owner: caller,
                metadata: ip_metadata,
                license_terms: license_terms,
                active: true,
                created_at: current_time,
            };

            self.intellectual_properties.entry(ip_id).write(ip);
            self.user_ips.entry(caller).push(ip_id);
            self.next_ip_id.write(ip_id + 1);

            self.emit(Event::IPRegistered(IPRegistered {
                ip_id: ip_id,
                owner: caller,
                metadata: ip_metadata,
                license_terms: license_terms,
            }));

            ip_id
        }

        // Update IP metadata (only by owner)
        fn update_ip_metadata(ref self: ContractState, ip_id: felt252, new_metadata: felt252) {
            let caller = get_caller_address();
            let mut ip = self.intellectual_properties.entry(ip_id).read();
            
            assert(ip.owner == caller, IPSponsorErrors::ONLY_IP_OWNER_CAN_UPDATE);
            assert(ip.active, IPSponsorErrors::IP_NOT_ACTIVE);

            ip.metadata = new_metadata;
            self.intellectual_properties.entry(ip_id).write(ip);

            self.emit(Event::IPMetadataUpdated(IPMetadataUpdated {
                ip_id: ip_id,
                new_metadata: new_metadata,
            }));
        }

        // Deactivate IP (only by owner or admin)
        fn deactivate_ip(ref self: ContractState, ip_id: felt252) {
            let caller = get_caller_address();
            let mut ip = self.intellectual_properties.entry(ip_id).read();
            
            assert(
                ip.owner == caller || self.admin.read() == caller,
                IPSponsorErrors::ONLY_OWNER_OR_ADMIN
            );
            assert(ip.active, IPSponsorErrors::IP_ALREADY_INACTIVE);

            ip.active = false;
            self.intellectual_properties.entry(ip_id).write(ip);

            // Cancel all active offers for this IP
            self._cancel_ip_offers(ip_id);
        }

        // Create a sponsorship offer
        fn create_sponsorship_offer(
            ref self: ContractState,
            ip_id: felt252,
            min_price: u256,
            max_price: u256,
            duration: u64,
            specific_sponsor: Option<ContractAddress>
        ) -> felt252 {
            let caller = get_caller_address();
            let ip = self.intellectual_properties.entry(ip_id).read();
            
            assert(ip.owner == caller, IPSponsorErrors::ONLY_IP_OWNER_CAN_CREATE_OFFERS);
            assert(ip.active, IPSponsorErrors::IP_NOT_ACTIVE);
            assert(min_price <= max_price, IPSponsorErrors::INVALID_PRICE_RANGE);
            assert(duration > 0, IPSponsorErrors::DURATION_MUST_BE_POSITIVE);

            let offer_id = self.next_offer_id.read();
            let current_time = get_block_timestamp();

            let offer = SponsorshipOffer {
                ip_id: ip_id,
                min_price: min_price,
                max_price: max_price,
                duration: duration,
                author: caller,
                active: true,
                specific_sponsor: specific_sponsor,
                created_at: current_time,
            };

            self.sponsorship_offers.entry(offer_id).write(offer);
            self.user_offers.entry(caller).push(offer_id);
            self.active_offers.push(offer_id);
            self.next_offer_id.write(offer_id + 1);

            self.emit(Event::SponsorshipOfferCreated(SponsorshipOfferCreated {
                offer_id: offer_id,
                ip_id: ip_id,
                author: caller,
                min_price: min_price,
                max_price: max_price,
                duration: duration,
                specific_sponsor: specific_sponsor,
            }));

            offer_id
        }

        // Cancel a sponsorship offer
        fn cancel_sponsorship_offer(ref self: ContractState, offer_id: felt252) {
            let caller = get_caller_address();
            let mut offer = self.sponsorship_offers.entry(offer_id).read();
            
            assert(offer.author == caller, IPSponsorErrors::ONLY_OFFER_AUTHOR_CAN_CANCEL);
            assert(offer.active, IPSponsorErrors::OFFER_NOT_ACTIVE);

            offer.active = false;
            self.sponsorship_offers.entry(offer_id).write(offer);

            // Remove from active offers list
            self._remove_from_active_offers(offer_id);

            self.emit(Event::SponsorshipOfferCancelled(SponsorshipOfferCancelled {
                offer_id: offer_id,
                author: caller,
            }));
        }

        // Update sponsorship offer prices
        fn update_sponsorship_offer(ref self: ContractState, offer_id: felt252, new_min_price: u256, new_max_price: u256) {
            let caller = get_caller_address();
            let mut offer = self.sponsorship_offers.entry(offer_id).read();
            
            assert(offer.author == caller, IPSponsorErrors::ONLY_OFFER_AUTHOR_CAN_UPDATE);
            assert(offer.active, IPSponsorErrors::OFFER_NOT_ACTIVE);
            assert(new_min_price <= new_max_price, IPSponsorErrors::INVALID_PRICE_RANGE);

            offer.min_price = new_min_price;
            offer.max_price = new_max_price;
            self.sponsorship_offers.entry(offer_id).write(offer);

            self.emit(Event::SponsorshipOfferUpdated(SponsorshipOfferUpdated {
                offer_id: offer_id,
                new_min_price: new_min_price,
                new_max_price: new_max_price,
            }));
        }

        // Place a sponsorship bid
        fn sponsor_ip(ref self: ContractState, offer_id: felt252, bid_amount: u256) {
            let caller = get_caller_address();
            let offer = self.sponsorship_offers.entry(offer_id).read();
            
            assert(offer.active, IPSponsorErrors::OFFER_NOT_ACTIVE);
            assert(bid_amount >= offer.min_price, IPSponsorErrors::BID_BELOW_MINIMUM);
            assert(bid_amount <= offer.max_price, IPSponsorErrors::BID_ABOVE_MAXIMUM);
            
            // Check if offer is restricted to specific sponsor
            if let Option::Some(specific_sponsor) = offer.specific_sponsor {
                assert(caller == specific_sponsor, IPSponsorErrors::NOT_AUTHORIZED_TO_SPONSOR);
            }

            let bid = SponsorshipBid {
                sponsor: caller,
                amount: bid_amount,
                timestamp: get_block_timestamp(),
                accepted: false,
            };

            self.offer_bids.entry(offer_id).push(bid);

            self.emit(Event::SponsorshipBidPlaced(SponsorshipBidPlaced {
                offer_id: offer_id,
                sponsor: caller,
                amount: bid_amount,
            }));
        }

        // Accept a sponsorship bid (by IP author)
        fn accept_sponsorship(ref self: ContractState, offer_id: felt252, sponsor: ContractAddress) {
            let caller = get_caller_address();
            let mut offer = self.sponsorship_offers.entry(offer_id).read();
            
            assert(offer.author == caller, IPSponsorErrors::ONLY_OFFER_AUTHOR_CAN_ACCEPT);
            assert(offer.active, IPSponsorErrors::OFFER_NOT_ACTIVE);

            let mut bids = self.offer_bids.entry(offer_id);
            let mut bid_found = false;
            let mut accepted_amount: u256 = 0;
            let mut accepted_bid_index: u64 = 0;
            
            let bids_len = bids.len();
            let mut i = 0;
            loop {
                if i >= bids_len {
                    break;
                }
                let bid = bids.at(i).read();
                if bid.sponsor == sponsor && !bid.accepted {
                    accepted_amount = bid.amount;
                    bid_found = true;
                    accepted_bid_index = i;
                    break;
                }
                i = i + 1;
            };

            assert(bid_found, IPSponsorErrors::NO_VALID_BID_FOUND);
            
            // Update the accepted bid in place
            let mut accepted_bid = bids.at(accepted_bid_index).read();
            accepted_bid.accepted = true;
            
            let mut new_bids: Array<SponsorshipBid> = array![];
            let mut j = 0;
            loop {
                if j >= bids_len {
                    break;
                }
                if j == accepted_bid_index {
                    new_bids.append(accepted_bid);
                } else {
                    new_bids.append(bids.at(j).read());
                }
                j = j + 1;
            };
            
            // Clear and repopulate the bids vector
            let mut current_len = bids.len();
            while current_len > 0 {
                if let Option::Some(_) = bids.pop() {}
                current_len -= 1;
            }
            
            let mut k = 0;
            loop {
                if k >= new_bids.len() {
                    break;
                }
                bids.push(*new_bids.at(k));
                k = k + 1;
            };

            // Create license
            let license_id = self.next_license_id.read();
            let current_time = get_block_timestamp();
            
            let license = License {
                ip_id: offer.ip_id,
                sponsor: sponsor,
                original_author: offer.author,
                amount_paid: accepted_amount,
                issue_date: current_time,
                expiry_date: current_time + offer.duration,
                active: true,
                transferable: true,
            };

            self.licenses.entry(license_id).write(license);
            self.user_licenses.entry(sponsor).push(license_id);
            self.next_license_id.write(license_id + 1);

            // Deactivate the offer
            offer.active = false;
            self.sponsorship_offers.entry(offer_id).write(offer);
            self._remove_from_active_offers(offer_id);

            self.emit(Event::SponsorshipAccepted(SponsorshipAccepted {
                offer_id: offer_id,
                sponsor: sponsor,
                license_id: license_id,
                amount: accepted_amount,
            }));
        }

        // Reject a sponsorship bid
        fn reject_sponsorship(ref self: ContractState, offer_id: felt252, sponsor: ContractAddress) {
            let caller = get_caller_address();
            let offer = self.sponsorship_offers.entry(offer_id).read();
            
            assert(offer.author == caller, IPSponsorErrors::ONLY_OFFER_AUTHOR_CAN_REJECT);
            assert(offer.active, IPSponsorErrors::OFFER_NOT_ACTIVE);

            self.emit(Event::SponsorshipRejected(SponsorshipRejected {
                offer_id: offer_id,
                sponsor: sponsor,
            }));
        }

        // Transfer a license to another address
        fn transfer_license(ref self: ContractState, license_id: felt252, new_owner: ContractAddress) {
            let caller = get_caller_address();
            let mut license = self.licenses.entry(license_id).read();
            
            assert(license.sponsor == caller, IPSponsorErrors::ONLY_LICENSE_OWNER_CAN_TRANSFER);
            assert(license.active, IPSponsorErrors::LICENSE_NOT_ACTIVE);
            assert(license.transferable, IPSponsorErrors::LICENSE_NOT_TRANSFERABLE);
            assert(get_block_timestamp() < license.expiry_date, IPSponsorErrors::LICENSE_HAS_EXPIRED);

            let old_owner = license.sponsor;
            license.sponsor = new_owner;
            self.licenses.entry(license_id).write(license);

            // Update user mappings
            self.user_licenses.entry(new_owner).push(license_id);
            
            // Remove license from old owner's list
            self._remove_license_from_user(old_owner, license_id);

            self.emit(Event::LicenseTransferred(LicenseTransferred {
                license_id: license_id,
                from: old_owner,
                to: new_owner,
            }));
        }

        fn revoke_license(ref self: ContractState, license_id: felt252) {
            let caller = get_caller_address();
            let mut license = self.licenses.entry(license_id).read();
            
            assert(
                license.original_author == caller || self.admin.read() == caller,
                IPSponsorErrors::NOT_AUTHORIZED_TO_REVOKE
            );
            assert(license.active, IPSponsorErrors::LICENSE_NOT_ACTIVE);

            license.active = false;
            self.licenses.entry(license_id).write(license);

            self.emit(Event::LicenseRevoked(LicenseRevoked {
                license_id: license_id,
                revoker: caller,
            }));
        }

        // View Functions

        fn get_ip_details(self: @ContractState, ip_id: felt252) -> (ContractAddress, felt252, felt252, bool) {
            let ip = self.intellectual_properties.entry(ip_id).read();
            (ip.owner, ip.metadata, ip.license_terms, ip.active)
        }

        fn get_sponsorship_offer(self: @ContractState, offer_id: felt252) -> (felt252, u256, u256, u64, ContractAddress, bool, Option<ContractAddress>) {
            let offer = self.sponsorship_offers.entry(offer_id).read();
            (offer.ip_id, offer.min_price, offer.max_price, offer.duration, offer.author, offer.active, offer.specific_sponsor)
        }

        fn get_user_ips(self: @ContractState, owner: ContractAddress) -> Array<felt252> {
            let user_ips = self.user_ips.entry(owner);
            let mut ip_ids: Array<felt252> = array![];
            let len = user_ips.len();
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                ip_ids.append(user_ips.at(i).read());
                i = i + 1;
            };
            ip_ids
        }

        fn get_user_licenses(self: @ContractState, owner: ContractAddress) -> Array<felt252> {
            let user_licenses = self.user_licenses.entry(owner);
            let mut license_ids: Array<felt252> = array![];
            let len = user_licenses.len();
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                license_ids.append(user_licenses.at(i).read());
                i = i + 1;
            };
            license_ids
        }

        fn get_active_offers(self: @ContractState) -> Array<felt252> {
            let mut offer_ids: Array<felt252> = array![];
            let len = self.active_offers.len();
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                let offer_id = self.active_offers.at(i).read();
                let offer = self.sponsorship_offers.entry(offer_id).read();
                if offer.active {
                    offer_ids.append(offer_id);
                }
                i = i + 1;
            };
            offer_ids
        }

        fn get_sponsorship_bids(self: @ContractState, offer_id: felt252) -> Array<(ContractAddress, u256)> {
            let bids = self.offer_bids.entry(offer_id);
            let mut bid_info: Array<(ContractAddress, u256)> = array![];
            let len = bids.len();
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                let bid = bids.at(i).read();
                bid_info.append((bid.sponsor, bid.amount));
                i = i + 1;
            };
            bid_info
        }

        fn is_license_valid(self: @ContractState, license_id: felt252) -> bool {
            let license = self.licenses.entry(license_id).read();
            license.active && get_block_timestamp() < license.expiry_date
        }

        fn get_license_details(self: @ContractState, license_id: felt252) -> (felt252, ContractAddress, ContractAddress, u256, u64, u64, bool, bool) {
            let license = self.licenses.entry(license_id).read();
            (
                license.ip_id,
                license.sponsor,
                license.original_author,
                license.amount_paid,
                license.issue_date,
                license.expiry_date,
                license.active,
                license.transferable
            )
        }

        fn get_user_offers(self: @ContractState, author: ContractAddress) -> Array<felt252> {
            let user_offers = self.user_offers.entry(author);
            let mut offer_ids: Array<felt252> = array![];
            let len = user_offers.len();
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                offer_ids.append(user_offers.at(i).read());
                i = i + 1;
            };
            offer_ids
        }
    }

    #[generate_trait]
    impl HelperImpl of HelperTrait {
        fn _remove_license_from_user(ref self: ContractState, user: ContractAddress, license_id: felt252) {
            let mut user_licenses = self.user_licenses.entry(user);
            let mut temp_licenses: Array<felt252> = array![];
            let len = user_licenses.len();
            
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                let current_license = user_licenses.at(i).read();
                if current_license != license_id {
                    temp_licenses.append(current_license);
                }
                i = i + 1;
            };

            // Clear and repopulate
            let mut current_len = user_licenses.len();
            while current_len > 0 {
                if let Option::Some(_) = user_licenses.pop() {}
                current_len -= 1;
            }

            let mut j = 0;
            loop {
                if j >= temp_licenses.len() {
                    break;
                }
                user_licenses.push(*temp_licenses.at(j));
                j = j + 1;
            };
        }

        fn _cancel_ip_offers(ref self: ContractState, ip_id: felt252) {
            let active_offers_len = self.active_offers.len();
            let mut i = 0;
            loop {
                if i >= active_offers_len {
                    break;
                }
                let offer_id = self.active_offers.at(i).read();
                let mut offer = self.sponsorship_offers.entry(offer_id).read();
                
                if offer.ip_id == ip_id && offer.active {
                    offer.active = false;
                    self.sponsorship_offers.entry(offer_id).write(offer);
                }
                i = i + 1;
            };
        }

        fn _remove_from_active_offers(ref self: ContractState, offer_id: felt252) {
            let mut active_offers = self.active_offers;
            let mut temp_offers: Array<felt252> = array![];
            let len = active_offers.len();
            
                         let mut i = 0;
             loop {
                 if i >= len {
                     break;
                 }
                 let current_offer = active_offers.at(i).read();
                 if current_offer != offer_id {
                     temp_offers.append(current_offer);
                 }
                 i = i + 1;
             };

            // Clear and repopulate
            let mut current_len = active_offers.len();
            while current_len > 0 {
                if let Option::Some(_) = active_offers.pop() {}
                current_len -= 1;
            }

                         let mut j = 0;
             loop {
                 if j >= temp_offers.len() {
                     break;
                 }
                 active_offers.push(*temp_offers.at(j));
                 j = j + 1;
             };
        }
    }
}
