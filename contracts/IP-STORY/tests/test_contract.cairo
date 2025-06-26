#[cfg(test)]
mod tests {
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_block_timestamp,
        testing::{set_caller_address, set_block_timestamp},
    };
    use snforge_std::{declare, ContractClassTrait, spy_events, SpyOn, EventSpy, EventAssertions};

    use ip_story::interface::{IIPStoryDispatcher, IIPStoryDispatcherTrait, Story, Chapter};
    use ip_story::IPStory;
    use ip_story::errors::IPStoryErrors;

    // Test helper functions
    fn deploy_contract() -> (IIPStoryDispatcher, ContractAddress) {
        let contract = declare("IPStory").unwrap();
        let admin = contract_address_const::<0x123>();
        let base_uri = 'https://ipfs.io/ipfs/';

        let (contract_address, _) = contract.deploy(@array![admin.into(), base_uri]).unwrap();
        (IIPStoryDispatcher { contract_address }, contract_address)
    }

    fn setup_accounts() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
        let admin = contract_address_const::<0x123>();
        let creator = contract_address_const::<0x456>();
        let author1 = contract_address_const::<0x789>();
        let author2 = contract_address_const::<0xABC>();
        (admin, creator, author1, author2)
    }

    #[test]
    fn test_create_story() {
        let (contract, _) = deploy_contract();
        let (_, creator, _, _) = setup_accounts();

        set_caller_address(creator);
        set_block_timestamp(1000);

        let title = 'Amazing Story';
        let description = 'A collaborative story';
        let governance_rules = 'Community moderated';
        let royalty_percentage = 10;

        let story_id = contract
            .create_story(title, description, governance_rules, royalty_percentage);

        assert(story_id == 1, 'Story ID should be 1');

        let story = contract.get_story_details(story_id);
        assert(story.creator == creator, 'Wrong creator');
        assert(story.title == title, 'Wrong title');
        assert(story.description == description, 'Wrong description');
        assert(story.governance_rules == governance_rules, 'Wrong governance rules');
        assert(story.royalty_percentage == royalty_percentage, 'Wrong royalty percentage');
        assert(story.active == true, 'Story should be active');
        assert(story.created_at == 1000, 'Wrong creation time');
        assert(story.total_chapters == 0, 'Should have 0 chapters initially');

        // Check if creator is automatically a moderator
        assert(contract.is_moderator(story_id, creator), 'Creator should be moderator');

        let user_stories = contract.get_user_stories(creator);
        assert(user_stories.len() == 1, 'Creator should have 1 story');
        assert(*user_stories.at(0) == story_id, 'Wrong story in user stories');
    }

    #[test]
    #[should_panic(expected: ('Story title cannot be empty',))]
    fn test_create_story_empty_title() {
        let (contract, _) = deploy_contract();
        let (_, creator, _, _) = setup_accounts();

        set_caller_address(creator);
        contract.create_story(0, 'description', 'rules', 10);
    }

    #[test]
    #[should_panic(expected: ('Invalid royalty percentage',))]
    fn test_create_story_invalid_royalty() {
        let (contract, _) = deploy_contract();
        let (_, creator, _, _) = setup_accounts();

        set_caller_address(creator);
        contract.create_story('title', 'description', 'rules', 101);
    }

    #[test]
    fn test_update_story_metadata() {
        let (contract, _) = deploy_contract();
        let (_, creator, _, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        let new_description = 'Updated description';
        contract.update_story_metadata(story_id, new_description);

        let story = contract.get_story_details(story_id);
        assert(story.description == new_description, 'Description not updated');
    }

    #[test]
    #[should_panic(expected: ('Only story creator can update',))]
    fn test_update_story_metadata_unauthorized() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        contract.update_story_metadata(story_id, 'new description');
    }

    #[test]
    fn test_submit_chapter() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        set_block_timestamp(2000);

        let content_hash = 'chapter1_content_hash';
        let chapter_title = 'Chapter 1';

        let chapter_id = contract.submit_chapter(story_id, content_hash, chapter_title);

        assert(chapter_id == 1, 'Chapter ID should be 1');

        let chapter = contract.get_chapter_details(chapter_id);
        assert(chapter.story_id == story_id, 'Wrong story ID');
        assert(chapter.author == author1, 'Wrong author');
        assert(chapter.content_hash == content_hash, 'Wrong content hash');
        assert(chapter.title == chapter_title, 'Wrong chapter title');
        assert(chapter.status == 0, 'Chapter should be pending');
        assert(chapter.minted == false, 'Chapter should not be minted');
        assert(chapter.submitted_at == 2000, 'Wrong submission time');
        assert(chapter.chapter_number == 1, 'Wrong chapter number');

        let user_chapters = contract.get_user_chapters(author1);
        assert(user_chapters.len() == 1, 'Author should have 1 chapter');

        let pending_chapters = contract.get_pending_chapters(story_id);
        assert(pending_chapters.len() == 1, 'Should have 1 pending chapter');

        // Check story total chapters updated
        let story = contract.get_story_details(story_id);
        assert(story.total_chapters == 1, 'Total chapters should be 1');
    }

    #[test]
    #[should_panic(expected: ('Story is not active',))]
    fn test_submit_chapter_inactive_story() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);
        contract.set_story_status(story_id, false);

        set_caller_address(author1);
        contract.submit_chapter(story_id, 'content', 'title');
    }

    #[test]
    fn test_approve_chapter() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        let chapter_id = contract.submit_chapter(story_id, 'content', 'title');

        set_caller_address(creator); // Creator is moderator
        contract.approve_chapter(chapter_id);

        let chapter = contract.get_chapter_details(chapter_id);
        assert(chapter.status == 1, 'Chapter should be approved');

        let story_chapters = contract.get_story_chapters(story_id);
        assert(story_chapters.len() == 1, 'Should have 1 approved chapter');

        let pending_chapters = contract.get_pending_chapters(story_id);
        assert(pending_chapters.len() == 0, 'Should have 0 pending chapters');
    }

    #[test]
    #[should_panic(expected: ('Not authorized to moderate',))]
    fn test_approve_chapter_unauthorized() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, author2) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        let chapter_id = contract.submit_chapter(story_id, 'content', 'title');

        set_caller_address(author2); // Not a moderator
        contract.approve_chapter(chapter_id);
    }

    #[test]
    fn test_reject_chapter() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        let chapter_id = contract.submit_chapter(story_id, 'content', 'title');

        set_caller_address(creator);
        let rejection_reason = 'Content inappropriate';
        contract.reject_chapter(chapter_id, rejection_reason);

        let chapter = contract.get_chapter_details(chapter_id);
        assert(chapter.status == 2, 'Chapter should be rejected');

        let pending_chapters = contract.get_pending_chapters(story_id);
        assert(pending_chapters.len() == 0, 'Should have 0 pending chapters');
    }

    #[test]
    fn test_mint_chapter_nft() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        let chapter_id = contract.submit_chapter(story_id, 'content', 'title');

        set_caller_address(creator);
        contract.approve_chapter(chapter_id);

        set_caller_address(author1);
        let token_id = contract.mint_chapter_nft(chapter_id);

        assert(token_id == 1, 'Token ID should be 1');

        let chapter = contract.get_chapter_details(chapter_id);
        assert(chapter.minted == true, 'Chapter should be minted');
        assert(chapter.nft_token_id == token_id, 'Wrong NFT token ID');

        // Check ERC1155 balance
        let balance = contract.balance_of(author1, token_id);
        assert(balance == 1, 'Author should own 1 NFT');

        // Check NFT metadata
        let uri = contract.get_chapter_nft_uri(token_id);
        assert(uri != 0, 'URI should not be empty');
    }

    #[test]
    #[should_panic(expected: ('Chapter not approved for minting',))]
    fn test_mint_chapter_nft_not_approved() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        let chapter_id = contract.submit_chapter(story_id, 'content', 'title');

        contract.mint_chapter_nft(chapter_id);
    }

    #[test]
    #[should_panic(expected: ('Only chapter author can mint',))]
    fn test_mint_chapter_nft_unauthorized() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, author2) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        let chapter_id = contract.submit_chapter(story_id, 'content', 'title');

        set_caller_address(creator);
        contract.approve_chapter(chapter_id);

        set_caller_address(author2); // Not the author
        contract.mint_chapter_nft(chapter_id);
    }

    #[test]
    fn test_add_moderator() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        contract.add_moderator(story_id, author1);

        assert(contract.is_moderator(story_id, author1), 'Author1 should be moderator');

        let moderators = contract.get_story_moderators(story_id);
        assert(moderators.len() == 2, 'Should have 2 moderators'); // Creator + added moderator
    }

    #[test]
    #[should_panic(expected: ('Only story creator allowed',))]
    fn test_add_moderator_unauthorized() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, author2) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1); // Not creator
        contract.add_moderator(story_id, author2);
    }

    #[test]
    fn test_remove_moderator() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);
        contract.add_moderator(story_id, author1);

        contract.remove_moderator(story_id, author1);

        assert(!contract.is_moderator(story_id, author1), 'Author1 should not be moderator');

        let moderators = contract.get_story_moderators(story_id);
        assert(moderators.len() == 1, 'Should have 1 moderator'); // Just creator
    }

    #[test]
    #[should_panic(expected: ('Cannot remove story creator',))]
    fn test_remove_creator_as_moderator() {
        let (contract, _) = deploy_contract();
        let (_, creator, _, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        contract.remove_moderator(story_id, creator);
    }

    #[test]
    fn test_distribute_royalties() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, author2) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        // Create and approve multiple chapters
        set_caller_address(author1);
        let chapter_id1 = contract.submit_chapter(story_id, 'content1', 'title1');

        set_caller_address(author2);
        let chapter_id2 = contract.submit_chapter(story_id, 'content2', 'title2');

        set_caller_address(creator);
        contract.approve_chapter(chapter_id1);
        contract.approve_chapter(chapter_id2);

        // Distribute royalties
        let total_amount = 1000_u256;
        contract.distribute_royalties(story_id, total_amount);

        // Check balances (should be split equally)
        let balance1 = contract.get_royalty_balance(story_id, author1);
        let balance2 = contract.get_royalty_balance(story_id, author2);

        assert(balance1 == 500, 'Author1 should have 500');
        assert(balance2 == 500, 'Author2 should have 500');
    }

    #[test]
    fn test_claim_royalties() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        let chapter_id = contract.submit_chapter(story_id, 'content', 'title');

        set_caller_address(creator);
        contract.approve_chapter(chapter_id);
        contract.distribute_royalties(story_id, 1000);

        set_caller_address(author1);
        contract.claim_royalties(story_id);

        let balance = contract.get_royalty_balance(story_id, author1);
        assert(balance == 0, 'Balance should be 0 after claiming');
    }

    #[test]
    #[should_panic(expected: ('No royalties to claim',))]
    fn test_claim_royalties_none_available() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        contract.claim_royalties(story_id);
    }

    #[test]
    fn test_update_royalty_percentage() {
        let (contract, _) = deploy_contract();
        let (_, creator, _, _) = setup_accounts();

        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        contract.update_royalty_percentage(story_id, 15);

        let story = contract.get_story_details(story_id);
        assert(story.royalty_percentage == 15, 'Royalty percentage should be 15');
    }

    #[test]
    fn test_erc1155_transfer() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, author2) = setup_accounts();

        // Mint an NFT
        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        let chapter_id = contract.submit_chapter(story_id, 'content', 'title');

        set_caller_address(creator);
        contract.approve_chapter(chapter_id);

        set_caller_address(author1);
        let token_id = contract.mint_chapter_nft(chapter_id);

        // Transfer NFT
        contract.safe_transfer_from(author1, author2, token_id, 1, array![].span());

        let balance1 = contract.balance_of(author1, token_id);
        let balance2 = contract.balance_of(author2, token_id);

        assert(balance1 == 0, 'Author1 should have 0 NFTs');
        assert(balance2 == 1, 'Author2 should have 1 NFT');
    }

    #[test]
    fn test_erc1155_approval() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, author2) = setup_accounts();

        set_caller_address(author1);
        contract.set_approval_for_all(author2, true);

        let approved = contract.is_approved_for_all(author1, author2);
        assert(approved, 'Author2 should be approved');

        contract.set_approval_for_all(author2, false);
        let not_approved = contract.is_approved_for_all(author1, author2);
        assert(!not_approved, 'Author2 should not be approved');
    }

    #[test]
    fn test_erc1155_batch_balance() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, author2) = setup_accounts();

        // Mint multiple NFTs
        set_caller_address(creator);
        let story_id = contract.create_story('title', 'description', 'rules', 10);

        set_caller_address(author1);
        let chapter_id1 = contract.submit_chapter(story_id, 'content1', 'title1');
        let chapter_id2 = contract.submit_chapter(story_id, 'content2', 'title2');

        set_caller_address(creator);
        contract.approve_chapter(chapter_id1);
        contract.approve_chapter(chapter_id2);

        set_caller_address(author1);
        let token_id1 = contract.mint_chapter_nft(chapter_id1);

        set_caller_address(author2);
        let token_id2 = contract.mint_chapter_nft(chapter_id2);

        // Test batch balance
        let accounts = array![author1, author2];
        let token_ids = array![token_id1, token_id2];
        let balances = contract.balance_of_batch(accounts, token_ids);

        assert(balances.len() == 2, 'Should return 2 balances');
        assert(*balances.at(0) == 1, 'Author1 should have 1 token');
        assert(*balances.at(1) == 1, 'Author2 should have 1 token');
    }

    #[test]
    fn test_supports_interface() {
        let (contract, _) = deploy_contract();

        // Test ERC1155 interface
        let erc1155_interface = 0xd9b67a26;
        assert(contract.supports_interface(erc1155_interface), 'Should support ERC1155');

        // Test ERC1155MetadataURI interface
        let metadata_interface = 0x0e89341c;
        assert(contract.supports_interface(metadata_interface), 'Should support metadata');

        // Test unsupported interface
        let random_interface = 0x12345678;
        assert(
            !contract.supports_interface(random_interface), 'Should not support random interface',
        );
    }

    #[test]
    fn test_complex_workflow() {
        let (contract, _) = deploy_contract();
        let (_, creator, author1, author2) = setup_accounts();

        // 1. Create story
        set_caller_address(creator);
        let story_id = contract.create_story('Epic Tale', 'A collaborative epic', 'Democratic', 15);

        // 2. Add moderator
        contract.add_moderator(story_id, author1);

        // 3. Submit chapters from different authors
        set_caller_address(author1);
        let chapter_id1 = contract
            .submit_chapter(story_id, 'chapter1_hash', 'Chapter 1: Beginning');

        set_caller_address(author2);
        let chapter_id2 = contract.submit_chapter(story_id, 'chapter2_hash', 'Chapter 2: Journey');

        // 4. Approve chapters using different moderators
        set_caller_address(creator);
        contract.approve_chapter(chapter_id1);

        set_caller_address(author1); // Author1 is also moderator
        contract.approve_chapter(chapter_id2);

        // 5. Mint NFTs
        set_caller_address(author1);
        let token_id1 = contract.mint_chapter_nft(chapter_id1);

        set_caller_address(author2);
        let token_id2 = contract.mint_chapter_nft(chapter_id2);

        // 6. Distribute and claim royalties
        set_caller_address(creator);
        contract.distribute_royalties(story_id, 2000);

        set_caller_address(author1);
        contract.claim_royalties(story_id);

        set_caller_address(author2);
        contract.claim_royalties(story_id);

        // 7. Verify final state
        let story = contract.get_story_details(story_id);
        assert(story.total_chapters == 2, 'Should have 2 chapters');

        let story_chapters = contract.get_story_chapters(story_id);
        assert(story_chapters.len() == 2, 'Should have 2 approved chapters');

        assert(contract.balance_of(author1, token_id1) == 1, 'Author1 should own token1');
        assert(contract.balance_of(author2, token_id2) == 1, 'Author2 should own token2');

        let balance1 = contract.get_royalty_balance(story_id, author1);
        let balance2 = contract.get_royalty_balance(story_id, author2);
        assert(balance1 == 0, 'Author1 royalties should be claimed');
        assert(balance2 == 0, 'Author2 royalties should be claimed');
    }
}
