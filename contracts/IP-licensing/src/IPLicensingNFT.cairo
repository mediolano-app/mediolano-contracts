#[starknet::contract]
pub mod IPLicensingNFT {
    // *************************************************************************
    //                             IMPORTS
    // *************************************************************************

    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use core::num::traits::zero::Zero;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin::{access::ownable::OwnableComponent};

    use starknet::storage::{
        Map, StoragePointerWriteAccess, StoragePointerReadAccess, StorageMapReadAccess,
        StorageMapWriteAccess,
    };
    use ip_licensing::interfaces::IIPLicensingNFT;

    // *************************************************************************
    //                             COMPONENTS
    // *************************************************************************
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ERC721 Mixin
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

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
        last_minted_id: u256,
        mint_timestamp: Map<u256, u64>,
        token_uris: Map<u256, ByteArray>,
        licensing_data: Map<u256, ByteArray>,
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
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.ownable.initializer(admin);
        self.erc721.initializer("MediolanoIntelctualProperty", "MIP", "https://ipfs.io/ipfs/");
    }


    #[abi(embed_v0)]
    impl IPLicensingImpl of IIPLicensingNFT::IIPLicensingNFT<ContractState> {
        // *************************************************************************
        //                            EXTERNAL
        // *************************************************************************
         
        //Mint new Licensing NFT with another NFT
        fn mint_Licensing_nft(
            ref self: ContractState,
            recipient: ContractAddress,             // address of new Derived licese nft owner
            token_id: u256,                         // token ID of perent NFT
            new_token_uri: ByteArray,               // new URI for the token 
            license_data: ByteArray,                // licensing data associated with the token               
        ) -> u256 {
            assert(self.owner_of(token_id) == get_caller_address(), 'INVALID_CALLER');
            assert(recipient.is_non_zero(), 'EMPTY_ADDRESS');
            assert(new_token_uri.len() > 0, 'EMPTY_URI');
            assert(license_data.len() > 0, 'EMPTY_LICENSE');

            let mut new_token_id = self.last_minted_id.read() + 1;
            self.erc721.mint(recipient, new_token_id);
            self.token_uris.write(new_token_id, new_token_uri);
            self.licensing_data.write(new_token_id, license_data);

            self.last_minted_id.write(new_token_id);
            self.mint_timestamp.write(new_token_id, get_block_timestamp());
            new_token_id
        }
        
        // Mint new fresh NFT
        fn mint_nft(
            ref self: ContractState, recipient: ContractAddress, new_token_uri: ByteArray,
        ) -> u256 {
            assert(recipient.is_non_zero(), 'EMPTY_ADDRESS');
            assert(new_token_uri.len() > 0, 'EMPTY_URI');

            let mut new_token_id = self.last_minted_id.read() + 1;
            self.erc721.mint(recipient, new_token_id);
            self.token_uris.write(new_token_id, new_token_uri);

            self.last_minted_id.write(new_token_id);
            self.mint_timestamp.write(new_token_id, get_block_timestamp());
            new_token_id
        }
        
        // It return last minted NFT ID
        fn get_last_minted_id(self: @ContractState) -> u256 {
            self.last_minted_id.read()
        }
        
        
        fn get_token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.token_uris.read(token_id)
        }

        fn get_token_mint_timestamp(self: @ContractState, token_id: u256) -> u64 {
            self.mint_timestamp.read(token_id)
        }

        fn get_license_data(self: @ContractState, token_id: u256) -> ByteArray {
            self.licensing_data.read(token_id)
        }
       
        fn get_owner_of_token(self: @ContractState, token_id: u256) -> ContractAddress {
            self.owner_of(token_id)
        }
    }
}
