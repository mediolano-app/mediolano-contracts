use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use ip_collective_agreement::types::{
    LicenseInfo, LicenseTerms, LicenseType, UsageRights, GovernanceSettings,
};
use ip_collective_agreement::interface::{
    IOwnershipRegistryDispatcher, IOwnershipRegistryDispatcherTrait, IIPAssetManagerDispatcher,
    IIPAssetManagerDispatcherTrait, IRevenueDistributionDispatcher,
    IRevenueDistributionDispatcherTrait, ILicenseManagerDispatcher, ILicenseManagerDispatcherTrait,
    IGovernanceDispatcher, IGovernanceDispatcherTrait,
};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use core::num::traits::Bounded;

pub fn OWNER() -> ContractAddress {
    deploy_erc1155_receiver()
}
pub fn CREATOR1() -> ContractAddress {
    deploy_erc1155_receiver()
}
pub fn CREATOR2() -> ContractAddress {
    deploy_erc1155_receiver()
}
pub fn CREATOR3() -> ContractAddress {
    deploy_erc1155_receiver()
}
pub fn USER() -> ContractAddress {
    deploy_erc1155_receiver()
}

pub fn SPENDER() -> ContractAddress {
    'spender'.try_into().unwrap()
}

pub fn MARKETPLACE() -> ContractAddress {
    'marketplace'.try_into().unwrap()
}

pub fn deploy_mock_erc20(
    name: ByteArray, symbol: ByteArray, initial_supply: u256, recipient: ContractAddress,
) -> ContractAddress {
    let mut calldata: Array<felt252> = ArrayTrait::new();
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    initial_supply.low.serialize(ref calldata);
    initial_supply.high.serialize(ref calldata);
    recipient.serialize(ref calldata);

    let contract = declare("MockERC20").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

pub fn deploy_erc1155_receiver() -> ContractAddress {
    let contract_class = declare("ERC1155ReceiverContract").unwrap().contract_class();

    let (contract_address, _) = contract_class.deploy(@array![]).unwrap();
    contract_address
}

// Deploy the contract
pub fn deploy_contract() -> (ContractAddress, ContractAddress) {
    let contract_class = declare("CollectiveIPCore").unwrap().contract_class();

    let base_uri: ByteArray = "ipfs://QmBaseUri/";
    let owner_address = OWNER();

    let mut calldata = array![];
    owner_address.serialize(ref calldata);
    base_uri.serialize(ref calldata);

    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    (contract_address, owner_address)
}

pub fn setup() -> (
    ContractAddress,
    IOwnershipRegistryDispatcher,
    IIPAssetManagerDispatcher,
    IERC1155Dispatcher,
    IRevenueDistributionDispatcher,
    ILicenseManagerDispatcher,
    IERC20Dispatcher,
    ContractAddress,
) {
    let (contract_address, owner_address) = deploy_contract();
    let ownership_dispatcher = IOwnershipRegistryDispatcher { contract_address };
    let asset_dispatcher = IIPAssetManagerDispatcher { contract_address };
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let revenue_dispatcher = IRevenueDistributionDispatcher { contract_address };
    let licensing_dispatcher = ILicenseManagerDispatcher { contract_address };
    let erc20_contract = deploy_mock_erc20("TestToken", "TTK", 100_000_000.into(), SPENDER());
    let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_contract };

    start_cheat_caller_address(erc20_contract, SPENDER());
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    erc20_dispatcher.transfer(MARKETPLACE(), 10_000_u256);
    stop_cheat_caller_address(erc20_contract);

    start_cheat_caller_address(erc20_contract, MARKETPLACE());
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20_contract);

    (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        licensing_dispatcher,
        erc20_dispatcher,
        owner_address,
    )
}

// Helper function to create test data
pub fn create_test_creators_data() -> (Span<ContractAddress>, Span<u256>, Span<u256>) {
    let creators = array![
        deploy_erc1155_receiver(), deploy_erc1155_receiver(), deploy_erc1155_receiver(),
    ]
        .span();

    let ownership_percentages = array![50_u256, 30_u256, 20_u256].span(); // 50%, 30%, 20%
    let governance_weights = array![40_u256, 35_u256, 25_u256].span(); // Different from ownership

    (creators, ownership_percentages, governance_weights)
}

pub fn register_test_asset(
    contract_address: ContractAddress,
    asset_dispatcher: IIPAssetManagerDispatcher,
    owner: ContractAddress,
) -> (u256, Span<ContractAddress>, Span<u256>, Span<u256>) {
    let asset_type = 'ART';
    let metadata_uri: ByteArray = "ipfs://QmTestArt";
    let creators = array![
        deploy_erc1155_receiver(), deploy_erc1155_receiver(), deploy_erc1155_receiver(),
    ]
        .span();
    let ownership_percentages = array![50_u256, 30_u256, 20_u256].span(); // 50%, 30%, 20%
    let governance_weights = array![40_u256, 35_u256, 25_u256].span();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    (asset_id, creators, ownership_percentages, governance_weights)
}

pub fn create_basic_license_terms() -> LicenseTerms {
    LicenseTerms {
        max_usage_count: 0, // Unlimited
        current_usage_count: 0,
        attribution_required: true,
        modification_allowed: false,
        commercial_revenue_share: 0,
        termination_notice_period: 604800 // 7 days
    }
}

pub fn create_proposed_license(
    asset_id: u256, licensee: ContractAddress, payment_token: ContractAddress,
) -> LicenseInfo {
    LicenseInfo {
        license_id: 0,
        asset_id,
        licensor: contract_address_const::<0>(),
        licensee,
        license_type: LicenseType::Exclusive.into(),
        usage_rights: UsageRights::All.into(),
        territory: 'GLOBAL',
        license_fee: 2000_u256,
        royalty_rate: 500_u256,
        start_timestamp: get_block_timestamp(),
        end_timestamp: 0,
        is_active: false,
        requires_approval: false,
        is_approved: false,
        payment_token,
        metadata_uri: "ipfs://governance-license",
        is_suspended: false,
        suspension_end_timestamp: 0,
    }
}

pub fn setup_licensee_payment(
    contract_address: ContractAddress,
    erc20_dispatcher: IERC20Dispatcher,
    licensee: ContractAddress,
    amount: u256,
) {
    start_cheat_caller_address(erc20_dispatcher.contract_address, SPENDER());
    erc20_dispatcher.transfer(licensee, amount);
    stop_cheat_caller_address(erc20_dispatcher.contract_address);

    start_cheat_caller_address(erc20_dispatcher.contract_address, licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20_dispatcher.contract_address);
}

pub fn create_and_execute_license_with_terms(
    contract_address: ContractAddress,
    licensing_dispatcher: ILicenseManagerDispatcher,
    erc20_dispatcher: IERC20Dispatcher,
    asset_id: u256,
    creator: ContractAddress,
    licensee: ContractAddress,
    payment_amount: u256,
    terms: LicenseTerms,
) -> u256 {
    start_cheat_caller_address(contract_address, creator);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            100_u256,
            300_u256, // 3% royalty
            0,
            erc20_dispatcher.contract_address,
            terms,
            "ipfs://test-license",
        );
    stop_cheat_caller_address(contract_address);

    setup_licensee_payment(contract_address, erc20_dispatcher, licensee, payment_amount);
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    license_id
}

pub fn setup_with_governance() -> (
    ContractAddress,
    IOwnershipRegistryDispatcher,
    IIPAssetManagerDispatcher,
    IERC1155Dispatcher,
    IRevenueDistributionDispatcher,
    ILicenseManagerDispatcher,
    IGovernanceDispatcher,
    IERC20Dispatcher,
    ContractAddress,
) {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        licensing_dispatcher,
        erc20_dispatcher,
        owner_address,
    ) =
        setup();

    let governance_dispatcher = IGovernanceDispatcher { contract_address };

    (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        revenue_dispatcher,
        licensing_dispatcher,
        governance_dispatcher,
        erc20_dispatcher,
        owner_address,
    )
}

pub fn create_default_governance_settings() -> GovernanceSettings {
    GovernanceSettings {
        default_quorum_percentage: 5000,
        emergency_quorum_percentage: 3000,
        license_quorum_percentage: 4000,
        asset_mgmt_quorum_percentage: 6000,
        revenue_policy_quorum_percentage: 5500,
        default_voting_duration: 259200,
        emergency_voting_duration: 86400,
        execution_delay: 86400,
    }
}

pub fn create_and_execute_license(
    contract_address: ContractAddress,
    licensing_dispatcher: ILicenseManagerDispatcher,
    erc20_dispatcher: IERC20Dispatcher,
    asset_id: u256,
    creator: ContractAddress,
    licensee: ContractAddress,
    payment_amount: u256,
) -> u256 {
    // Fund licensee
    start_cheat_caller_address(erc20_dispatcher.contract_address, SPENDER());
    erc20_dispatcher.transfer(licensee, payment_amount);
    stop_cheat_caller_address(erc20_dispatcher.contract_address);

    start_cheat_caller_address(erc20_dispatcher.contract_address, licensee);
    erc20_dispatcher.approve(contract_address, Bounded::<u256>::MAX);
    stop_cheat_caller_address(erc20_dispatcher.contract_address);

    // Create license
    start_cheat_caller_address(contract_address, creator);
    let license_id = licensing_dispatcher
        .create_license_request(
            asset_id,
            licensee,
            LicenseType::NonExclusive.into(),
            UsageRights::Commercial.into(),
            'GLOBAL',
            100_u256,
            300_u256,
            0,
            erc20_dispatcher.contract_address,
            create_basic_license_terms(),
            "ipfs://test-license",
        );
    stop_cheat_caller_address(contract_address);

    // Execute license
    start_cheat_caller_address(contract_address, licensee);
    licensing_dispatcher.execute_license(license_id);
    stop_cheat_caller_address(contract_address);

    license_id
}
