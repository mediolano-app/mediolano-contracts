use snforge_std::DeclareResultTrait;
use starknet::{ContractAddress, contract_address_const, ClassHash};

use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{declare, ContractClassTrait};

use ip_franchise_monetization::interfaces::{
    IIPFranchiseAgreementDispatcher, IIPFranchiseManagerDispatcher,
};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher};
use ip_franchise_monetization::mocks::MockERC20::{IERC20MintDispatcher, IERC20MintDispatcherTrait};
use ip_franchise_monetization::mocks::MockERC721::{
    IERC721MintDispatcher, IERC721MintDispatcherTrait,
};
use ip_franchise_monetization::types::{FranchiseTerms, PaymentModel, ExclusivityType};

pub const ONE_E18: u256 = 1000000000000000000_u256;

pub fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

pub fn FRANCHISEE() -> ContractAddress {
    contract_address_const::<'FRANCHISEE'>()
}

pub fn BUYER() -> ContractAddress {
    contract_address_const::<'BUYER'>()
}

pub fn ZERO_ADDRESS() -> ContractAddress {
    contract_address_const::<0>()
}

pub fn declare_and_deploy(contract_name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract = declare(contract_name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

pub fn deploy_erc20() -> IERC20Dispatcher {
    let mut calldata = array![];
    let initial_supply: u256 = 1000_000_000_u256;
    let name: ByteArray = "DummyERC20";
    let symbol: ByteArray = "DUMMY";

    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(initial_supply);
    let erc20_address = declare_and_deploy("MockERC20", calldata);
    IERC20Dispatcher { contract_address: erc20_address }
}


pub fn deploy_erc721() -> IERC721Dispatcher {
    let mut calldata = array![];
    let base_url: ByteArray = "DummyERC721";
    calldata.append_serde(base_url);
    let erc721_address = declare_and_deploy("MockERC721", calldata);
    IERC721Dispatcher { contract_address: erc721_address }
}

pub fn mint_erc20(token: ContractAddress, recipient: ContractAddress, amount: u256) {
    IERC20MintDispatcher { contract_address: token }.mint(recipient, amount)
}

pub fn mint_erc721(token: ContractAddress, recipient: ContractAddress, token_id: u256) {
    IERC721MintDispatcher { contract_address: token }.mint(recipient, token_id)
}


pub fn deploy_agreement_contract(
    agreement_id: u256,
    franchise_manager: ContractAddress,
    franchisee: ContractAddress,
    franchise_terms: FranchiseTerms,
) -> IIPFranchiseAgreementDispatcher {
    let mut calldata = array![];
    calldata.append_serde(agreement_id);
    calldata.append_serde(franchise_manager);
    calldata.append_serde(franchisee);
    calldata.append_serde(franchise_terms);
    let agreement_contract = declare_and_deploy("IPFranchisingAgreement", calldata);
    IIPFranchiseAgreementDispatcher { contract_address: agreement_contract }
}

pub fn deploy_manager_contract(
    admin: ContractAddress,
    token_id: u256,
    token_address: ContractAddress,
    agreement_class_hash: ClassHash,
    default_franchise_fee: u256,
    preferred_payment_model: PaymentModel,
) -> IIPFranchiseManagerDispatcher {
    let mut calldata = array![];
    calldata.append_serde(admin);
    calldata.append_serde(token_id);
    calldata.append_serde(token_address);
    calldata.append_serde(agreement_class_hash);
    calldata.append_serde(default_franchise_fee);
    calldata.append_serde(preferred_payment_model);
    let manager_contract = declare_and_deploy("IPFranchiseManager", calldata);
    IIPFranchiseManagerDispatcher { contract_address: manager_contract }
}

#[derive(Drop)]
pub struct TestContracts {
    pub manager_contract: IIPFranchiseManagerDispatcher,
    pub erc20_token: IERC20Dispatcher,
    pub erc721_token: IERC721Dispatcher,
}


pub fn initialize_contracts() -> TestContracts {
    let erc20_token = deploy_erc20();
    let erc721_token = deploy_erc721();
    let token_id = 1;

    mint_erc721(erc721_token.contract_address, OWNER(), token_id);

    let agreement_class_hash = declare("IPFranchisingAgreement").unwrap().contract_class();
    let default_fee = 500;
    let default_payment_model = PaymentModel::OneTime(20000);

    let manager_contract = deploy_manager_contract(
        OWNER(),
        token_id,
        erc721_token.contract_address,
        *agreement_class_hash.class_hash,
        default_fee,
        default_payment_model,
    );

    TestContracts { manager_contract, erc20_token, erc721_token }
}


pub fn dummy_franchise_terms(token: ContractAddress) -> FranchiseTerms {
    FranchiseTerms {
        payment_model: PaymentModel::OneTime(1000),
        payment_token: token,
        franchise_fee: 100,
        license_start: 1000,
        license_end: 4000,
        exclusivity: ExclusivityType::NonExclusive,
        territory_id: 0,
    }
}
