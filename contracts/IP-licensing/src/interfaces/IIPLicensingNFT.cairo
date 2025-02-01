use starknet::ContractAddress;
// *************************************************************************
//                              INTERFACE of IPLICENSING NFT
// *************************************************************************
#[starknet::interface]
pub trait IIPLicensingNFT<TContractState> {
    fn mint_Licensing_nft(ref self: TContractState, recipient: ContractAddress , token_uri : ByteArray)-> u256;
    fn get_last_minted_id(self: @TContractState) -> u256;
    fn get_token_mint_timestamp(self: @TContractState, token_id: u256) -> u64;
    fn get_token_uri(self: @TContractState  , token_id : u256) -> ByteArray;
}