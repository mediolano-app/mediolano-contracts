#[starknet::contract]
pub mod IPMarketplace {
    use super::super::interfaces::IIPTokenizerDispatcherTrait;
    use openzeppelin_token::erc20::interface::IERC20DispatcherTrait;
    use core::{
        array::ArrayTrait, traits::{Into}, box::BoxTrait, option::OptionTrait,
        starknet::{
            ContractAddress,
            storage::{
                StoragePointerWriteAccess, StoragePointerReadAccess, StorageMapReadAccess,
                StorageMapWriteAccess, Map
            }
        },
    };
    use super::super::interfaces::IIPMarketplace;
    use starknet::{get_caller_address};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::interface::IERC20;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use ip_marketplace_bulk_order::interfaces::{IIPTokenizerDispatcher};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    use OwnableComponent::InternalTrait;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    use super::super::interfaces::{IIPTokenizer};

    // Constants
    const COMMISSION_FEE_PERCENTAGE: u64 = 5; // 5% commission fee
    const ERROR_INVALID_PAYMENT: felt252 = 'Invalid payment amount';
    const ERROR_INVALID_ASSET: felt252 = 'Invalid asset';
    const ERROR_TRANSFER_FAILED: felt252 = 'Transfer failed';

    #[storage]
    struct Storage {
        tokenizer_contract: ContractAddress,
        accepted_token: ContractAddress, // ETH or STRK token address
        commission_wallet: ContractAddress, // Mediolano.app commission wallet
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        BulkPurchaseCompleted: BulkPurchaseCompleted,
        PaymentProcessed: PaymentProcessed,
    }

    #[derive(Drop, starknet::Event)]
    struct BulkPurchaseCompleted {
        buyer: ContractAddress,
        asset_ids: Array<u256>,
        total_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PaymentProcessed {
        seller: ContractAddress,
        amount: u256,
        commission: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        tokenizer_contract: ContractAddress,
        accepted_token: ContractAddress,
        commission_wallet: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.tokenizer_contract.write(tokenizer_contract);
        self.accepted_token.write(accepted_token);
        self.commission_wallet.write(commission_wallet);
    }

    #[abi(embed_v0)]
    impl IPMarketplaceImpl of IIPMarketplace<ContractState> {
        fn bulk_purchase(ref self: ContractState, asset_ids: Array<u256>, total_amount: u256,) {
            self.pausable.assert_not_paused();

            // Validate payment amount
            assert(total_amount > 0, ERROR_INVALID_PAYMENT);

            // Get tokenizer contract
            let tokenizer = IIPTokenizerDispatcher {
                contract_address: self.tokenizer_contract.read()
            };

            // Calculate commission and distribute payments
            let commission = (total_amount * COMMISSION_FEE_PERCENTAGE.into()) / 100;
            let amount_to_distribute = total_amount - commission;

            // Transfer commission to Mediolano.app
            self._transfer_funds(self.commission_wallet.read(), commission);

            // Distribute payments to sellers
            let mut i: u32 = 0;
            let asset_count = asset_ids.len();
            loop {
                if i >= asset_count {
                    break;
                }

                let asset_id = asset_ids.get(i).unwrap().unbox();
                let asset_data = tokenizer.get_token_metadata(*asset_id);
                let seller = asset_data.owner;

                // Transfer payment to seller
                self._transfer_funds(seller, amount_to_distribute / asset_count.into());

                i += 1;
            };

            // Emit events
            self
                .emit(
                    BulkPurchaseCompleted { buyer: get_caller_address(), asset_ids, total_amount }
                );
        }

        fn set_accepted_token(ref self: ContractState, token_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.accepted_token.write(token_address);
        }

        fn set_commission_wallet(ref self: ContractState, wallet_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.commission_wallet.write(wallet_address);
        }

        fn set_paused(ref self: ContractState, paused: bool) {
            self.ownable.assert_only_owner();
            if paused {
                self.pausable.pause();
            } else {
                self.pausable.unpause();
            }
        }
    }

    #[generate_trait]
    impl Private of PrivateTrait {
        fn _transfer_funds(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let token = IERC20Dispatcher { contract_address: self.accepted_token.read() };
            let caller = get_caller_address();

            // Transfer funds from buyer to recipient
            let success = token.transfer_from(caller, recipient, amount);
            assert(success, ERROR_TRANSFER_FAILED);
        }
    }
}
