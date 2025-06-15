use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IMIPCollections<TContractState> {
    fn deploy_collection(
        self: @TContractState,
        class_hash: ClassHash,
        salt: felt252,
        from_zero: bool,
        constructor_calldata: Array<felt252>
    ) -> ContractAddress;
}

#[starknet::contract]
mod MIPCollections {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::utils::interfaces::{IUniversalDeployerDispatcher, IUniversalDeployerDispatcherTrait};
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};

    use super::IMIPCollections;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    const UDC_ADDRESS: felt252 = 0x041a78e741e5af4fec34b695679bc6891742439f7afb8484ecd7766661ad02bf;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    //
    // Upgradeable
    //
    
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    impl MIPCollections of IMIPCollections<ContractState> {
        fn deploy_collection(
            self: @ContractState,
            class_hash: ClassHash,
            salt: felt252,
            from_zero: bool,
            constructor_calldata: Array<felt252>
        ) -> ContractAddress {

            let udc_dispatcher = IUniversalDeployerDispatcher {
                contract_address: UDC_ADDRESS.try_into().unwrap(),
            };

            udc_dispatcher.deploy_contract(
                class_hash, salt, false, constructor_calldata.span()
            )
        }
    }
}
