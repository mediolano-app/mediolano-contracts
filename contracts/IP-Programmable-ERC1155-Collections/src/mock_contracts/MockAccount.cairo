/// Minimal account contract mock for testing.
/// Implements ISRC6 (Starknet account interface) so it passes
/// `mint_with_acceptance_check` when used as a recipient.
/// Must use `#[starknet::contract(account)]` to allow __validate__/__execute__.
#[starknet::contract(account)]
pub mod MockAccount {
    use openzeppelin::account::AccountComponent;
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // AccountMixinImpl already embeds SRC5 — do NOT re-embed SRC5Impl separately.
    #[abi(embed_v0)]
    impl AccountMixinImpl = AccountComponent::AccountMixinImpl<ContractState>;
    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: AccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccountEvent: AccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
    }
}
