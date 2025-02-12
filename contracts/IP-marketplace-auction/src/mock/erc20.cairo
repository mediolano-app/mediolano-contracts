#[starknet::contract]
mod MyToken {
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::ERC20HooksEmptyImpl;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, recipient: ContractAddress,) {
        let name: ByteArray = "My Token";
        let symbol: ByteArray = "MYT";
        let initial_supply = 100_000_000_u256;

        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}
