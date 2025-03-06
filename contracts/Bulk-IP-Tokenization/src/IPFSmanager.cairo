
#[starknet::contract]
mod IPFSmanager {
    use super::super::interfaces::IIPFSManager;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        ipfsgateway: ByteArray,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
    }

    #[constructor]
    fn constructor(ref self: ContractState, ipfsgateway: ByteArray) {
        self.ipfsgateway.write(ipfsgateway);
    }

    #[abi(embed_v0)]
    impl IPFSManager of IIPFSManager<ContractState>  {
        fn pin_to_ipfs(ref self: ContractState, data: ByteArray) -> ByteArray {
            return data;
        }
        fn validate_ipfs_hash(self: @ContractState, hash: ByteArray) -> bool {
            return true;
        }
        fn get_ipfs_gateway(self: @ContractState) -> ByteArray {
            self.ipfsgateway.read()
        }
        fn set_ipfs_gateway(ref self: ContractState, gateway: ByteArray) {
            self.ipfsgateway.write(gateway);
        }
    }
}
