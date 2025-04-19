use ip_marketplace::IPMarketplace::{IIPMarketplace, IIPMarketplaceDispatcher};
use ip_programmable_erc_721::MIP::{IMIPDispatcher, IMIPDispatcherTrait};

use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    spy_events, EventSpyAssertionsTrait, get_class_hash,
    cheat_block_timestamp, start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global
};

use openzeppelin_token::erc721::interface::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721MetadataDispatcher,
    IERC721MetadataDispatcherTrait
};

fn __setup__() -> (
    IIPMarketplaceDispatcher, 
    ContractAddress,
    IMIPDispatcher,
    ContractAddress
) {
    let (ip_marketplace_dispatcher, ip_marketplace_contract_address) = _deploy_IPMarketplace__();
    let (mip_dispatcher, mip_contract_address) = _deploy_MIP__();
    (ip_marketplace_dispatcher, ip_marketplace_contract_address, mip_dispatcher, mip_contract_address)
}

fn _deploy_IPMarketplace__() -> (IIPMarketplaceDispatcher, ContractAddress) {
    let contract = declare("IPMarketplace").unwrap().contract_class();
    let marketplace_fee: u256 = 100;
    let constructor_calldata = array![marketplace_fee.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = IIPMarketplaceDispatcher { contract_address };
    println!("IPMarketplace deployed on: {:?}", contract_address);
    (dispatcher, contract_address)
}

fn _deploy_MIP__() -> (IMIPDispatcher, ContractAddress) {
    let contract = declare("MIP").unwrap().contract_class();
    let owner: ContractAddress = contract_address_const::<'owner'>();
    let constructor_calldata = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = IMIPDispatcher { contract_address };
    println!("MIP deployed on: {:?}", contract_address);
    (dispatcher, contract_address)
}


#[test]
fn test_list_item(){
    let (
        ip_marketplace_dispatcher,
        ip_marketplace_contract_address,
        mip_dispatcher,
        mip_contract_address,
    ) = __setup__();

    let owner = contract_address_const::<'owner'>();

    let user = contract_address_const::<'user'>();
    start_cheat_caller_address(ip_marketplace_contract_address, user);

    let erc721 = IERC721Dispatcher { contract_address: mip_contract_address };
    let mint_url: ByteArray = "QmfVMAmNM1kDEBYrC2TPzQDoCRFH6F5tE1e9Mr4FkkR5Xr";
    let mint_url_felt: felt252 = QmfVMAmNM1kDEBYrC2TPzQDoCRFH6F5tE1e9Mr4FkkR5Xr;    
    let first_token_id = mip_dispatcher.mint_item(user, mint_url.clone());
    let price: u256 = 1000;
    let strk: felt252 = 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;
    let license_url_felt: felt252 = bafkreibryabifvypyx7gleiqztaj3fkkyalqiaahn3ewvmrm6zoi3bnqdu;

    let usage_rights: IPUsageRights = IPUsageRights {
        commercial_use: true,
        modifications_allowed: true,
        attribution_required: true,
        geographical_restrictions: 1,
        usage_duration: 2,
        sublicensing_allowed: true,
        industry_restrictions: 3,
    };

    let derivative_rights: IPDerivativeRights = IPDerivativeRights {
        allowed: true,
        royalty_share: 4,
        requires_approval: true,
        max_derivatives: 5
    };

    start_cheat_block_timestamp_global(10); 
    ip_marketplace_dispatcher.list_item(
        nft_contract: mip_contract_address,
        token_id: first_token_id,
        price,
        currency_address: strk,
        metadata_hash: mint_url_felt,
        license_terms_hash: license_url_felt,
        usage_rights,
        derivative_rights,
    );

    assert_eq!(
        ip_marketplace_dispatcher.get_listing(
            nft_contract: mip_contract_address,
            token_id: first_token_id
        ),
        (
            Listing {
                seller: user,
                nft_contract: mip_contract_address,
                price,
                currency: strk,
                active: true,
                metadata: IPMetadata = IPMetadata {
                    ipfs_hash: mint_url_felt,
                    license_terms_hash: license_url_felt,
                    creator: user,
                    creation_date: 10,
                    last_updated: 10,
                    version: 1,
                    content_type: 0,
                    derivative_of: 0 
                },
                royalty_percentage: 250,
                usage_rights,
                derivative_rights,
                minimum_purchase_duration: 0,
                bulk_discount_rate: 0,
            },
        )
    );


    stop_cheat_caller_address(ip_marketplace_contract_address);
}