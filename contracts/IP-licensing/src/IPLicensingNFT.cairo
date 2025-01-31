#[starknet::contract]
pub mod IPLicensingNFT {
    // *************************************************************************
    //                             IMPORTS
    // *************************************************************************
    use starknet::{ContractAddress,};
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
        token_id_counter: u256,
        token_uris: Map<u256, ByteArray>,
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
    impl IPLicensingNFTImpl of IIPLicensingNFT<ContractState> {
        // *************************************************************************
        //                            EXTERNAL FUNCTIONS
        // *************************************************************************

        // Mint a licensing NFT from derived from a NFT
        fn mint_license(
            ref self: ContractState, recipient: ContractAddress, metadata_uri: ByteArray,
        ) -> u256 {   
            let token_id = self.token_id_counter.read() + 1;
            self.erc721.mint(recipient, token_id);
            self.token_uris.write(token_id, metadata_uri);
            token_id
        }
    }
}
