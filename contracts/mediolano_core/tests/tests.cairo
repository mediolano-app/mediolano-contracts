//use mediolano_core::mocks::erc20::{IExternalTraitDispatcher as IERC20ExternalTraitDispatcher, IExternalTraitDispatcherTrait as IERC20ExternalTraitDispatcherTrait};
//use mediolano_core::mocks::erc721::{IExternalTraitDispatcher as IERC721ExternalTraitDispatcher, IExternalTraitDispatcherTrait as IERC721ExternalTraitDispatcherTrait};
//use mediolano_core::mocks::erc1155::{IExternalTraitDispatcher as IERC1155ExternalTraitDispatcher, IExternalTraitDispatcherTrait as IERC1155ExternalTraitDispatcherTrait};
use mediolano_core::mocks::erc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};
use mediolano_core::mocks::erc721::{IMockERC721Dispatcher, IMockERC721DispatcherTrait};
use mediolano_core::mocks::erc1155::{IMockERC1155Dispatcher, IMockERC1155DispatcherTrait};
use mediolano_core::Medialane::{
    ConsiderationItem, ItemType, Medialane,
    OfferItem, Order, OrderFillStatus, OrderParameters,
};
use mediolano_core::{IMedialaneDispatcher, IMedialaneDispatcherTrait};
//use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
//use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
//use openzeppelin_token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};

#[cfg(test)]
mod test {
    use super::*;
    //use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use core::result::ResultTrait;
    use core::traits::{Into, TryInto};
    use snforge_std::{
        CheatSpan, ContractClassTrait, DeclareResultTrait, Event, EventSpyAssertionsTrait,
        cheat_block_timestamp, cheat_caller_address, declare,
        spy_events, start_cheat_block_timestamp, stop_cheat_block_timestamp,
        stop_cheat_caller_address,
    };
    use snforge_std::signature::{KeyPair, KeyPairTrait, SignerTrait};
    use snforge_std::signature::stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl};

    use starknet::{
        ContractAddress, EthAddress, contract_address_const,
         get_block_timestamp, get_caller_address,
    };


    const OWNER_ADDRESS: felt252 = 0x1001;
    const OFFERER_ADDRESS: felt252 = 0x2001;
    const FULFILLER_ADDRESS: felt252 = 0x3001;
    const RECIPIENT_ADDRESS: felt252 = 0x4001;
    const ZONE_ADDRESS: felt252 = 0x5001;

    const OFFERER_PK: felt252 = 111;
    const FULFILLER_PK: felt252 = 222;

    const STRK_ADDRESS: felt252 =
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;

    const ONE_HOUR: u64 = 3600;
    const START_TIME_OFFSET: u64 = 100;
    const END_TIME_OFFSET: u64 = ONE_HOUR * 2;

    const NFT_TOKEN_ID: u256 = u256 { low: 1, high: 0 };
    const ERC1155_TOKEN_ID: u256 = u256 { low: 55, high: 0 };
    const ERC20_AMOUNT: u256 = u256 { low: 1_000_000_000_000_000_000_000, high: 0 };
    const ERC1155_AMOUNT: u256 = u256 { low: 10, high: 0 };

    struct DeployedContracts {
        medialane: IMedialaneDispatcher,
        erc20: IMockERC20Dispatcher,
        erc721: IMockERC721Dispatcher,
        erc1155: IMockERC1155Dispatcher,
    }
    #[derive(Clone, Drop)]
    struct Accounts {
        owner: ContractAddress,
        offerer: ContractAddress,
        fulfiller: ContractAddress,
        recipient: ContractAddress,
        zone: ContractAddress,
    }

    fn setup_accounts() -> Accounts {
        Accounts {
            owner: contract_address_const::<OWNER_ADDRESS>(),
            offerer: contract_address_const::<OFFERER_ADDRESS>(),
            fulfiller: contract_address_const::<FULFILLER_ADDRESS>(),
            recipient: contract_address_const::<RECIPIENT_ADDRESS>(),
            zone: contract_address_const::<ZONE_ADDRESS>(),
        }
    }

    fn deploy_contract(contract_name: ByteArray, calldata: @Array<felt252>) -> ContractAddress {
        let contract = declare(contract_name).unwrap().contract_class();
        let (contract_address, _) = contract.deploy(calldata).unwrap();
        contract_address
    }

    fn deploy_medialane() -> IMedialaneDispatcher {
        let constructor_calldata = array![];
        let contract_address = deploy_contract("Medialane", @constructor_calldata);
        IMedialaneDispatcher { contract_address }
    }

     fn deploy_erc20(recipient: ContractAddress) -> IMockERC20Dispatcher {
         let mut constructor_calldata = array![];
         recipient.serialize(ref constructor_calldata);
         // constructor_calldata.append('Mock ERC20'.into());
         // constructor_calldata.append('MERC'.into());
         // constructor_calldata.append(18.into());
         let contract_address = deploy_contract("MockERC20", @constructor_calldata);
         IMockERC20Dispatcher { contract_address }
     }


    fn deploy_erc721(owner: ContractAddress) -> IMockERC721Dispatcher {
        let mut constructor_calldata = array![];
        // constructor_calldata.append('Mock NFT'.into());
        // constructor_calldata.append('MNFT'.into());
        // constructor_calldata.append(owner.into());
        owner.serialize(ref constructor_calldata);
        let contract_address = deploy_contract("MockERC721", @constructor_calldata);
        IMockERC721Dispatcher { contract_address }
    }

    fn deploy_erc1155(owner: ContractAddress) -> IMockERC1155Dispatcher {
        let mut constructor_calldata = array![];
        owner.serialize(ref constructor_calldata);
        //constructor_calldata.append(owner.into());
        let contract_address = deploy_contract("MockERC1155", @constructor_calldata);
        IMockERC1155Dispatcher { contract_address }
    }

    fn setup_contracts_and_accounts() -> (DeployedContracts, Accounts) {
        let accounts = setup_accounts();
        let medialane_contract = deploy_medialane();
        let erc20_contract = deploy_erc20(accounts.owner);
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
        offer: Array<OfferItem>,
        consideration: Array<ConsiderationItem>,
        nonce: u128,
        salt: felt252,
    ) -> OrderParameters {
        let now = get_block_timestamp();
        OrderParameters {
            offerer: offerer,
            offer: offer,
            consideration: consideration,
            start_time: now + START_TIME_OFFSET,
            end_time: now + END_TIME_OFFSET,
            zone: contract_address_const::<0>(),
            zone_hash: 0,
            salt: salt,
            nonce: nonce,
        }
    }

    fn sign_order(
        medialane: IMedialaneDispatcher, parameters: OrderParameters, signer_pk: felt252,
    ) -> Order {
        let key_pair = StarkCurveKeyPairImpl::from_secret_key(signer_pk);
        let order_hash = medialane.get_order_hash(parameters.clone());
        let signature_tuple: (felt252, felt252) = key_pair.sign(order_hash).unwrap();
        let (r, s) = signature_tuple;
        let mut signature_array = array![];
        r.serialize(ref signature_array);
        s.serialize(ref signature_array);
        key_pair.public_key.serialize(ref signature_array);
        Order { parameters, signature: signature_array }
    }

    fn mint_erc20(
        contract: IMockERC20Dispatcher,
        minter: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    ) {
        cheat_caller_address(contract.contract_address, minter, CheatSpan::TargetCalls(1));
        contract.mint(recipient, amount);
    }

    fn mint_erc721(
        ref contract: IMockERC721Dispatcher,
        minter: ContractAddress,
        recipient: ContractAddress,
        token_id: u256,
    ) {
        cheat_caller_address(contract.contract_address, minter, CheatSpan::TargetCalls(1));
        contract.mint(recipient, token_id);
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
        contract: IMockERC20Dispatcher, owner: ContractAddress, spender: ContractAddress, amount: u256,
    ) {
        cheat_caller_address(contract.contract_address, owner, CheatSpan::TargetCalls(1));
        contract.approve(spender, amount);
    }

    fn approve_erc721(
        contract: IMockERC721Dispatcher,
        owner: ContractAddress,
        spender: ContractAddress,
        token_id: u256,
    ) {
        cheat_caller_address(contract.contract_address, owner, CheatSpan::TargetCalls(1));
        // IMockERC721DispatcherTrait::approve(contract, spender, token_id);
        contract.approve(spender, token_id);
    }

    fn approve_erc1155(
        contract: IMockERC1155Dispatcher, owner: ContractAddress, spender: ContractAddress,
    ) {
        cheat_caller_address(contract.contract_address, owner, CheatSpan::TargetCalls(1));
        contract.approve(spender, true);
    }

    #[test]
    fn test_fulfill_erc20_for_erc721_success() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();
        let offerer_start_balance = contracts.erc20.balance_of(accounts.offerer);
        let fulfiller_start_balance = contracts.erc20.balance_of(accounts.fulfiller);

        mint_erc721(ref contracts.erc721, accounts.owner, accounts.offerer, NFT_TOKEN_ID);
        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, ERC20_AMOUNT);

        approve_erc721(
            contracts.erc721, accounts.offerer, contracts.medialane.contract_address, NFT_TOKEN_ID,
        );
        approve_erc20(
            contracts.erc20, accounts.fulfiller, contracts.medialane.contract_address, ERC20_AMOUNT,
        );

        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let nonce: u128 = contracts.medialane.get_nonce(accounts.offerer);
        let salt = 12345;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, nonce, salt,
        );
        let signed_order = sign_order(contracts.medialane, parameters.clone(), OFFERER_PK);
        let order_hash = contracts.medialane.get_order_hash(parameters.clone());

        let valid_time = get_block_timestamp() + START_TIME_OFFSET + 1;
        start_cheat_block_timestamp(contracts.medialane.contract_address, valid_time);

        let mut spy = spy_events();
        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );

        contracts.medialane.fulfill_order(signed_order);
        stop_cheat_block_timestamp(contracts.medialane.contract_address);

        assert_eq!(contracts.erc721.owner_of(NFT_TOKEN_ID), accounts.fulfiller);
        assert_eq!(
            contracts.erc20.balance_of(accounts.offerer), offerer_start_balance + ERC20_AMOUNT,
        );
        assert_eq!(contracts.erc20.balance_of(accounts.fulfiller), fulfiller_start_balance);
        assert_eq!(contracts.medialane.get_order_status(order_hash), OrderFillStatus::Filled);

        spy
            .assert_emitted(
                @array![
                    (
                        contracts.medialane.contract_address,
                        Medialane::Event::OrderFulfilled(
                            Medialane::OrderFulfilled {
                                order_hash: order_hash,
                                offerer: accounts.offerer,
                                fulfiller: accounts.fulfiller,
                                zone: parameters.zone,
                            },
                        ),
                    ),
                ],
            );
    }


    #[test]
    #[should_panic(expected: ('Invalid signature',))]
    fn test_fulfill_revert_invalid_signature() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();
        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let nonce: u128 = contracts.medialane.get_nonce(accounts.offerer);
        let salt = 1;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, nonce, salt,
        );

        let mut order_with_invalid_sig = sign_order(contracts.medialane, parameters, FULFILLER_PK);

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, get_block_timestamp() + START_TIME_OFFSET + 1,
        );
        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.fulfill_order(order_with_invalid_sig);
        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }


    #[test]
    #[should_panic(expected: ('Order expired',))]
    fn test_fulfill_revert_expired() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();
        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let nonce: u128 = contracts.medialane.get_nonce(accounts.offerer);
        let salt = 2;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, nonce, salt,
        );
        let signed_order = sign_order(contracts.medialane, parameters.clone(), OFFERER_PK);

        start_cheat_block_timestamp(contracts.medialane.contract_address, parameters.end_time + 1);

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.fulfill_order(signed_order);
        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }

    #[test]
    #[should_panic(expected: ('Order not yet valid',))]
    fn test_fulfill_revert_not_yet_valid() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();
        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let nonce: u128 = contracts.medialane.get_nonce(accounts.offerer);
        let salt = 3;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, nonce, salt,
        );
        let signed_order = sign_order(contracts.medialane, parameters.clone(), OFFERER_PK);

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, parameters.start_time - 1,
        );

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.fulfill_order(signed_order);
        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }


    #[test]
    #[should_panic(expected: ('Invalid nonce',))]
    fn test_fulfill_revert_invalid_nonce_wrong() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();
        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let current_nonce = contracts.medialane.get_nonce(accounts.offerer);
        let wrong_nonce = current_nonce + 1;
        let salt = 4;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, wrong_nonce, salt,
        );
        let signed_order = sign_order(contracts.medialane, parameters, OFFERER_PK);

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, get_block_timestamp() + START_TIME_OFFSET + 1,
        );
        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.fulfill_order(signed_order);
        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }

    #[test]
    #[should_panic(expected: ('Order already filled',))]
    fn test_fulfill_revert_already_filled() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        mint_erc721(ref contracts.erc721, accounts.owner, accounts.offerer, NFT_TOKEN_ID);
        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, ERC20_AMOUNT);
        approve_erc721(
            contracts.erc721, accounts.offerer, contracts.medialane.contract_address, NFT_TOKEN_ID,
        );
        approve_erc20(
            contracts.erc20, accounts.fulfiller, contracts.medialane.contract_address, ERC20_AMOUNT,
        );
        println!("ERC20: {:x}", contracts.erc20.contract_address);
        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let nonce: u128 = contracts.medialane.get_nonce(accounts.offerer);
        let salt = 5;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, nonce, salt,
        );
        let signed_order = sign_order(contracts.medialane, parameters.clone(), OFFERER_PK);

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, get_block_timestamp() + START_TIME_OFFSET + 1,
        );
        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.fulfill_order(signed_order.clone());

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.fulfill_order(signed_order);
        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }

    #[test]
    #[should_panic(expected: ('Transfer failed',))]
    fn test_fulfill_revert_offerer_insufficient_nft() {
        let (contracts, accounts) = setup_contracts_and_accounts();

        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, ERC20_AMOUNT);
        approve_erc20(
            contracts.erc20, accounts.fulfiller, contracts.medialane.contract_address, ERC20_AMOUNT,
        );

        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let nonce: u128 = contracts.medialane.get_nonce(accounts.offerer);
        let salt = 6;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, nonce, salt,
        );
        let signed_order = sign_order(contracts.medialane, parameters, OFFERER_PK);

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, get_block_timestamp() + START_TIME_OFFSET + 1,
        );
        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.fulfill_order(signed_order);
        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }


    #[test]
    #[should_panic(expected: ('Transfer failed',))]
    fn test_fulfill_revert_fulfiller_insufficient_erc20() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        mint_erc721(ref contracts.erc721, accounts.owner, accounts.offerer, NFT_TOKEN_ID);
        approve_erc721(
            contracts.erc721, accounts.offerer, contracts.medialane.contract_address, NFT_TOKEN_ID,
        );

        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let nonce: u128 = contracts.medialane.get_nonce(accounts.offerer);
        let salt = 7;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, nonce, salt,
        );
        let signed_order = sign_order(contracts.medialane, parameters, OFFERER_PK);

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, get_block_timestamp() + START_TIME_OFFSET + 1,
        );
        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.fulfill_order(signed_order);
        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }


    #[test]
    fn test_cancel_order_success() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let nonce: u128 = contracts.medialane.get_nonce(accounts.offerer);
        let salt = 8;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, nonce, salt,
        );
        let order_hash = contracts.medialane.get_order_hash(parameters.clone());

        assert_eq!(contracts.medialane.get_order_status(order_hash), OrderFillStatus::Unfilled);

        let mut spy = spy_events();
        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.cancel_orders(array![parameters.clone()]);

        assert_eq!(contracts.medialane.get_order_status(order_hash), OrderFillStatus::Cancelled);

        spy
            .assert_emitted(
                @array![
                    (
                        contracts.medialane.contract_address,
                        Medialane::Event::OrderCancelled(
                            Medialane::OrderCancelled {
                                order_hash: order_hash,
                                offerer: accounts.offerer,
                                zone: parameters.zone,
                            },
                        ),
                    ),
                ],
            );
    }


    #[test]
    #[should_panic(expected: ('Caller not offerer',))]
    fn test_cancel_revert_not_offerer() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let nonce: u128 = contracts.medialane.get_nonce(accounts.offerer);
        let salt = 9;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, nonce, salt,
        );

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.cancel_orders(array![parameters]);
    }


    #[test]
    #[should_panic(expected: ('Order already filled',))]
    fn test_cancel_revert_already_filled() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        mint_erc721(ref contracts.erc721, accounts.owner, accounts.offerer, NFT_TOKEN_ID);
        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, ERC20_AMOUNT);
        approve_erc721(
            contracts.erc721, accounts.offerer, contracts.medialane.contract_address, NFT_TOKEN_ID,
        );
        approve_erc20(
            contracts.erc20, accounts.fulfiller, contracts.medialane.contract_address, ERC20_AMOUNT,
        );

        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let nonce = contracts.medialane.get_nonce(accounts.offerer);
        let salt = 10;
        let parameters = get_default_order_parameters(
            accounts.offerer, offer, consideration, nonce, salt,
        );
        let signed_order = sign_order(contracts.medialane, parameters.clone(), OFFERER_PK);

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, get_block_timestamp() + START_TIME_OFFSET + 1,
        );
        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.fulfill_order(signed_order.clone());

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.cancel_orders(array![parameters]);
        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }

    #[test]
    fn test_increment_nonce_success() {
        let (contracts, accounts) = setup_contracts_and_accounts();
        let initial_nonce = contracts.medialane.get_nonce(accounts.offerer);
        assert_eq!(initial_nonce, 0);

        let mut spy = spy_events();

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.increment_nonce();

        let new_nonce = contracts.medialane.get_nonce(accounts.offerer);
        assert_eq!(new_nonce, initial_nonce + 1);

        spy
            .assert_emitted(
                @array![
                    (
                        contracts.medialane.contract_address,
                        Medialane::Event::NonceIncremented(
                            Medialane::NonceIncremented {
                                offerer: accounts.offerer, 
                                new_nonce: new_nonce,
                            },
                        ),
                    ),
                ],
            );
    }


    #[test]
    #[should_panic(expected: ('Invalid nonce',))]
    fn test_fulfill_order_after_nonce_increment() {
        let (mut contracts, accounts) = setup_contracts_and_accounts();

        let offer = array![
            OfferItem {
                item_type: ItemType::ERC721,
                token: contracts.erc721.contract_address,
                identifier_or_criteria: NFT_TOKEN_ID,
                start_amount: 1.into(),
                end_amount: 1.into(),
            },
        ];
        let consideration = array![
            ConsiderationItem {
                item_type: ItemType::ERC20,
                token: contracts.erc20.contract_address,
                identifier_or_criteria: 0,
                start_amount: ERC20_AMOUNT,
                end_amount: ERC20_AMOUNT,
                recipient: accounts.offerer,
            },
        ];
        let initial_nonce = contracts.medialane.get_nonce(accounts.offerer);
        assert_eq!(initial_nonce, 0);
        let salt = 11;
        let parameters_nonce_0 = get_default_order_parameters(
            accounts.offerer, offer.clone(), consideration.clone(), initial_nonce, salt,
        );
        let signed_order_nonce_0 = sign_order(contracts.medialane, parameters_nonce_0, OFFERER_PK);

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.offerer, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.increment_nonce();
        let new_nonce = contracts.medialane.get_nonce(accounts.offerer);
        assert_eq!(new_nonce, initial_nonce + 1);

        start_cheat_block_timestamp(
            contracts.medialane.contract_address, get_block_timestamp() + START_TIME_OFFSET + 1,
        );

        mint_erc721(ref contracts.erc721, accounts.owner, accounts.offerer, NFT_TOKEN_ID);
        mint_erc20(contracts.erc20, accounts.owner, accounts.fulfiller, ERC20_AMOUNT);
        approve_erc721(
            contracts.erc721, accounts.offerer, contracts.medialane.contract_address, NFT_TOKEN_ID,
        );
        approve_erc20(
            contracts.erc20, accounts.fulfiller, contracts.medialane.contract_address, ERC20_AMOUNT,
        );

        cheat_caller_address(
            contracts.medialane.contract_address, accounts.fulfiller, CheatSpan::TargetCalls(1),
        );
        contracts.medialane.fulfill_order(signed_order_nonce_0);

        stop_cheat_block_timestamp(contracts.medialane.contract_address);
    }
}
