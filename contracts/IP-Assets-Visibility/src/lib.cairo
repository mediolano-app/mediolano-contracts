#[starknet::contract]
mod VisibilityManagement {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        visibility: Map<(ContractAddress, u256, ContractAddress), u8>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        VisibilityChanged: VisibilityChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct VisibilityChanged {
        token_address: ContractAddress,
        asset_id: u256,
        owner: ContractAddress,
        visibility_status: u8,
    }

    #[external(v0)]
    fn set_visibility(
        ref self: ContractState,
        token_address: ContractAddress,
        asset_id: u256,
        visibility_status: u8,
    ) {
        assert(visibility_status == 0 || visibility_status == 1, 'Invalid visibility status');

        let caller = get_caller_address();
        self.visibility.write((token_address, asset_id, caller), visibility_status);

        self
            .emit(
                Event::VisibilityChanged(
                    VisibilityChanged {
                        token_address: token_address,
                        asset_id: asset_id,
                        owner: caller,
                        visibility_status: visibility_status,
                    },
                ),
            );
    }

    #[external(v0)]
    fn get_visibility(
        self: @ContractState,
        token_address: ContractAddress,
        asset_id: u256,
        owner: ContractAddress,
    ) -> u8 {
        self.visibility.read((token_address, asset_id, owner))
    }
}
