use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Contribution {
    contributor: ContractAddress,
    asset_uri: felt252,
    metadata: felt252,
    verified: bool,
    minted: bool,
    timestamp: u64,
}

#[starknet::interface]
trait IIPCollection<TContractState> {
    fn submit_contribution(ref self: TContractState, asset_uri: felt252, metadata: felt252);
    fn verify_contribution(ref self: TContractState, contribution_id: u256, verified: bool);
    fn mint_nft(ref self: TContractState, contribution_id: u256, recipient: ContractAddress);
    fn batch_submit_contributions(ref self: TContractState, assets: Array<felt252>, metadatas: Array<felt252>);
    fn get_contribution(self: @TContractState, contribution_id: u256) -> Contribution;
    fn get_contributions_count(self: @TContractState) -> u256;
    fn get_contributor_contributions(self: @TContractState, contributor: ContractAddress) -> Array<u256>;
    fn is_verifier(self: @TContractState, address: ContractAddress) -> bool;
    fn add_verifier(ref self: TContractState, verifier: ContractAddress);
    fn remove_verifier(ref self: TContractState, verifier: ContractAddress);
}

#[starknet::contract]
mod IPCollection {
    use super::{IIPCollection, Contribution};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use core::array::ArrayTrait;
    // use core::array::SpanTrait;
    use core::starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        contributions_count: u256,
        contributions: Map<u256, Contribution>,
        contributor_to_contribution_count: Map<ContractAddress, u256>,
        contributor_contributions: Map<(ContractAddress, u256), u256>,
        verifiers: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ContributionSubmitted: ContributionSubmitted,
        ContributionVerified: ContributionVerified,
        NFTMinted: NFTMinted,
        VerifierAdded: VerifierAdded,
        VerifierRemoved: VerifierRemoved,
        BatchSubmitted: BatchSubmitted
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

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.contributions_count.write(0);
        self.verifiers.entry(owner).write(true);
    }

    #[abi(embed_v0)]
    impl IPCollectionImpl of super::IIPCollection<ContractState> {
        fn submit_contribution(ref self: ContractState, asset_uri: felt252, metadata: felt252) {
            let caller = get_caller_address();
            let contribution_id = self.contributions_count.read() + 1;
            
            let contribution = Contribution {
                contributor: caller,
                asset_uri,
                metadata,
                verified: false,
                minted: false,
                timestamp: get_block_timestamp(),
            };

            self.contributions.entry(contribution_id).write(contribution);
            
            let current_count = self.contributor_to_contribution_count.entry(caller).read();
            let new_count = current_count + 1;
            
            self.contributor_contributions.entry((caller, new_count)).write(contribution_id);
            self.contributor_to_contribution_count.entry(caller).write(new_count);
            
            self.contributions_count.write(contribution_id);

            self.emit(Event::ContributionSubmitted(ContributionSubmitted {
                contribution_id,
                contributor: caller,
                asset_uri,
            }));
        }

        fn batch_submit_contributions(
            ref self: ContractState,
            assets: Array<felt252>,
            metadatas: Array<felt252>
        ) {
            assert(assets.len() == metadatas.len(), 'Arrays length mismatch');
            let caller = get_caller_address();
            
            let mut i: u32 = 0;
            let len = assets.len();
            
            loop {
                if i >= len {
                    break;
                }
                self.submit_contribution(*assets.at(i), *metadatas.at(i));
                i += 1;
            };

            self.emit(Event::BatchSubmitted(BatchSubmitted {
                count: len.into(),
                contributor: caller,
            }));
        }

        fn verify_contribution(ref self: ContractState, contribution_id: u256, verified: bool) {
            let caller = get_caller_address();
            assert(self.verifiers.entry(caller).read(), 'Not authorized');
            
            let contribution = self.contributions.entry(contribution_id).read();
            assert(!contribution.minted, 'Already minted');

            let new_contribution = Contribution {
                contributor: contribution.contributor,
                asset_uri: contribution.asset_uri,
                metadata: contribution.metadata,
                verified,
                minted: contribution.minted,
                timestamp: contribution.timestamp,
            };
            
            self.contributions.entry(contribution_id).write(new_contribution);
            self.emit(Event::ContributionVerified(ContributionVerified { 
                contribution_id, 
                verified 
            }));
        }

        fn mint_nft(ref self: ContractState, contribution_id: u256, recipient: ContractAddress) {
            let contribution = self.contributions.entry(contribution_id).read();
            assert(contribution.verified, 'Not verified');
            assert(!contribution.minted, 'Already minted');

            let new_contribution = Contribution {
                contributor: contribution.contributor,
                asset_uri: contribution.asset_uri,
                metadata: contribution.metadata,
                verified: contribution.verified,
                minted: true,
                timestamp: contribution.timestamp,
            };
            
            self.contributions.entry(contribution_id).write(new_contribution);
            self.emit(Event::NFTMinted(NFTMinted { 
                contribution_id, 
                recipient 
            }));
        }

        fn get_contribution(self: @ContractState, contribution_id: u256) -> Contribution {
            self.contributions.entry(contribution_id).read()
        }

        fn get_contributions_count(self: @ContractState) -> u256 {
            self.contributions_count.read()
        }

        fn get_contributor_contributions(self: @ContractState, contributor: ContractAddress) -> Array<u256> {
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