#[starknet::contract]
mod ERC1155WithLicensing {
    use array::{Span, ArrayTrait, SpanTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc1155::ERC1155Component;
    use starknet::ContractAddress;

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        _licenses: LegacyMap<u256, Span<felt252>>, // Licensing terms for each token
        _token_uris: LegacyMap<u256, Span<felt252>>, // Per-token metadata URIs
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        LicenseUpdated: LicenseUpdated, // New event for licensing updates
        TokenURIUpdated: TokenURIUpdated, // New event for metadata updates
    }

    #[derive(Drop, starknet::Event)]
    struct LicenseUpdated {
        token_id: u256,
        license_terms: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenURIUpdated {
        token_id: u256,
        uri: Span<felt252>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    //
    // External Functions
    //
    #[generate_trait]
    #[abi(per_item)]
    impl ERC1155WithLicensingImpl of ERC1155WithLicensingTrait {
        #[external(v0)]
        fn mint(
            ref self: ContractState,
            account: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>,
            metadata_uri: Span<felt252>,
            license_terms: Span<felt252>
        ) {
            self.ownable.assert_only_owner(); // Only the owner can mint
            self.erc1155.mint_with_acceptance_check(account, token_id, value, data);
            self._token_uris.write(token_id, metadata_uri); // Store metadata URI
            self._licenses.write(token_id, license_terms); // Store licensing terms
            self.emit(Event::TokenURIUpdated(TokenURIUpdated { token_id, uri: metadata_uri }));
            self.emit(Event::LicenseUpdated(LicenseUpdated { token_id, license_terms }));
        }

        #[external(v0)]
        fn batch_mint(
            ref self: ContractState,
            account: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>,
            metadata_uris: Span<Span<felt252>>,
            license_terms: Span<Span<felt252>>
        ) {
            self.ownable.assert_only_owner(); // Only the owner can mint
            assert(
                token_ids.len() == values.len(), 'ERC1155: token_ids and values length mismatch'
            );
            assert(
                token_ids.len() == metadata_uris.len(),
                'ERC1155: token_ids and metadata_uris length mismatch'
            );
            assert(
                token_ids.len() == license_terms.len(),
                'ERC1155: token_ids and license_terms length mismatch'
            );

            self.erc1155.batch_mint_with_acceptance_check(account, token_ids, values, data);

            let mut i: usize = 0;
            let len = token_ids.len();
            loop {
                if i >= len {
                    break;
                }
                let token_id = *token_ids.at(i);
                let metadata_uri = *metadata_uris.at(i);
                let license_term = *license_terms.at(i);

                self._token_uris.write(token_id, metadata_uri); // Store metadata URI
                self._licenses.write(token_id, license_term); // Store licensing terms
                self.emit(Event::TokenURIUpdated(TokenURIUpdated { token_id, uri: metadata_uri }));
                self
                    .emit(
                        Event::LicenseUpdated(
                            LicenseUpdated { token_id, license_terms: license_term }
                        )
                    );

                i += 1;
            }
        }

        #[external(v0)]
        fn get_license_terms(self: @ContractState, token_id: u256) -> Span<felt252> {
            self._licenses.read(token_id)
        }

        #[external(v0)]
        fn get_token_uri(self: @ContractState, token_id: u256) -> Span<felt252> {
            self._token_uris.read(token_id)
        }

        #[external(v0)]
        fn list_tokens(self: @ContractState, owner: ContractAddress) -> Span<u256> {
            self.erc1155.balance_of_batch(array![owner].span(), self.erc1155.get_all_token_ids())
        }
    }
}
