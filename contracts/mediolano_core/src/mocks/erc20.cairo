use starknet::ContractAddress;

// https://wizard.openzeppelin.com/cairo#erc20
#[starknet::contract]
pub mod MockERC20 {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use super::*;
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // External
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc20.initializer("MyToken", "MTK");
        self.ownable.initializer(owner);
    }

    pub impl MockERC20Impl of super::IMockERC20<ContractState> {
        #[external(v0)]
        fn mint(ref self: ContractState, recepient: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self.erc20.mint(recepient, amount);
        }
        #[external(v0)]
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            self.erc20.approve(spender, amount);
        }
        #[external(v0)]
        fn balance_of(ref self: ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }
    }
}

#[starknet::interface]
pub trait IMockERC20<TContractState> {
    fn mint(ref self: TContractState, recepient: ContractAddress, amount: u256);
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn balance_of(ref self: TContractState, account: ContractAddress) -> u256;
}