#[cfg(test)]
mod test {
    use core::result::ResultTrait;
    use mediolano_core::core::events::*;
    use mediolano_core::core::interface::{IMedialaneDispatcher, IMedialaneDispatcherTrait};
    use mediolano_core::core::medialane::Medialane;
    use mediolano_core::core::types::*;
    use mediolano_core::core::utils::*;
    use mediolano_core::mocks::erc1155::{IMockERC1155Dispatcher, IMockERC1155DispatcherTrait};
    use mediolano_core::mocks::erc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};
    use mediolano_core::mocks::erc721::{IMockERC721Dispatcher, IMockERC721DispatcherTrait};
    use openzeppelin_account::interface::AccountABIDispatcher;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use snforge_std::{
        CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
        cheat_caller_address, declare, spy_events, start_cheat_block_timestamp,
        stop_cheat_block_timestamp,
    };
    use starknet::{ContractAddress, get_block_timestamp};

    fn erc20_erc721_signature() -> Array<felt252> {
        array![
            3454928433868771987793737319591141299303880296339125482430761070816410607020,
            1687957968351732802669593318187197490044820175724885527288686545380842475828,
        ]
    }

    fn erc20_erc721_fulfilment_signature() -> Array<felt252> {
        array![
            3153762219456228275540139167487013577360679603422098242184045521620900787267,
            1775594892691740465900712693775684609458245052498958467425546734232892735538,
        ]
    }

    fn erc20_erc721_cancel_signature() -> Array<felt252> {
        array![
            3428666881081820239052350035163331228699955344013335388546792595001053179231,
            641750449764461143285733112189243315208147935584282455090309799624730568160,
        ]
    }

    fn invalid_signature() -> Array<felt252> {
        array![
            3153762219456228275540139167487013577360679603422098242184045521620900787267,
            641750449764461143285733112189243315208147935584282455090309799624730568160,
        ]
    }

    const OWNER_ADDRESS: felt252 = 0x1001;
    const NFT_TOKEN_ID: felt252 = 0;
    const ERC20_AMOUNT: felt252 = 1000000;

    #[derive(Clone, Drop)]
    struct DeployedContracts {
        medialane: IMedialaneDispatcher,
        erc20: IMockERC20Dispatcher,
        erc721: IMockERC721Dispatcher,
        erc1155: IMockERC1155Dispatcher,
    }

    #[derive(Clone, Drop, Debug)]
    struct Accounts {
        owner: ContractAddress,
        offerer: ContractAddress,
        fulfiller: ContractAddress,
        recipient: ContractAddress,
    }

    fn setup_accounts() -> Accounts {
        let offerer_pub_key: ContractAddress =
            0x05c9bc4f9800eef3186980708ecedee4f056a4542abd7a24713b07680eda4346
            .try_into()
            .unwrap();

        let offerer_address: ContractAddress =
            0x040204472aef47d0aa8d68316e773f09a6f7d8d10ff6d30363b353ef3f2d1305
            .try_into()
            .unwrap();
        let offerer = deploy_account(offerer_pub_key, offerer_address);

        let fulfiller_pub_key: ContractAddress =
            0x0349afcb9441c4a8ab36d0d04e671479f78c5df5812ec8e5ddec4742d2bb2bec
            .try_into()
            .unwrap();
        let fulfiller_address: ContractAddress =
            0x01d0c57c28e34bf6407c2fbfadbda7ae59d39ff9c8f9ac4ec3fa32ec784fb549
            .try_into()
            .unwrap();
        let fulfiller = deploy_account(fulfiller_pub_key, fulfiller_address);

        Accounts {
            owner: OWNER_ADDRESS.try_into().unwrap(),
            offerer: offerer.contract_address,
            fulfiller: fulfiller.contract_address,
            recipient: offerer.contract_address,
        }
    }

    fn deploy_contract(
        contract_name: ByteArray, calldata: @Array<felt252>, contract_address: ContractAddress,
    ) -> ContractAddress {
        let contract = declare(contract_name).unwrap().contract_class();
        let (contract_address, _) = contract.deploy_at(calldata, contract_address).unwrap();
        contract_address
    }

    fn deploy_medialane(
        native_token: ContractAddress, owner_adddress: ContractAddress,
    ) -> IMedialaneDispatcher {
        let expected_medialane_contract: ContractAddress =
            0x2a0626d1a71fab6c6cdcb262afc48bff92a6844700ebbd16297596e6c53da29
            .try_into()
            .unwrap();

        let mut constructor_calldata = array![];
        owner_adddress.serialize(ref constructor_calldata);
        native_token.serialize(ref constructor_calldata);
        let contract_address = deploy_contract(
            "Medialane", @constructor_calldata, expected_medialane_contract,
        );
        IMedialaneDispatcher { contract_address }
    }

    fn deploy_erc20(owner: ContractAddress) -> IMockERC20Dispatcher {
        let expected_erc20: ContractAddress =
            0x0589edc6e13293530fec9cad58787ed8cff1fce35c3ef80342b7b00651e04d1f
            .try_into()
            .unwrap();

        let mut constructor_calldata = array![];
        owner.serialize(ref constructor_calldata);
        let contract_address = deploy_contract("MockERC20", @constructor_calldata, expected_erc20);

        IMockERC20Dispatcher { contract_address }
    }

    fn deploy_erc721(owner: ContractAddress) -> IMockERC721Dispatcher {
        let expected_erc721: ContractAddress =
            0x01be0d1cd01de34f946a40e8cc305b67ebb13bca8472484b33e408be03de39fe
            .try_into()
            .unwrap();

        let mut constructor_calldata = array![];
        owner.serialize(ref constructor_calldata);
        let contract_address = deploy_contract(
            "MockERC721", @constructor_calldata, expected_erc721,
        );

        IMockERC721Dispatcher { contract_address }
    }
    fn deploy_erc1155(owner: ContractAddress) -> IMockERC1155Dispatcher {
        let expected_erc1155: ContractAddress =
            0x07ca2d381f55b159ea4c80abf84d4343fde9989854a6be2f02585daae7d89d76
            .try_into()
            .unwrap();

        let mut constructor_calldata = array![];
        owner.serialize(ref constructor_calldata);
        let contract_address = deploy_contract(
            "MockERC1155", @constructor_calldata, expected_erc1155,
        );
        IMockERC1155Dispatcher { contract_address }
    }

    fn deploy_account(
        public_key: ContractAddress, account: ContractAddress,
    ) -> AccountABIDispatcher {
        let mut constructor_calldata = array![];
        public_key.serialize(ref constructor_calldata);
        let contract_address = deploy_contract("MockAccount", @constructor_calldata, account);
        AccountABIDispatcher { contract_address }
    }

    fn setup_contracts_and_accounts() -> (DeployedContracts, Accounts) {
        let accounts = setup_accounts();
        let mut erc20_contract = deploy_erc20(accounts.owner);
        let medialane_contract = deploy_medialane(erc20_contract.contract_address, accounts.owner);
        let erc721_contract = deploy_erc721(accounts.owner);
        let erc1155_contract = deploy_erc1155(accounts.owner);

        (
            DeployedContracts {
                medialane: medialane_contract,
                erc20: erc20_contract,
                erc721: erc721_contract,
                erc1155: erc1155_contract,
            },
            accounts,
        )
    }

    fn get_default_order_parameters(
        offerer: ContractAddress,
        offer: OfferItem,
        consideration: ConsiderationItem,
        nonce: felt252,
        salt: felt252,
    ) -> OrderParameters {
        OrderParameters {
            offerer: offerer,
            offer: offer,
            consideration: consideration,
            start_time: 1000000000,
            end_time: 1000003600,
            salt: salt,
            nonce: nonce,
        }
    }

    fn mint_erc20(
        contract: IMockERC20Dispatcher,
        minter: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    ) {
        cheat_caller_address(contract.contract_address, minter, CheatSpan::TargetCalls(1));
        contract.mint_token(recipient, amount);
    }

    fn mint_erc721(
        ref contract: IMockERC721Dispatcher,
        minter: ContractAddress,
        recipient: ContractAddress,
        token_id: u256,
    ) {
        cheat_caller_address(contract.contract_address, minter, CheatSpan::TargetCalls(1));
        contract.mint_token(recipient, token_id);
    }

    fn mint_erc1155(
        contract: IMockERC1155Dispatcher,
        minter: ContractAddress,
        recipient: ContractAddress,
        token_id: u256,
        amount: u256,
    ) {
        cheat_caller_address(contract.contract_address, minter, CheatSpan::TargetCalls(1));
        contract.mint(recipient, token_id, amount, array![].span());
    }

    fn approve_erc20(
        contract: IMockERC20Dispatcher,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
    ) {
        cheat_caller_address(contract.contract_address, owner, CheatSpan::TargetCalls(1));
        contract.approve_token(spender, amount);
    }

    fn approve_erc721(
        contract: IMockERC721Dispatcher,
        owner: ContractAddress,
        spender: ContractAddress,
        token_id: u256,
    ) {
        cheat_caller_address(contract.contract_address, owner, CheatSpan::TargetCalls(1));
        contract.approve_token(spender, token_id);
    }

    fn approve_erc1155(
        contract: IMockERC1155Dispatcher, owner: ContractAddress, spender: ContractAddress,
    ) {
        cheat_caller_address(contract.contract_address, owner, CheatSpan::TargetCalls(1));
        contract.approve(spender, true);
    }

    #[test]
    fn test_register_valid_order() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        mint_erc721(
            ref contracts.erc721, accounts.owner, accounts.offerer, felt_to_u256(NFT_TOKEN_ID),
        );

        approve_erc721(
            contracts.erc721,
            accounts.offerer,
            contracts.medialane.contract_address,
            felt_to_u256(NFT_TOKEN_ID),
        );

        let offer = OfferItem {
            item_type: 'ERC721',
            token: contracts.erc721.contract_address,
            identifier_or_criteria: 0,
            start_amount: 1.into(),
            end_amount: 1.into(),
        };

        let consideration = ConsiderationItem {
            item_type: 'ERC20',
            token: contracts.erc20.contract_address,
            identifier_or_criteria: 0,
            start_amount: 1000000,
            end_amount: 1000000,
            recipient: accounts.offerer,
        };

        let parameters = get_default_order_parameters(accounts.offerer, offer, consideration, 0, 0);

        let order = Order { parameters, signature: erc20_erc721_signature() };

        let mut spy = spy_events();

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.register_order(order);

        let order_hash = contracts.medialane.get_order_hash(parameters, accounts.offerer);

        let order_details = contracts.medialane.get_order_details(order_hash);

        assert_eq!(order_details.offerer, accounts.offerer, "offerer mismatch");
        assert_eq!(order_details.offer, offer, "offer mismatch");
        assert_eq!(order_details.consideration, consideration, "consideration mismatch");
        assert_eq!(order_details.order_status, OrderStatus::Created, "status mismatch");

        spy
            .assert_emitted(
                @array![
                    (
                        contracts.medialane.contract_address,
                        Medialane::Event::OrderCreated(
                            OrderCreated { order_hash: order_hash, offerer: accounts.offerer },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_fulfill_valid_order() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        let Ierc20 = IERC20Dispatcher { contract_address: contracts.erc20.contract_address };
        let Ierc721 = IERC721Dispatcher { contract_address: contracts.erc721.contract_address };

        let offerer_initial_balance = Ierc20.balance_of(accounts.offerer);

        // register
        mint_erc721(
            ref contracts.erc721, accounts.owner, accounts.offerer, felt_to_u256(NFT_TOKEN_ID),
        );

        assert!(Ierc721.owner_of(felt_to_u256(NFT_TOKEN_ID)) == accounts.offerer, "mint error");

        approve_erc721(
            contracts.erc721,
            accounts.offerer,
            contracts.medialane.contract_address,
            felt_to_u256(NFT_TOKEN_ID),
        );

        let offer = OfferItem {
            item_type: 'ERC721',
            token: contracts.erc721.contract_address,
            identifier_or_criteria: NFT_TOKEN_ID,
            start_amount: 1.into(),
            end_amount: 1.into(),
        };

        let consideration = ConsiderationItem {
            item_type: 'ERC20',
            token: contracts.erc20.contract_address,
            identifier_or_criteria: 0,
            start_amount: ERC20_AMOUNT,
            end_amount: ERC20_AMOUNT,
            recipient: accounts.offerer,
        };

        let parameters = get_default_order_parameters(accounts.offerer, offer, consideration, 0, 0);

        let order = Order { parameters, signature: erc20_erc721_signature() };

        let mut spy = spy_events();

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.register_order(order);

        let order_hash = contracts.medialane.get_order_hash(parameters, accounts.offerer);

        // fulfill
        let order_fulfillment_intent = OrderFulfillment {
            order_hash, fulfiller: accounts.fulfiller, nonce: 0,
        };

        let fulfillment_request = FulfillmentRequest {
            fulfillment: order_fulfillment_intent, signature: erc20_erc721_fulfilment_signature(),
        };

        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, felt_to_u256(ERC20_AMOUNT));

        approve_erc20(
            contracts.erc20,
            accounts.fulfiller,
            contracts.medialane.contract_address,
            felt_to_u256(ERC20_AMOUNT),
        );

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, 1000000000 + get_block_timestamp() + 100,
        );

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.fulfill_order(fulfillment_request);
        let order_details = contracts.medialane.get_order_details(order_hash);

        assert_eq!(order_details.order_status, OrderStatus::Filled, "status mismatch");
        assert_eq!(order_details.fulfiller, Option::Some(accounts.fulfiller), "fulfiller mismatch");

        // check balances
        let offerer_current_balance = Ierc20.balance_of(accounts.offerer);
        assert_eq!(
            offerer_initial_balance + felt_to_u256(ERC20_AMOUNT),
            offerer_current_balance,
            "offerer balance mismatch",
        );
        assert_eq!(
            Ierc721.owner_of(felt_to_u256(NFT_TOKEN_ID)),
            accounts.fulfiller,
            "fulfiller should own nft",
        );

        spy
            .assert_emitted(
                @array![
                    (
                        contracts.medialane.contract_address,
                        Medialane::Event::OrderFulfilled(
                            OrderFulfilled {
                                order_hash: order_hash,
                                offerer: accounts.offerer,
                                fulfiller: accounts.fulfiller,
                            },
                        ),
                    ),
                ],
            );
        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }


    #[test]
    fn test_cancel_valid_order() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        // register
        mint_erc721(
            ref contracts.erc721, accounts.owner, accounts.offerer, felt_to_u256(NFT_TOKEN_ID),
        );

        let offer = OfferItem {
            item_type: 'ERC721',
            token: contracts.erc721.contract_address,
            identifier_or_criteria: NFT_TOKEN_ID,
            start_amount: 1.into(),
            end_amount: 1.into(),
        };

        let consideration = ConsiderationItem {
            item_type: 'ERC20',
            token: contracts.erc20.contract_address,
            identifier_or_criteria: 0,
            start_amount: ERC20_AMOUNT,
            end_amount: ERC20_AMOUNT,
            recipient: accounts.offerer,
        };

        let parameters = get_default_order_parameters(accounts.offerer, offer, consideration, 0, 0);

        let order = Order { parameters, signature: erc20_erc721_signature() };

        let mut spy = spy_events();

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.register_order(order);

        let order_hash = contracts.medialane.get_order_hash(parameters, accounts.offerer);

        // cancel
        let order_cancelation_intent = OrderCancellation {
            order_hash, offerer: accounts.offerer, nonce: 1,
        };

        let cancelation_request = CancelRequest {
            cancelation: order_cancelation_intent, signature: erc20_erc721_cancel_signature(),
        };

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.cancel_order(cancelation_request);

        let order_details = contracts.medialane.get_order_details(order_hash);

        assert_eq!(order_details.order_status, OrderStatus::Cancelled, "status mismatch");
        spy
            .assert_emitted(
                @array![
                    (
                        contracts.medialane.contract_address,
                        Medialane::Event::OrderCancelled(
                            OrderCancelled { order_hash: order_hash, offerer: accounts.offerer },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: ('Invalid signature',))]
    fn test_register_revert_invalid_signature() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();
        let offer = OfferItem {
            item_type: 'ERC721',
            token: contracts.erc721.contract_address,
            identifier_or_criteria: NFT_TOKEN_ID,
            start_amount: 1.into(),
            end_amount: 1.into(),
        };

        let consideration = ConsiderationItem {
            item_type: 'ERC20',
            token: contracts.erc20.contract_address,
            identifier_or_criteria: 0,
            start_amount: ERC20_AMOUNT,
            end_amount: ERC20_AMOUNT,
            recipient: accounts.offerer,
        };

        let parameters = get_default_order_parameters(accounts.offerer, offer, consideration, 0, 0);

        let order_with_invalid_sig = Order { parameters, signature: invalid_signature() };

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.register_order(order_with_invalid_sig);
    }


    #[test]
    #[should_panic(expected: ('Invalid signature',))]
    fn test_fulfill_revert_invalid_signature() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        // register
        mint_erc721(
            ref contracts.erc721, accounts.owner, accounts.offerer, felt_to_u256(NFT_TOKEN_ID),
        );

        let offer = OfferItem {
            item_type: 'ERC721',
            token: contracts.erc721.contract_address,
            identifier_or_criteria: NFT_TOKEN_ID,
            start_amount: 1.into(),
            end_amount: 1.into(),
        };

        let consideration = ConsiderationItem {
            item_type: 'ERC20',
            token: contracts.erc20.contract_address,
            identifier_or_criteria: 0,
            start_amount: ERC20_AMOUNT,
            end_amount: ERC20_AMOUNT,
            recipient: accounts.offerer,
        };

        let parameters = get_default_order_parameters(accounts.offerer, offer, consideration, 0, 0);

        let order = Order { parameters, signature: erc20_erc721_signature() };

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.register_order(order);

        let order_hash = contracts.medialane.get_order_hash(parameters, accounts.offerer);

        // fulfill
        let order_fulfillment_intent = OrderFulfillment {
            order_hash, fulfiller: accounts.fulfiller, nonce: 0,
        };

        let fulfillment_request_with_invalid_signature = FulfillmentRequest {
            fulfillment: order_fulfillment_intent, signature: invalid_signature(),
        };

        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, felt_to_u256(ERC20_AMOUNT));

        approve_erc20(
            contracts.erc20,
            accounts.fulfiller,
            contracts.medialane.contract_address,
            felt_to_u256(ERC20_AMOUNT),
        );

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, 1000000000 + get_block_timestamp() + 100,
        );

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.fulfill_order(fulfillment_request_with_invalid_signature);
    }
    #[test]
    #[should_panic(expected: ('Order expired',))]
    fn test_fulfill_revert_expired() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        // register
        mint_erc721(
            ref contracts.erc721, accounts.owner, accounts.offerer, felt_to_u256(NFT_TOKEN_ID),
        );

        let offer = OfferItem {
            item_type: 'ERC721',
            token: contracts.erc721.contract_address,
            identifier_or_criteria: NFT_TOKEN_ID,
            start_amount: 1.into(),
            end_amount: 1.into(),
        };

        let consideration = ConsiderationItem {
            item_type: 'ERC20',
            token: contracts.erc20.contract_address,
            identifier_or_criteria: 0,
            start_amount: ERC20_AMOUNT,
            end_amount: ERC20_AMOUNT,
            recipient: accounts.offerer,
        };

        let parameters = get_default_order_parameters(accounts.offerer, offer, consideration, 0, 0);

        let order = Order { parameters, signature: erc20_erc721_signature() };

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.register_order(order);

        let order_hash = contracts.medialane.get_order_hash(parameters, accounts.offerer);

        // fulfill
        let order_fulfillment_intent = OrderFulfillment {
            order_hash, fulfiller: accounts.fulfiller, nonce: 0,
        };

        let fulfillment_request = FulfillmentRequest {
            fulfillment: order_fulfillment_intent, signature: erc20_erc721_fulfilment_signature(),
        };

        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, felt_to_u256(ERC20_AMOUNT));

        approve_erc20(
            contracts.erc20,
            accounts.fulfiller,
            contracts.medialane.contract_address,
            felt_to_u256(ERC20_AMOUNT),
        );

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, 1000003600 + get_block_timestamp() + 100,
        );

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.fulfill_order(fulfillment_request);
    }
    #[test]
    #[should_panic(expected: ('Order not yet valid',))]
    fn test_fulfill_revert_not_yet_valid() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        // register
        mint_erc721(
            ref contracts.erc721, accounts.owner, accounts.offerer, felt_to_u256(NFT_TOKEN_ID),
        );

        let offer = OfferItem {
            item_type: 'ERC721',
            token: contracts.erc721.contract_address,
            identifier_or_criteria: NFT_TOKEN_ID,
            start_amount: 1.into(),
            end_amount: 1.into(),
        };

        let consideration = ConsiderationItem {
            item_type: 'ERC20',
            token: contracts.erc20.contract_address,
            identifier_or_criteria: 0,
            start_amount: ERC20_AMOUNT,
            end_amount: ERC20_AMOUNT,
            recipient: accounts.offerer,
        };

        let parameters = get_default_order_parameters(accounts.offerer, offer, consideration, 0, 0);

        let order = Order { parameters, signature: erc20_erc721_signature() };

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.register_order(order);

        let order_hash = contracts.medialane.get_order_hash(parameters, accounts.offerer);

        // fulfill
        let order_fulfillment_intent = OrderFulfillment {
            order_hash, fulfiller: accounts.fulfiller, nonce: 0,
        };

        let fulfillment_request = FulfillmentRequest {
            fulfillment: order_fulfillment_intent, signature: erc20_erc721_fulfilment_signature(),
        };

        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, felt_to_u256(ERC20_AMOUNT));

        approve_erc20(
            contracts.erc20,
            accounts.fulfiller,
            contracts.medialane.contract_address,
            felt_to_u256(ERC20_AMOUNT),
        );

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, get_block_timestamp() + 100,
        );

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.fulfill_order(fulfillment_request);
    }

    #[test]
    #[should_panic(expected: ('Order already filled',))]
    fn test_fulfill_revert_already_filled() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        // register
        mint_erc721(
            ref contracts.erc721, accounts.owner, accounts.offerer, felt_to_u256(NFT_TOKEN_ID),
        );

        approve_erc721(
            contracts.erc721,
            accounts.offerer,
            contracts.medialane.contract_address,
            felt_to_u256(NFT_TOKEN_ID),
        );

        let offer = OfferItem {
            item_type: 'ERC721',
            token: contracts.erc721.contract_address,
            identifier_or_criteria: NFT_TOKEN_ID,
            start_amount: 1.into(),
            end_amount: 1.into(),
        };

        let consideration = ConsiderationItem {
            item_type: 'ERC20',
            token: contracts.erc20.contract_address,
            identifier_or_criteria: 0,
            start_amount: ERC20_AMOUNT,
            end_amount: ERC20_AMOUNT,
            recipient: accounts.offerer,
        };

        let parameters = get_default_order_parameters(accounts.offerer, offer, consideration, 0, 0);

        let order = Order { parameters, signature: erc20_erc721_signature() };

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.register_order(order);

        let order_hash = contracts.medialane.get_order_hash(parameters, accounts.offerer);

        // fulfill
        let order_fulfillment_intent = OrderFulfillment {
            order_hash, fulfiller: accounts.fulfiller, nonce: 0,
        };

        let fulfillment_request_1 = FulfillmentRequest {
            fulfillment: order_fulfillment_intent, signature: erc20_erc721_fulfilment_signature(),
        };

        let fulfillment_request_2 = FulfillmentRequest {
            fulfillment: order_fulfillment_intent, signature: erc20_erc721_fulfilment_signature(),
        };

        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, felt_to_u256(ERC20_AMOUNT));

        approve_erc20(
            contracts.erc20,
            accounts.fulfiller,
            contracts.medialane.contract_address,
            felt_to_u256(ERC20_AMOUNT),
        );

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, 1000000000 + get_block_timestamp() + 100,
        );

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(2),
        );

        contracts.medialane.fulfill_order(fulfillment_request_1);

        contracts.medialane.fulfill_order(fulfillment_request_2);
    }

    #[test]
    #[should_panic(expected: ('Order already filled',))]
    fn test_cancel_revert_already_filled() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        // register
        mint_erc721(
            ref contracts.erc721, accounts.owner, accounts.offerer, felt_to_u256(NFT_TOKEN_ID),
        );

        approve_erc721(
            contracts.erc721,
            accounts.offerer,
            contracts.medialane.contract_address,
            felt_to_u256(NFT_TOKEN_ID),
        );

        let offer = OfferItem {
            item_type: 'ERC721',
            token: contracts.erc721.contract_address,
            identifier_or_criteria: NFT_TOKEN_ID,
            start_amount: 1.into(),
            end_amount: 1.into(),
        };

        let consideration = ConsiderationItem {
            item_type: 'ERC20',
            token: contracts.erc20.contract_address,
            identifier_or_criteria: 0,
            start_amount: ERC20_AMOUNT,
            end_amount: ERC20_AMOUNT,
            recipient: accounts.offerer,
        };

        let parameters = get_default_order_parameters(accounts.offerer, offer, consideration, 0, 0);

        let order = Order { parameters, signature: erc20_erc721_signature() };

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.register_order(order);

        let order_hash = contracts.medialane.get_order_hash(parameters, accounts.offerer);

        // fulfill
        let order_fulfillment_intent = OrderFulfillment {
            order_hash, fulfiller: accounts.fulfiller, nonce: 0,
        };

        let fulfillment_request = FulfillmentRequest {
            fulfillment: order_fulfillment_intent, signature: erc20_erc721_fulfilment_signature(),
        };

        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, felt_to_u256(ERC20_AMOUNT));

        approve_erc20(
            contracts.erc20,
            accounts.fulfiller,
            contracts.medialane.contract_address,
            felt_to_u256(ERC20_AMOUNT),
        );

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, 1000000000 + get_block_timestamp() + 100,
        );

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(2),
        );

        contracts.medialane.fulfill_order(fulfillment_request);

        // cancel
        let order_cancelation_intent = OrderCancellation {
            order_hash, offerer: accounts.offerer, nonce: 1,
        };

        let cancelation_request = CancelRequest {
            cancelation: order_cancelation_intent, signature: erc20_erc721_cancel_signature(),
        };

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.cancel_order(cancelation_request);

        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }
}

