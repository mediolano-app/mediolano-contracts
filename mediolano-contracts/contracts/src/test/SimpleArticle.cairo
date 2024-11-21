#[starknet::contract]
mod publication_nft {
    // Define storage variables
    struct Storage {
        owner: felt,
        publication_data: felt,
    }

    // Function to initialize the NFT with publication data
    #[external]
    fn initialize(owner: felt, publication_data: felt) {
        let storage: Storage = Storage::new();
        storage.owner.write(owner);
        storage.publication_data.write(publication_data);
    }

    // Function to get the publication data
    #[view]
    fn get_publication_data() -> felt {
        let storage: Storage = Storage::new();
        return storage.publication_data.read();
    }

    // Function to transfer ownership of the NFT
    #[external]
    fn transfer_ownership(new_owner: felt) {
        let storage: Storage = Storage::new();
        storage.owner.write(new_owner);
    }
}