use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
struct ContributionType {
    type_id: felt252,
    min_quality_score: u8,
    submission_deadline: u64,
    max_supply: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Contribution {
    contributor: ContractAddress,
    asset_uri: felt252,
    metadata: felt252,
    contribution_type: felt252,
    quality_score: u8,
    submission_time: u64,
    verified: bool,
    minted: bool,
    timestamp: u64,
    // Marketplace fields
    listed: bool,
    price: u256,
    // Collaboration fields
    co_creator: ContractAddress,
    royalty_percentage: u8,
}

#[starknet::interface]
trait IIPCollection<TContractState> {
    // Core contribution functions
    fn submit_contribution(
        ref self: TContractState, asset_uri: felt252, metadata: felt252, contribution_type: felt252,
    );
    fn verify_contribution(
        ref self: TContractState, contribution_id: u256, verified: bool, quality_score: u8,
    );
    fn mint_nft(ref self: TContractState, contribution_id: u256, recipient: ContractAddress);

    // Batch operations
    fn batch_submit_contributions(
        ref self: TContractState,
        assets: Array<felt252>,
        metadatas: Array<felt252>,
        types: Array<felt252>,
    );

    // Query functions
    fn get_contribution(self: @TContractState, contribution_id: u256) -> Contribution;
    fn get_contributions_count(self: @TContractState) -> u256;
    fn get_contributor_contributions(
        self: @TContractState, contributor: ContractAddress,
    ) -> Array<u256>;

    // Type management
    fn register_contribution_type(
        ref self: TContractState,
        type_id: felt252,
        min_quality_score: u8,
        submission_deadline: u64,
        max_supply: u256,
    );
    fn get_contribution_type(self: @TContractState, type_id: felt252) -> ContributionType;

    // Access control
    fn is_verifier(self: @TContractState, address: ContractAddress) -> bool;
    fn add_verifier(ref self: TContractState, verifier: ContractAddress);
    fn remove_verifier(ref self: TContractState, verifier: ContractAddress);

    // Marketplace functions
    fn list_contribution(ref self: TContractState, contribution_id: u256, price: u256);
    fn unlist_contribution(ref self: TContractState, contribution_id: u256);
    fn update_price(ref self: TContractState, contribution_id: u256, new_price: u256);

    // Collaboration functions
    fn add_co_creator(
        ref self: TContractState,
        contribution_id: u256,
        co_creator: ContractAddress,
        royalty_percentage: u8,
    );
}

#[starknet::contract]
mod IPCollection {
    use super::{IIPCollection, Contribution, ContributionType};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use core::array::ArrayTrait;
    use core::starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        contributions_count: u256,
        contributions: Map<u256, Contribution>,
        contributor_to_contribution_count: Map<ContractAddress, u256>,
        contributor_contributions: Map<(ContractAddress, u256), u256>,
        verifiers: Map<ContractAddress, bool>,
        contribution_types: Map<felt252, ContributionType>,
        type_counts: Map<felt252, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ContributionSubmitted: ContributionSubmitted,
        ContributionVerified: ContributionVerified,
        NFTMinted: NFTMinted,
        VerifierAdded: VerifierAdded,
        VerifierRemoved: VerifierRemoved,
        BatchSubmitted: BatchSubmitted,
        TypeRegistered: TypeRegistered,
        ContributionListed: ContributionListed,
        ContributionUnlisted: ContributionUnlisted,
        PriceUpdated: PriceUpdated,
        CoCreatorAdded: CoCreatorAdded,
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionSubmitted {
        #[key]
        contribution_id: u256,
        contributor: ContractAddress,
        asset_uri: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionVerified {
        #[key]
        contribution_id: u256,
        verified: bool,
        quality_score: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct NFTMinted {
        #[key]
        contribution_id: u256,
        recipient: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct VerifierAdded {
        #[key]
        verifier: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct VerifierRemoved {
        #[key]
        verifier: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct BatchSubmitted {
        #[key]
        count: u256,
        contributor: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TypeRegistered {
        #[key]
        type_id: felt252,
        min_quality_score: u8,
        submission_deadline: u64,
        max_supply: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionListed {
        #[key]
        contribution_id: u256,
        price: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionUnlisted {
        #[key]
        contribution_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PriceUpdated {
        #[key]
        contribution_id: u256,
        new_price: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct CoCreatorAdded {
        #[key]
        contribution_id: u256,
        co_creator: ContractAddress,
        royalty_percentage: u8,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.contributions_count.write(0);
        self.verifiers.entry(owner).write(true);
    }

    #[abi(embed_v0)]
    impl IPCollectionImpl of super::IIPCollection<ContractState> {
        fn submit_contribution(
            ref self: ContractState,
            asset_uri: felt252,
            metadata: felt252,
            contribution_type: felt252,
        ) {
            let caller = get_caller_address();
            let contribution_id = self.contributions_count.read() + 1;

            // Verify contribution type and deadline
            let type_info = self.contribution_types.entry(contribution_type).read();
            let current_time = get_block_timestamp();
            assert(current_time <= type_info.submission_deadline, 'Deadline passed');

            // Check supply limit
            let current_type_count = self.type_counts.entry(contribution_type).read();
            assert(current_type_count < type_info.max_supply, 'Max supply reached');

            let contribution = Contribution {
                contributor: caller,
                asset_uri,
                metadata,
                contribution_type,
                quality_score: 0,
                submission_time: current_time,
                verified: false,
                minted: false,
                timestamp: current_time,
                listed: false,
                price: 0,
                // co_creator: ContractAddress::default(),
                co_creator: starknet::contract_address_const::<0>(),
                royalty_percentage: 0,
            };

            self.contributions.entry(contribution_id).write(contribution);

            let current_count = self.contributor_to_contribution_count.entry(caller).read();
            let new_count = current_count + 1;

            self.contributor_contributions.entry((caller, new_count)).write(contribution_id);
            self.contributor_to_contribution_count.entry(caller).write(new_count);
            self.type_counts.entry(contribution_type).write(current_type_count + 1);

            self.contributions_count.write(contribution_id);

            self
                .emit(
                    Event::ContributionSubmitted(
                        ContributionSubmitted { contribution_id, contributor: caller, asset_uri },
                    ),
                );
        }

        fn verify_contribution(
            ref self: ContractState, contribution_id: u256, verified: bool, quality_score: u8,
        ) {
            let caller = get_caller_address();
            assert(self.verifiers.entry(caller).read(), 'Not authorized');

            let contribution = self.contributions.entry(contribution_id).read();
            assert(!contribution.minted, 'Already minted');

            // Check quality score
            let type_info = self.contribution_types.entry(contribution.contribution_type).read();
            assert(quality_score >= type_info.min_quality_score, 'Quality score too low');

            let new_contribution = Contribution {
                quality_score, verified, timestamp: get_block_timestamp(), ..contribution,
            };

            self.contributions.entry(contribution_id).write(new_contribution);
            self
                .emit(
                    Event::ContributionVerified(
                        ContributionVerified { contribution_id, verified, quality_score },
                    ),
                );
        }

        fn mint_nft(ref self: ContractState, contribution_id: u256, recipient: ContractAddress) {
            let contribution = self.contributions.entry(contribution_id).read();
            assert(contribution.verified, 'Not verified');
            assert(!contribution.minted, 'Already minted');

            let new_contribution = Contribution {
                minted: true, timestamp: get_block_timestamp(), ..contribution,
            };

            self.contributions.entry(contribution_id).write(new_contribution);
            self.emit(Event::NFTMinted(NFTMinted { contribution_id, recipient }));
        }

        fn batch_submit_contributions(
            ref self: ContractState,
            assets: Array<felt252>,
            metadatas: Array<felt252>,
            types: Array<felt252>,
        ) {
            assert(
                assets.len() == metadatas.len() && assets.len() == types.len(), 'Length mismatch',
            );
            let caller = get_caller_address();

            let mut i: u32 = 0;
            let len = assets.len();

            loop {
                if i >= len {
                    break;
                }
                self.submit_contribution(*assets.at(i), *metadatas.at(i), *types.at(i));
                i += 1;
            };

            self
                .emit(
                    Event::BatchSubmitted(
                        BatchSubmitted { count: len.into(), contributor: caller },
                    ),
                );
        }

        fn list_contribution(ref self: ContractState, contribution_id: u256, price: u256) {
            let contribution = self.contributions.entry(contribution_id).read();
            assert(contribution.verified, 'Not verified');
            assert(contribution.minted, 'Not minted');
            assert(!contribution.listed, 'Already listed');
            assert(
                contribution.contributor == get_caller_address()
                    || contribution.co_creator == get_caller_address(),
                'Not authorized',
            );

            let new_contribution = Contribution {
                listed: true, price, timestamp: get_block_timestamp(), ..contribution,
            };

            self.contributions.entry(contribution_id).write(new_contribution);
            self.emit(Event::ContributionListed(ContributionListed { contribution_id, price }));
        }

        fn unlist_contribution(ref self: ContractState, contribution_id: u256) {
            let contribution = self.contributions.entry(contribution_id).read();
            assert(contribution.listed, 'Not listed');
            assert(
                contribution.contributor == get_caller_address()
                    || contribution.co_creator == get_caller_address(),
                'Not authorized',
            );

            let new_contribution = Contribution {
                listed: false, price: 0, timestamp: get_block_timestamp(), ..contribution,
            };

            self.contributions.entry(contribution_id).write(new_contribution);
            self.emit(Event::ContributionUnlisted(ContributionUnlisted { contribution_id }));
        }

        fn update_price(ref self: ContractState, contribution_id: u256, new_price: u256) {
            let contribution = self.contributions.entry(contribution_id).read();
            assert(contribution.listed, 'Not listed');
            assert(
                contribution.contributor == get_caller_address()
                    || contribution.co_creator == get_caller_address(),
                'Not authorized',
            );

            let new_contribution = Contribution {
                price: new_price, timestamp: get_block_timestamp(), ..contribution,
            };

            self.contributions.entry(contribution_id).write(new_contribution);
            self.emit(Event::PriceUpdated(PriceUpdated { contribution_id, new_price }));
        }

        fn add_co_creator(
            ref self: ContractState,
            contribution_id: u256,
            co_creator: ContractAddress,
            royalty_percentage: u8,
        ) {
            let contribution = self.contributions.entry(contribution_id).read();
            assert(contribution.contributor == get_caller_address(), 'Not contributor');
            assert(royalty_percentage <= 100, 'Invalid royalty');
            assert(contribution.co_creator.into() == 0, 'Co-creator exists');

            let new_contribution = Contribution {
                co_creator, royalty_percentage, timestamp: get_block_timestamp(), ..contribution,
            };

            self.contributions.entry(contribution_id).write(new_contribution);
            self
                .emit(
                    Event::CoCreatorAdded(
                        CoCreatorAdded { contribution_id, co_creator, royalty_percentage },
                    ),
                );
        }

        // Query functions
        fn get_contribution(self: @ContractState, contribution_id: u256) -> Contribution {
            self.contributions.entry(contribution_id).read()
        }

        fn get_contributions_count(self: @ContractState) -> u256 {
            self.contributions_count.read()
        }

        fn get_contributor_contributions(
            self: @ContractState, contributor: ContractAddress,
        ) -> Array<u256> {
            let count = self.contributor_to_contribution_count.entry(contributor).read();
            let mut contributions = ArrayTrait::new();

            let mut i: u256 = 1;
            loop {
                if i > count {
                    break;
                }
                let contribution_id = self.contributor_contributions.entry((contributor, i)).read();
                contributions.append(contribution_id);
                i += 1;
            };

            contributions
        }

        // Type management
        fn register_contribution_type(
            ref self: ContractState,
            type_id: felt252,
            min_quality_score: u8,
            submission_deadline: u64,
            max_supply: u256,
        ) {
            self.only_owner();

            let type_info = ContributionType {
                type_id, min_quality_score, submission_deadline, max_supply,
            };

            self.contribution_types.entry(type_id).write(type_info);
            self.type_counts.entry(type_id).write(0);

            self
                .emit(
                    Event::TypeRegistered(
                        TypeRegistered {
                            type_id, min_quality_score, submission_deadline, max_supply,
                        },
                    ),
                );
        }

        fn get_contribution_type(self: @ContractState, type_id: felt252) -> ContributionType {
            self.contribution_types.entry(type_id).read()
        }

        // Access control
        fn is_verifier(self: @ContractState, address: ContractAddress) -> bool {
            self.verifiers.entry(address).read()
        }

        fn add_verifier(ref self: ContractState, verifier: ContractAddress) {
            self.only_owner();
            self.verifiers.entry(verifier).write(true);
            self.emit(Event::VerifierAdded(VerifierAdded { verifier }));
        }

        fn remove_verifier(ref self: ContractState, verifier: ContractAddress) {
            self.only_owner();
            self.verifiers.entry(verifier).write(false);
            self.emit(Event::VerifierRemoved(VerifierRemoved { verifier }));
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn only_owner(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner');
        }
    }
}

