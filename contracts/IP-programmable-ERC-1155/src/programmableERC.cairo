use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC1155<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress, token_id: u256) -> u256;
    fn balance_of_batch(
        self: @TContractState, accounts: Span<ContractAddress>, token_ids: Span<u256>,
    ) -> Span<u256>;
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>,
    );
    fn safe_batch_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>,
    );
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
    fn uri(self: @TContractState, token_id: u256) -> ByteArray;
    fn get_license(self: @TContractState, token_id: u256) -> ByteArray;
    fn list_tokens(self: @TContractState, owner: ContractAddress) -> Span<u256>;
}

#[starknet::contract]
pub mod ERC1155 {
    use starknet::storage::StoragePathEntry;
    use super::IERC1155;
    use core::num::traits::Zero;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TransferSingle: TransferSingle,
        TransferBatch: TransferBatch,
        ApprovalForAll: ApprovalForAll,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferSingle {
        operator: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferBatch {
        operator: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        owner: ContractAddress,
        operator: ContractAddress,
        approved: bool,
    }

    #[storage]
    pub struct Storage {
        /// Balances of tokens for each account.
        pub ERC1155_balances: Map<(u256, ContractAddress), u256>,
        /// Operator approvals for each account.
        pub ERC1155_operator_approvals: Map<(ContractAddress, ContractAddress), bool>,
        /// Metadata URIs for each token.
        pub ERC1155_uri: Map<u256, ByteArray>,
        /// Licensing information for each token.
        pub ERC1155_licenses: Map<u256, ByteArray>,
        /// Number of tokens owned by each account.
        pub ERC1155_owned_tokens: Map<ContractAddress, u256>,
        /// List of token IDs owned by each account.
        pub ERC1155_owned_tokens_list: Map<(ContractAddress, u256), u256>,
        /// Owner of the contract.
        pub owner: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_uri: ByteArray,
        recipient: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
    ) {
        // Set the owner during deployment
        self.owner.write(get_caller_address());

        // Validate inputs
        assert(token_ids.len() == values.len(), 'Arrays length mismatch');
        assert(!recipient.is_zero(), 'Invalid recipient');

        // Initialize metadata for each token
        for i in 0..token_ids.len() {
            self.ERC1155_uri.write(*token_ids.at(i), token_uri.clone());
        };

        // Mint tokens to the recipient
        self
            .batch_mint(
                starknet::contract_address_const::<0>(),
                recipient,
                token_ids,
                values,
                array![].span(),
            );
    }

    #[abi(embed_v0)]
    pub impl ERC1155Impl of super::IERC1155<ContractState> {
        fn balance_of(self: @ContractState, account: ContractAddress, token_id: u256) -> u256 {
            self.ERC1155_balances.read((token_id, account))
        }

        fn balance_of_batch(
            self: @ContractState, accounts: Span<ContractAddress>, token_ids: Span<u256>,
        ) -> Span<u256> {
            assert(accounts.len() == token_ids.len(), 'Arrays length mismatch');
            let mut result = array![];
            for i in 0..accounts.len() {
                let balance = self.ERC1155_balances.read((*token_ids.at(i), *accounts.at(i)));
                result.append(balance);
            };
            result.span()
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress,
        ) -> bool {
            self.ERC1155_operator_approvals.read((owner, operator))
        }

        fn uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.ERC1155_uri.read(token_id)
        }

        fn safe_batch_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>,
        ) {
            // Validate inputs
            assert(token_ids.len() == values.len(), 'Arrays length mismatch');
            assert(!to.is_zero(), 'Invalid recipient');

            // Check authorization
            let caller = get_caller_address();
            assert(
                caller == from || self.ERC1155_operator_approvals.read((from, caller)),
                'Not authorized',
            );

            // Perform batch transfer
            self.batch_mint(from, to, token_ids, values, data);

            // Emit event
            self.emit(TransferBatch { operator: caller, from, to, token_ids, values });
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool,
        ) {
            assert(!operator.is_zero(), 'Invalid operator');
            let owner = get_caller_address();
            assert(owner != operator, 'Self approval');

            // Update approvals
            self.ERC1155_operator_approvals.write((owner, operator), approved);

            // Emit event
            self.emit(ApprovalForAll { owner, operator, approved });
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>,
        ) {
            assert(!to.is_zero(), 'Invalid recipient'.into());

            // Check authorization
            let caller = get_caller_address();
            assert(
                caller == from || self.ERC1155_operator_approvals.read((from, caller)),
                'Not authorized'.into(),
            );

            // Perform single transfer
            let token_ids = array![token_id].span();
            let values = array![value].span();
            self.batch_mint(from, to, token_ids, values, data);

            // Emit event
            self.emit(TransferSingle { operator: caller, from, to, token_id, value });
        }

        fn get_license(self: @ContractState, token_id: u256) -> ByteArray {
            self.ERC1155_licenses.read(token_id)
        }

        fn list_tokens(self: @ContractState, owner: ContractAddress) -> Span<u256> {
            let mut result = array![];
            let token_count = self.ERC1155_owned_tokens.read(owner);

            let mut i = 0;
            while i < token_count {
                let token_id = self.ERC1155_owned_tokens_list.read((owner, i));
                result.append(token_id);
                i += 1;
            };
            result.span()
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn batch_mint(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>,
        ) {
            for i in 0..token_ids.len() {
                let token_id = *token_ids.at(i);
                let value = *values.at(i);

                if from.is_non_zero() {
                    let from_balance = self.ERC1155_balances.read((token_id, from));
                    assert(from_balance >= value, 'Insufficient balance'.into());
                    self.ERC1155_balances.write((token_id, from), from_balance - value);

                    // Update ownership for `from`
                    let from_token_count = self.ERC1155_owned_tokens.read(from);
                    if from_token_count > 0 {
                        self.ERC1155_owned_tokens.write(from, from_token_count - 1);
                    }
                }

                let to_balance = self.ERC1155_balances.read((token_id, to));
                self.ERC1155_balances.write((token_id, to), to_balance + value);

                // Update ownership for `to`
                let to_token_count = self.ERC1155_owned_tokens.read(to);
                self.ERC1155_owned_tokens.write(to, to_token_count + 1);
                self.ERC1155_owned_tokens_list.write((to, to_token_count), token_id);
            }
        }
    }
}
