// Shared structs for the contract
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Story {
    pub creator: starknet::ContractAddress,
    pub title: felt252,
    pub description: felt252,
    pub governance_rules: felt252,
    pub royalty_percentage: u8,
    pub active: bool,
    pub created_at: u64,
    pub total_chapters: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Chapter {
    pub story_id: felt252,
    pub author: starknet::ContractAddress,
    pub content_hash: felt252,
    pub title: felt252,
    pub status: u8, // 0: pending, 1: approved, 2: rejected
    pub minted: bool,
    pub nft_token_id: u256,
    pub submitted_at: u64,
    pub chapter_number: u64,
}

#[starknet::interface]
pub trait IIPStory<TContractState> {
    // Story Management Functions
    fn create_story(
        ref self: TContractState,
        title: felt252,
        description: felt252,
        governance_rules: felt252,
        royalty_percentage: u8,
    ) -> felt252;
    fn update_story_metadata(ref self: TContractState, story_id: felt252, new_description: felt252);
    fn set_story_status(ref self: TContractState, story_id: felt252, active: bool);

    // Chapter Management Functions
    fn submit_chapter(
        ref self: TContractState, story_id: felt252, content_hash: felt252, chapter_title: felt252,
    ) -> felt252;
    fn approve_chapter(ref self: TContractState, chapter_id: felt252);
    fn reject_chapter(ref self: TContractState, chapter_id: felt252, reason: felt252);
    fn mint_chapter_nft(ref self: TContractState, chapter_id: felt252) -> u256;

    // Moderation Functions
    fn add_moderator(
        ref self: TContractState, story_id: felt252, moderator: starknet::ContractAddress,
    );
    fn remove_moderator(
        ref self: TContractState, story_id: felt252, moderator: starknet::ContractAddress,
    );
    fn set_moderation_rules(ref self: TContractState, story_id: felt252, new_rules: felt252);

    // Royalty Functions
    fn claim_royalties(ref self: TContractState, story_id: felt252);
    fn distribute_royalties(ref self: TContractState, story_id: felt252, amount: u256);
    fn update_royalty_percentage(ref self: TContractState, story_id: felt252, new_percentage: u8);

    // ERC1155 Functions
    fn balance_of(
        self: @TContractState, account: starknet::ContractAddress, token_id: u256,
    ) -> u256;
    fn balance_of_batch(
        self: @TContractState, accounts: Array<starknet::ContractAddress>, token_ids: Array<u256>,
    ) -> Array<u256>;
    fn set_approval_for_all(
        ref self: TContractState, operator: starknet::ContractAddress, approved: bool,
    );
    fn is_approved_for_all(
        self: @TContractState,
        account: starknet::ContractAddress,
        operator: starknet::ContractAddress,
    ) -> bool;
    fn safe_transfer_from(
        ref self: TContractState,
        from: starknet::ContractAddress,
        to: starknet::ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>,
    );
    fn safe_batch_transfer_from(
        ref self: TContractState,
        from: starknet::ContractAddress,
        to: starknet::ContractAddress,
        token_ids: Array<u256>,
        values: Array<u256>,
        data: Span<felt252>,
    );

    // View Functions
    fn get_story_details(self: @TContractState, story_id: felt252) -> Story;
    fn get_chapter_details(self: @TContractState, chapter_id: felt252) -> Chapter;
    fn get_story_chapters(self: @TContractState, story_id: felt252) -> Array<felt252>;
    fn get_user_stories(
        self: @TContractState, creator: starknet::ContractAddress,
    ) -> Array<felt252>;
    fn get_user_chapters(
        self: @TContractState, author: starknet::ContractAddress,
    ) -> Array<felt252>;
    fn is_moderator(
        self: @TContractState, story_id: felt252, user: starknet::ContractAddress,
    ) -> bool;
    fn get_story_moderators(
        self: @TContractState, story_id: felt252,
    ) -> Array<starknet::ContractAddress>;
    fn get_pending_chapters(self: @TContractState, story_id: felt252) -> Array<felt252>;
    fn get_royalty_balance(
        self: @TContractState, story_id: felt252, contributor: starknet::ContractAddress,
    ) -> u256;
    fn get_chapter_nft_uri(self: @TContractState, token_id: u256) -> felt252;
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
}
