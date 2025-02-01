#[starknet::contract]
pub mod IPLicensingNFT {
    // *************************************************************************
    //                             IMPORTS
    // *************************************************************************
    use starknet::{ContractAddress, get_block_timestamp};
    use core::num::traits::zero::Zero;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin::{access::ownable::OwnableComponent};

    use starknet::storage::{
        Map, StoragePointerWriteAccess, StoragePointerReadAccess, StorageMapReadAccess,
        StorageMapWriteAccess
    };
    use ip_licensing::interfaces::IIPLicensingNFT;

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
        mint_timestamp: Map<u256, u64>,
        token_uris : Map<u256  , ByteArray>,
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
        SRC5Event: SRC5Component::Event
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        self.erc721.initializer("SPIDERS", "WEBS", "" // The pinata URL will be updated soon
        );
    }


    #[abi(embed_v0)]
    impl IPLicensingImpl of IIPLicensingNFT::IIPLicensingNFT<ContractState> {
        // *************************************************************************
        //                            EXTERNAL
        // *************************************************************************

        fn mint_Licensing_nft(ref self:ContractState, recipient: ContractAddress , token_uri : ByteArray)-> u256 {
            assert(recipient.is_non_zero(), 'EMPTY_ADDRESS');
            assert(token_uri.len()>0 , 'EMPTY_URI');
            let mut token_id = self.last_minted_id.read() + 1;
            self.erc721.mint(recipient, token_id);
            self.token_uris.write(token_id , token_uri);
            let timestamp: u64 = get_block_timestamp();

            self.last_minted_id.write(token_id);
            self.mint_timestamp.write(token_id, timestamp);
            token_id
        }

        fn get_last_minted_id(self: @ContractState) -> u256 {
            self.last_minted_id.read()
        }
        fn get_token_uri(self: @ContractState  , token_id : u256) -> ByteArray {
            self.token_uris.read(token_id) 
        }

        fn get_token_mint_timestamp(self: @ContractState, token_id: u256) -> u64 {
            self.mint_timestamp.read(token_id)
        }
    }
}