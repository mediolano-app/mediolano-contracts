use starknet::{ContractAddress};

#[starknet::interface]
pub trait IMockERC721<TContractState> {
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn mint(ref self: TContractState, to: ContractAddress, token_id: u256);
}

#[starknet::contract]
pub mod MockERC721 {
    use starknet::{ContractAddress, get_caller_address};
    use core::num::traits::Zero;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    // Storage
    #[storage]
    struct Storage {
        owners: Map<u256, ContractAddress>, // Maps token_id to owner
        owner: ContractAddress, // Contract owner (for minting control)
    }

    // Constructor to set the contract owner
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }


    // Implementation
    #[abi(embed_v0)]
    pub impl ERC721Impl of super::IMockERC721<ContractState> {
        // Returns the owner of a given token_id
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.owners.read(token_id);
            assert(!owner.is_zero(), 'ERC721: invalid token ID');
            owner
        }

        // Mints a new token to the specified address (only callable by owner)
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'ERC721: unauthorized');
            assert(!to.is_zero(), 'ERC721: invalid receiver');
            assert(self.owners.read(token_id).is_zero(), 'ERC721: token already minted');

            self.owners.write(token_id, to);
        }
    }
}
