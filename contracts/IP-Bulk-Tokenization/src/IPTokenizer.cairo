

#[starknet::contract]
pub mod IPTokenizer {
    // Core imports
    use core::{
        array::ArrayTrait,
        traits::{Into},
        box::BoxTrait,
        option::OptionTrait,
        starknet::{
            ContractAddress, storage::{
                StoragePointerWriteAccess, 
                StoragePointerReadAccess, 
                StorageMapReadAccess, 
                StorageMapWriteAccess, 
                Map}
            },
        };
    //Openzeppellin imports
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;
    
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    
    use OwnableComponent::InternalTrait;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    // Interface import
    use super::super::interfaces::{IIPTokenizer, IIPNFTDispatcher, IIPNFTDispatcherTrait};
    // Type imports
    use super::super::types::{
        IPAssetData, 
        AssetType, 
        LicenseTerms, 
        INVALID_METADATA, 
        INVALID_ASSET_TYPE,
        INVALID_LICENSE_TERMS, 
        DEFAULT_BATCH_LIMIT,
        ERROR_EMPTY_BATCH,
        ERROR_BATCH_TOO_LARGE,
    };

    #[storage]
    struct Storage {
        nft_contract: ContractAddress,  
        batch_limit: u32,
        batch_counter: u256,
        batch_status: Map<u256, u8>,  // 0=pending, 1=processing, 2=completed, 3=failed
        tokens: Map<u256, IPAssetData>,
        token_counter: u256,
        gateway: ByteArray,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        BatchProcessed: BatchProcessed,
        BatchFailed: BatchFailed,
        TokenTransferred: TokenTransferred,
        TokenMinted: TokenMinted,
    }

    #[derive(Drop, starknet::Event)]
    struct BatchProcessed {
        batch_id: u256,
        token_ids: Array<u256>,
    }

    #[derive(Drop, starknet::Event)]
    struct BatchFailed {
        batch_id: u256,
        reason: felt252,
    }
    
    #[derive(Drop, starknet::Event)]
    struct TokenTransferred { 
        token_id: u256, 
        from: ContractAddress, 
        to: ContractAddress
    }
    
    #[derive(Drop, starknet::Event)]
    struct TokenMinted { 
        token_id: u256, 
        owner: ContractAddress
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        nft_contract_address: ContractAddress,
        gateway: ByteArray,
    ) {
        self.ownable.initializer(owner);
        self.nft_contract.write(nft_contract_address);
        self.gateway.write(gateway);
        self.batch_limit.write(DEFAULT_BATCH_LIMIT);
        self.token_counter.write(0);
    }

    #[abi(embed_v0)]
    impl IPTokenizerImpl of IIPTokenizer<ContractState> {
        fn bulk_tokenize(
            ref self: ContractState, 
            assets: Array<IPAssetData>
        ) -> Array<u256> {
            self.pausable.assert_not_paused();

            // Validate batch size
            let batch_size = assets.len();
            assert(batch_size > 0, ERROR_EMPTY_BATCH);
            assert(batch_size <= self.batch_limit.read(), ERROR_BATCH_TOO_LARGE);

            // Create new batch
            let batch_id = self.batch_counter.read() + 1;
            self.batch_counter.write(batch_id);
            self.batch_status.write(batch_id, 1); // Processing

            let mut token_ids: Array<u256> = ArrayTrait::new();

            // Process tokens
            let mut i: u32 = 0;
            loop {
                if i >= batch_size {
                    break;
                }

                match assets.get(i) {
                    Option::Some(_) => {
                        let asset = assets.get(i).unwrap().unbox();
                        // Mint token
                        let token_id = self._mint(asset.clone());
                        token_ids.append(token_id);
                    },
                    Option::None => {
                        break;
                    }
                }
                
                i += 1;
            };

            // Update batch status
            self.batch_status.write(batch_id, 2); // Completed
            self.emit(BatchProcessed { batch_id, token_ids: token_ids.clone() });

            token_ids
        }

        fn get_batch_status(self: @ContractState, batch_id: u256) -> u8 {
            self.batch_status.read(batch_id)
        }

        fn get_batch_limit(self: @ContractState) -> u32 {
            self.batch_limit.read()
        }

        fn set_batch_limit(ref self: ContractState, new_limit: u32) {
            self.ownable.assert_only_owner();
            self.batch_limit.write(new_limit);
        }

        fn set_paused(ref self: ContractState, paused: bool) {
            self.ownable.assert_only_owner();
            if paused {
                self.pausable.pause();
            } else {
                self.pausable.unpause();
            }
        }

        fn get_token_metadata(self: @ContractState, token_id: u256) -> IPAssetData {
            self.tokens.read(token_id)
        }

        fn get_token_owner(self: @ContractState, token_id: u256) -> ContractAddress {
            let nft_contract = IIPNFTDispatcher { contract_address: self.nft_contract.read() };
            nft_contract.ownerOf(token_id)
        }

        fn get_token_expiry(self: @ContractState, token_id: u256) -> u64 {
            let metadata = self.tokens.read(token_id);
            metadata.expiry_date
        }

        fn update_metadata(
            ref self: ContractState, 
            token_id: u256, 
            new_metadata: ByteArray
        ) {
            self.ownable.assert_only_owner();
            let mut asset = self.tokens.read(token_id);
            let updated_asset = IPAssetData {
                metadata_uri: new_metadata,
                ..asset
            };
            self.tokens.write(token_id, updated_asset);
        }

        fn update_license_terms(
            ref self: ContractState, 
            token_id: u256, 
            new_terms: LicenseTerms
        ) {
            self.ownable.assert_only_owner();
            let mut asset = self.tokens.read(token_id);
            let mut new_license_terms = asset.license_terms;
            new_license_terms = new_terms;
            self.tokens.write(token_id, asset);
        }

        fn transfer_token(
            ref self: ContractState, 
            token_id: u256, 
            to: ContractAddress
        ) {
            self.ownable.assert_only_owner();
            let asset = self.tokens.read(token_id);
            let from = asset.owner;
            let nft_contract = IIPNFTDispatcher { contract_address: self.nft_contract.read() };
            nft_contract.transferFrom(from, to, token_id);

            self.emit(TokenTransferred { token_id, from, to });
        }

        fn get_ipfs_gateway(self: @ContractState) -> ByteArray {
            self.gateway.read()
        }
        
        fn set_ipfs_gateway(ref self: ContractState, gateway: ByteArray) {
            self.ownable.assert_only_owner();
            self.gateway.write(gateway);
        }
        
        fn get_hash(self: @ContractState, token_id: u256) -> ByteArray {
            let metadata = self.tokens.read(token_id);
            metadata.metadata_hash
        }
    }


    #[generate_trait]
    impl Private of PrivateTrait {
        fn _mint(ref self: ContractState, asset: IPAssetData) -> u256 {
            assert(asset.clone().metadata_uri.len() != 0, INVALID_METADATA);
            assert(self._validate_asset_type(asset.clone().asset_type), INVALID_ASSET_TYPE);
            assert(self._validate_license_terms(asset.clone().license_terms), INVALID_LICENSE_TERMS);

            let token_id = self.token_counter.read() + 1;
            self.token_counter.write(token_id);

            // Store asset data
            self.tokens.write(token_id, asset.clone());

            // Mint NFT
            let nft_contract = IIPNFTDispatcher { contract_address: self.nft_contract.read() };
            let minted_token_id = nft_contract.mint(asset.owner);
            assert(minted_token_id == token_id, 'Token ID mismatch');

            self.emit(TokenMinted { token_id, owner: asset.owner });

            token_id
        }

        fn _validate_asset_type(self: @ContractState, asset_type: AssetType) -> bool {
            match asset_type {
                AssetType::Patent => true,
                AssetType::Trademark => true,
                AssetType::Copyright => true,
                AssetType::TradeSecret => true,
                _ => false,
            }
        }

        fn _validate_license_terms(self: @ContractState, terms: LicenseTerms) -> bool {
            match terms {
                LicenseTerms::Standard => true,
                LicenseTerms::Premium => true,
                LicenseTerms::Exclusive => true,
                LicenseTerms::Custom => true,
                _ => false,
            }
        }

    }
}