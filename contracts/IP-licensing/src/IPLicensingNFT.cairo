#[starknet::contract]
pub mod IPLicensingNFT {
    // *************************************************************************
    //                             IMPORTS
    // *************************************************************************
    use alexandria_storage::ListTrait;
    use alexandria_storage::List;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use core::num::traits::zero::Zero;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin::{access::ownable::OwnableComponent};


    use starknet::storage::{
        Map, StoragePointerWriteAccess, StoragePointerReadAccess, StorageMapReadAccess,
        StorageMapWriteAccess,
    };
    use ip_licensing::interfaces::IIPLicensingNFT::{
        IIPLicensingNFT, IIPLicensingNFTDispatcher, IIPLicensingNFTDispatcherTrait,
    };
    use ip_licensing::interfaces::IERC721::{IERC721, IERC721Dispatcher, IERC721DispatcherTrait};

    // *************************************************************************
    //                             COMPONENTS
    // *************************************************************************
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721 Mixin
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // *************************************************************************
    //                             STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        admin: ContractAddress,
        last_minted_id: u256,
        // user_derived_nft_ids is maping of owner_of_perentNFT  and  List< child_nft_ids >
        user_derived_tokens: Map<ContractAddress, List<u256>>,
        // mint_timestamp  is mapping of child_nft_id and  timestamp when NFT minted
        mint_timestamp: Map<u256, u64>,
        // derivedNFT_id is map of perent_nft_id and List<child_nft_ids>
        NFT_derived_tokens: Map<u256, List<u256>>,
        //licensing_data  is mapping of child_nft_id and  IPLiceseData
        licensing_data: Map<u256, IPLicenseData>,
    }


    // *************************************************************************
    //                             EVENTS
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }


    #[derive(Drop, Serde, Debug, PartialEq, starknet::Store)]
    pub struct IPLicenseData {
        derivefrom: u256, //perent_nft_id
        license_type: u8, // Licesnse Type 
        duration: u32,
        royalty_rate: u8,
        upfront_fee: u256,
        sublicensing: bool,
        exclusivity: u8,
        metadata_cid: felt252 // IPFS cid of child NFT 
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        self.erc721.initializer("SPIDERS", "WEBS", ""); // The pinata URL will be updated soon
    }

    #[abi(embed_v0)]
    impl IPLicensingNFTImpl of IIPLicensingNFT<ContractState> {
        // *************************************************************************
        //                            EXTERNAL FUNCTIONS
        // *************************************************************************

        fn mint_license_nft(
            ref self: ContractState,
            original_nft_id: u256,
            license_type: u8,
            duration: u32,
            royalty_rate: u8,
            upfront_fee: u256,
            sublicensing: bool,
            exclusivity: u8,
            metadata_cid: felt252,
        ) -> u256 {
            let license_data = self
                .prepare_license_data(
                    original_nft_id,
                    license_type,
                    duration,
                    royalty_rate,
                    upfront_fee,
                    sublicensing,
                    exclusivity,
                    metadata_cid,
                );
            self.mint_and_store_license(license_data, original_nft_id)
        }


        fn prepare_license_data(
            ref self: ContractState,
            original_nft_id: u256,
            license_type: u8,
            duration: u32,
            royalty_rate: u8,
            upfront_fee: u256,
            sublicensing: bool,
            exclusivity: u8,
            metadata_cid: felt252,
        ) -> IPLicenseData {
            let nft_owner = self.erc721.owner_of(original_nft_id);
            assert(get_caller_address() == nft_owner, 'Caller_not_owner_of_org_NFT');
            assert(license_type >= 0 && license_type < 3, 'Invalid_license_type');
            assert(duration > 0, 'Duration_must_be_positive');
            assert(royalty_rate <= 100, 'Royalty_rate_exceeds_100');
            assert(upfront_fee >= 0, 'Upfront_fee_cannot_be_negative');
            assert(exclusivity >= 0 && exclusivity < 3, 'Invalid_exclusivity_value');
            assert(metadata_cid.is_non_zero(), 'Metadata_CID_cannot_be_empty');

            IPLicenseData {
                derivefrom: original_nft_id,
                license_type,
                duration,
                royalty_rate,
                upfront_fee,
                sublicensing,
                exclusivity,
                metadata_cid,
            }
        }

        fn mint_and_store_license(
            ref self: ContractState, license_data: IPLicenseData, original_nft_id: u256,
        ) -> u256 {
            let caller = get_caller_address();

            let nft_owner = self.erc721.owner_of(original_nft_id);
            assert(caller == nft_owner, 'Caller_not_owner_of_org_NFT');

            let new_nft_id = self.last_minted_id.read() + 1;

            self.erc721.mint(caller, new_nft_id);
            self.licensing_data.write(new_nft_id, license_data);

            let mut nft_id_list = self.NFT_derived_tokens.read(original_nft_id);
            assert(nft_id_list.append(new_nft_id).is_ok(), 'Failed_to_append_derived_tokens');
            self.NFT_derived_tokens.write(original_nft_id, nft_id_list);

            let mut user_nft = self.user_derived_tokens.read(caller);
            assert(user_nft.append(new_nft_id).is_ok(), 'Fail_append_user_derived_tokens');
            self.user_derived_tokens.write(caller, user_nft);

            self.mint_timestamp.write(new_nft_id, get_block_timestamp());
            self.last_minted_id.write(new_nft_id);

            new_nft_id
        }

        fn get_licensing_data(ref self: ContractState, nft_id: u256) -> IPLicenseData {
            // Retrieve the licensing data of a child NFT
            self.licensing_data.read(nft_id)
        }
    }
}
