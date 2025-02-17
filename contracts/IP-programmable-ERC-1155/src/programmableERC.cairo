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

    #[storage]
    pub struct Storage {
        pub ERC1155_balances: Map<(u256, ContractAddress), u256>,
        pub ERC1155_operator_approvals: Map<(ContractAddress, ContractAddress), bool>,
        pub ERC1155_uri: Map<u256, ByteArray>,
        pub ERC1155_licenses: Map<u256, ByteArray>,
        pub ERC1155_owned_tokens: Map<ContractAddress, u256>, // Store token count
        pub ERC1155_owned_tokens_list: Map<
            (ContractAddress, u256), u256,
        > // Store token IDs sequentially
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_uri: ByteArray,
        recipient: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
    ) {
        for i in 0..token_ids.len() {
            self.ERC1155_uri.write(*token_ids.at(i), token_uri.clone());
        };
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
        fn safe_batch_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>,
        ) {
            self.batch_mint(from, to, token_ids, values, data);
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress,
        ) -> bool {
            self.ERC1155_operator_approvals.read((owner, operator))
        }

        fn uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.ERC1155_uri.read(token_id)
        }
        fn balance_of(self: @ContractState, account: ContractAddress, token_id: u256) -> u256 {
            self.ERC1155_balances.read((token_id, account))
        }

        fn balance_of_batch(
            self: @ContractState, accounts: Span<ContractAddress>, token_ids: Span<u256>,
        ) -> Span<u256> {
            let mut batch_balances = array![];
            for i in 0..token_ids.len() {
                batch_balances.append(self.balance_of(*accounts.at(i), *token_ids.at(i)));
            };
            batch_balances.span()
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool,
        ) {
            let owner = get_caller_address();
            self.ERC1155_operator_approvals.write((owner, operator), approved);
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>,
        ) {
            let token_ids = array![token_id].span();
            let values = array![value].span();
            self.safe_batch_transfer_from(from, to, token_ids, values, data);
        }

        fn get_license(self: @ContractState, token_id: u256) -> ByteArray {
            self.ERC1155_licenses.read(token_id)
        }

        fn list_tokens(self: @ContractState, owner: ContractAddress) -> Span<u256> {
            let mut result = array![];
            let token_count = self.ERC1155_owned_tokens.read(owner); // Read number of tokens

            let mut i = 0;
            while i < token_count {
                let token_id = self
                    .ERC1155_owned_tokens_list
                    .read((owner, i)); // Read stored token ID
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
                    self.ERC1155_balances.write((token_id, from), from_balance - value);
                }
                let to_balance = self.ERC1155_balances.read((token_id, to));
                self.ERC1155_balances.write((token_id, to), to_balance + value);
            }
        }
    }
}
