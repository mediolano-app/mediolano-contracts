#[starknet::contract]
mod IPDrop {
    use core::num::traits::Zero;
    use ip_drop::interface::{ClaimConditions, IIPDrop, TokenOwnership};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl ReentrancyGuardInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // ERC721A storage
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        current_index: u256,
        max_supply: u256,
        // Token ownership packed storage (ERC721A optimization)
        packed_ownerships: Map<u256, TokenOwnership>,
        packed_address_data: Map<ContractAddress, u256>, // balance
        // Approvals
        token_approvals: Map<u256, ContractAddress>,
        operator_approvals: Map<(ContractAddress, ContractAddress), bool>,
        // IP Drop specific storage
        claim_conditions: ClaimConditions,
        claimed_by_wallet: Map<ContractAddress, u256>,
        // Allowlist storage
        allowlist: Map<ContractAddress, bool>,
        allowlist_enabled: bool,
        // Payment tracking
        total_payments_received: u256,
        // Component storage
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        ApprovalForAll: ApprovalForAll,
        TokensClaimed: TokensClaimed,
        ClaimConditionsUpdated: ClaimConditionsUpdated,
        AllowlistUpdated: AllowlistUpdated,
        PaymentReceived: PaymentReceived,
        PaymentsWithdrawn: PaymentsWithdrawn,
        BaseURIUpdated: BaseURIUpdated,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        approved: ContractAddress,
        #[key]
        token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        #[key]
        owner: ContractAddress,
        #[key]
        operator: ContractAddress,
        approved: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensClaimed {
        #[key]
        claimer: ContractAddress,
        quantity: u256,
        start_token_id: u256,
        total_paid: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ClaimConditionsUpdated {
        conditions: ClaimConditions,
    }

    #[derive(Drop, starknet::Event)]
    struct AllowlistUpdated {
        #[key]
        user: ContractAddress,
        allowed: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct PaymentReceived {
        #[key]
        from: ContractAddress,
        amount: u256,
        token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct PaymentsWithdrawn {
        #[key]
        to: ContractAddress,
        amount: u256,
        token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct BaseURIUpdated {
        new_base_uri: ByteArray,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        max_supply: u256,
        owner: ContractAddress,
        initial_conditions: ClaimConditions,
        allowlist_enabled: bool,
    ) {
        // Initialize basic contract data
        self.name.write(name);
        self.symbol.write(symbol);
        self.base_uri.write(base_uri);
        self.max_supply.write(max_supply);
        self.current_index.write(1); // Start from token ID 1

        self.claim_conditions.write(initial_conditions);
        self.allowlist_enabled.write(allowlist_enabled);

        // Initialize components
        self.ownable.initializer(owner);

        // Initialize payment tracking
        self.total_payments_received.write(0);
    }

    #[abi(embed_v0)]
    impl IPDropImpl of IIPDrop<ContractState> {
        // ==================== ERC721 STANDARD FUNCTIONS ====================

        fn name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            assert(self._exists(token_id), 'Token does not exist');
            let base_uri = self.base_uri.read();
            format!("{}{}", base_uri, token_id)
        }

        fn balance_of(self: @ContractState, owner: ContractAddress) -> u256 {
            assert(!owner.is_zero(), 'Invalid owner address');
            self._get_current_balance(owner)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self._owner_of_token(token_id)
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), 'Token does not exist');
            self.token_approvals.entry(token_id).read()
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress,
        ) -> bool {
            self.operator_approvals.entry((owner, operator)).read()
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of_token(token_id);
            assert(to != owner, 'Approval to current owner');

            let caller = get_caller_address();
            assert(
                caller == owner || self.is_approved_for_all(owner, caller),
                'Not owner nor approved',
            );

            self._approve(to, token_id, Option::Some(owner));
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool,
        ) {
            let caller = get_caller_address();
            assert(operator != caller, 'Approve to caller');

            self.operator_approvals.entry((caller, operator)).write(approved);
            self.emit(ApprovalForAll { owner: caller, operator, approved });
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            self._transfer(from, to, token_id);
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>,
        ) {
            self._transfer(from, to, token_id);
            // Note: Safe transfer receiver check would be implemented here for full compatibility
        }

        // ==================== IP DROP CLAIM FUNCTIONS ====================

        fn claim(ref self: ContractState, quantity: u256) {
            self.reentrancy_guard.start();

            let caller = get_caller_address();
            self._validate_claim(caller, quantity);

            let conditions = self.claim_conditions.read();
            assert(conditions.price == 0, 'Payment required');

            self._execute_claim(caller, quantity, 0);
            self.reentrancy_guard.end();
        }

        fn claim_with_payment(ref self: ContractState, quantity: u256) {
            self.reentrancy_guard.start();

            let caller = get_caller_address();
            self._validate_claim(caller, quantity);

            let conditions = self.claim_conditions.read();
            let total_cost = conditions.price * quantity;

            assert(total_cost > 0, 'No payment required - use claim');

            // Handle payment
            if (!conditions.payment_token.is_zero()) {
                // ERC20 payment
                let token = IERC20Dispatcher { contract_address: conditions.payment_token };
                let success = token.transfer_from(caller, get_contract_address(), total_cost);
                assert(success, 'Payment transfer failed');

                self
                    .emit(
                        PaymentReceived {
                            from: caller, amount: total_cost, token: conditions.payment_token,
                        },
                    );
            }

            // Track total payments
            let current_total = self.total_payments_received.read();
            self.total_payments_received.write(current_total + total_cost);

            self._execute_claim(caller, quantity, total_cost);
            self.reentrancy_guard.end();
        }

        // ==================== ADMIN FUNCTIONS ====================

        fn set_claim_conditions(ref self: ContractState, conditions: ClaimConditions) {
            self.ownable.assert_only_owner();

            // Validate conditions
            assert(conditions.start_time < conditions.end_time, 'Invalid time range');
            assert(conditions.max_quantity_per_wallet > 0, 'Invalid max quantity');

            self.claim_conditions.write(conditions);
            self.emit(ClaimConditionsUpdated { conditions });
        }

        fn add_to_allowlist(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(!address.is_zero(), 'Invalid address');

            self.allowlist.entry(address).write(true);
            self.emit(AllowlistUpdated { user: address, allowed: true });
        }

        fn add_batch_to_allowlist(ref self: ContractState, addresses: Span<ContractAddress>) {
            self.ownable.assert_only_owner();

            let mut i = 0;
            loop {
                if i >= addresses.len() {
                    break;
                }
                let addr = *addresses.at(i);
                assert(!addr.is_zero(), 'Invalid address in batch');

                self.allowlist.entry(addr).write(true);
                self.emit(AllowlistUpdated { user: addr, allowed: true });
                i += 1;
            };
        }

        fn remove_from_allowlist(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();

            self.allowlist.entry(address).write(false);
            self.emit(AllowlistUpdated { user: address, allowed: false });
        }

        fn set_base_uri(ref self: ContractState, base_uri: ByteArray) {
            self.ownable.assert_only_owner();
            self.base_uri.write(base_uri.clone());
            self.emit(BaseURIUpdated { new_base_uri: base_uri });
        }

        fn set_allowlist_enabled(ref self: ContractState, enabled: bool) {
            self.ownable.assert_only_owner();
            self.allowlist_enabled.write(enabled);
        }

        fn withdraw_payments(ref self: ContractState) {
            self.ownable.assert_only_owner();

            let conditions = self.claim_conditions.read();
            let owner = self.ownable.owner();
            let total_to_withdraw = self.total_payments_received.read();

            assert(total_to_withdraw > 0, 'No payments to withdraw');

            if (!conditions.payment_token.is_zero()) {
                // Withdraw ERC20 tokens
                let token = IERC20Dispatcher { contract_address: conditions.payment_token };
                let success = token.transfer(owner, total_to_withdraw);
                assert(success, 'Withdrawal failed');

                self
                    .emit(
                        PaymentsWithdrawn {
                            to: owner, amount: total_to_withdraw, token: conditions.payment_token,
                        },
                    );
            }

            self.total_payments_received.write(0);
        }

        // ==================== VIEW FUNCTIONS ====================

        fn total_supply(self: @ContractState) -> u256 {
            let current = self.current_index.read();
            if current == 0 {
                0
            } else {
                current - 1
            }
        }

        fn max_supply(self: @ContractState) -> u256 {
            self.max_supply.read()
        }

        fn get_claim_conditions(self: @ContractState) -> ClaimConditions {
            self.claim_conditions.read()
        }

        fn is_allowlisted(self: @ContractState, address: ContractAddress) -> bool {
            if (!self.allowlist_enabled.read()) {
                return true; // Public mint when allowlist disabled
            }
            self.allowlist.entry(address).read()
        }

        fn is_allowlist_enabled(self: @ContractState) -> bool {
            self.allowlist_enabled.read()
        }

        fn claimed_by_wallet(self: @ContractState, wallet: ContractAddress) -> u256 {
            self.claimed_by_wallet.entry(wallet).read()
        }
    }

    // ==================== INTERNAL FUNCTIONS ====================

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _validate_claim(self: @ContractState, claimer: ContractAddress, quantity: u256) {
            let conditions = self.claim_conditions.read();
            let current_time = get_block_timestamp();

            // Time validation
            assert(current_time >= conditions.start_time, 'Claim not started');
            assert(current_time <= conditions.end_time, 'Claim ended');

            // Quantity validation
            assert(quantity > 0, 'Invalid quantity');
            let current_supply = self.total_supply();
            assert(current_supply + quantity <= self.max_supply.read(), 'Exceeds max supply');

            // Per-wallet limit validation
            let already_claimed = self.claimed_by_wallet.entry(claimer).read();
            assert(
                already_claimed + quantity <= conditions.max_quantity_per_wallet,
                'Exceeds wallet limit',
            );

            // Allowlist validation
            if (self.allowlist_enabled.read()) {
                assert(self.allowlist.entry(claimer).read(), 'Not on allowlist');
            }
        }

        fn _execute_claim(
            ref self: ContractState, claimer: ContractAddress, quantity: u256, total_paid: u256,
        ) {
            let start_token_id = self.current_index.read();

            // Update claimed amount for wallet
            let already_claimed = self.claimed_by_wallet.entry(claimer).read();
            self.claimed_by_wallet.entry(claimer).write(already_claimed + quantity);

            // Batch mint
            self._mint_batch(claimer, quantity);

            self.emit(TokensClaimed { claimer, quantity, start_token_id, total_paid });
        }

        fn _mint_batch(ref self: ContractState, to: ContractAddress, quantity: u256) {
            let start_token_id = self.current_index.read();
            let end_token_id = start_token_id + quantity;

            // Update balance
            let current_balance = self._number_minted(to);
            self.packed_address_data.entry(to).write(current_balance + quantity);

            // Set ownership for the batch
            self
                .packed_ownerships
                .entry(start_token_id)
                .write(TokenOwnership { addr: to, start_timestamp: get_block_timestamp() });

            // Emit transfer events for each token
            let mut token_id = start_token_id;
            loop {
                if (token_id >= end_token_id) {
                    break;
                }
                self.emit(Transfer { from: 0.try_into().unwrap(), to, token_id });
                token_id += 1;
            }

            // Update current index
            self.current_index.write(end_token_id);
        }

        fn _exists(self: @ContractState, token_id: u256) -> bool {
            token_id > 0 && token_id < self.current_index.read()
        }

        fn _owner_of_token(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), 'Token does not exist');

            // scan backwards to find the owner
            let mut curr = token_id;
            loop {
                let ownership = self.packed_ownerships.entry(curr).read();
                if (!ownership.addr.is_zero()) {
                    break ownership.addr;
                }
                assert(curr > 0, 'nonexistent token');
                curr -= 1;
            }
        }

        fn _number_minted(self: @ContractState, owner: ContractAddress) -> u256 {
            self.packed_address_data.entry(owner).read()
        }

        fn _approve(
            ref self: ContractState,
            to: ContractAddress,
            token_id: u256,
            owner: Option<ContractAddress>,
        ) {
            self.token_approvals.entry(token_id).write(to);
            let token_owner = match owner {
                Option::Some(addr) => addr,
                Option::None => self._owner_of_token(token_id),
            };
            self.emit(Approval { owner: token_owner, approved: to, token_id });
        }

        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            assert(self._owner_of_token(token_id) == from, 'Not token owner');
            assert(!to.is_zero(), 'Transfer to zero address');

            let caller = get_caller_address();
            assert(
                caller == from
                    || self.get_approved(token_id) == caller
                    || self.is_approved_for_all(from, caller),
                'Not authorized',
            );

            // Clear approval
            self._approve(0.try_into().unwrap(), token_id, Option::Some(from));

            // If this token doesn't have explicit ownership set, we need to set it
            let current_ownership = self.packed_ownerships.entry(token_id).read();
            if current_ownership.addr.is_zero() {
                // This token's ownership was inherited, so set it explicitly
                self
                    .packed_ownerships
                    .entry(token_id)
                    .write(TokenOwnership { addr: from, start_timestamp: get_block_timestamp() });
            }

            // Set ownership for the next token if it exists and doesn't have explicit ownership
            let next_token_id = token_id + 1;
            if next_token_id < self.current_index.read() {
                let next_ownership = self.packed_ownerships.entry(next_token_id).read();
                if next_ownership.addr.is_zero() {
                    // Next token doesn't have explicit ownership, so it was inheriting from this
                    // token We need to set it explicitly to maintain the chain
                    self
                        .packed_ownerships
                        .entry(next_token_id)
                        .write(
                            TokenOwnership { addr: from, start_timestamp: get_block_timestamp() },
                        );
                }
            }

            // Update balances
            let from_balance = self._get_current_balance(from);
            let to_balance = self._get_current_balance(to);
            self.packed_address_data.entry(from).write(from_balance - 1);
            self.packed_address_data.entry(to).write(to_balance + 1);

            // Set ownership for the transferred token
            self
                .packed_ownerships
                .entry(token_id)
                .write(TokenOwnership { addr: to, start_timestamp: get_block_timestamp() });

            self.emit(Transfer { from, to, token_id });
        }

        fn _get_current_balance(self: @ContractState, owner: ContractAddress) -> u256 {
            self.packed_address_data.entry(owner).read()
        }
    }
}
