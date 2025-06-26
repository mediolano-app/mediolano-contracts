#[starknet::contract]
pub mod IPStory {
    use ip_story::errors::IPStoryErrors;
    use ip_story::interface::{Chapter, IIPStory, Story};
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    // Struct for NFT token metadata
    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct TokenMetadata {
        chapter_id: felt252,
        uri: felt252,
    }

    #[storage]
    struct Storage {
        // Core mappings
        stories: Map<felt252, Story>,
        chapters: Map<felt252, Chapter>,
        token_metadata: Map<u256, TokenMetadata>,
        // User mappings
        user_stories: Map<ContractAddress, Vec<felt252>>,
        user_chapters: Map<ContractAddress, Vec<felt252>>,
        // Story to chapters mapping
        story_chapters: Map<felt252, Vec<felt252>>,
        story_pending_chapters: Map<felt252, Vec<felt252>>,
        // Moderation mappings
        story_moderators: Map<felt252, Map<ContractAddress, bool>>,
        story_moderator_list: Map<felt252, Vec<ContractAddress>>,
        // Royalty mappings
        royalty_balances: Map<(felt252, ContractAddress), u256>,
        story_total_royalties: Map<felt252, u256>,
        // ERC1155 storage
        balances: Map<(ContractAddress, u256), u256>,
        operator_approvals: Map<(ContractAddress, ContractAddress), bool>,
        // Contract admin and counters
        admin: ContractAddress,
        next_story_id: felt252,
        next_chapter_id: felt252,
        next_token_id: u256,
        // ERC1155 metadata
        base_uri: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        StoryCreated: StoryCreated,
        StoryUpdated: StoryUpdated,
        StoryStatusChanged: StoryStatusChanged,
        ChapterSubmitted: ChapterSubmitted,
        ChapterApproved: ChapterApproved,
        ChapterRejected: ChapterRejected,
        ChapterMinted: ChapterMinted,
        ModeratorAdded: ModeratorAdded,
        ModeratorRemoved: ModeratorRemoved,
        ModerationRulesUpdated: ModerationRulesUpdated,
        RoyaltiesDistributed: RoyaltiesDistributed,
        RoyaltiesClaimed: RoyaltiesClaimed,
        RoyaltyPercentageUpdated: RoyaltyPercentageUpdated,
        TransferSingle: TransferSingle,
        TransferBatch: TransferBatch,
        ApprovalForAll: ApprovalForAll,
        URI: URI,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StoryCreated {
        pub story_id: felt252,
        pub creator: ContractAddress,
        pub title: felt252,
        pub description: felt252,
        pub royalty_percentage: u8,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StoryUpdated {
        pub story_id: felt252,
        pub new_description: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StoryStatusChanged {
        pub story_id: felt252,
        pub active: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ChapterSubmitted {
        pub chapter_id: felt252,
        pub story_id: felt252,
        pub author: ContractAddress,
        pub title: felt252,
        pub chapter_number: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ChapterApproved {
        pub chapter_id: felt252,
        pub story_id: felt252,
        pub moderator: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ChapterRejected {
        pub chapter_id: felt252,
        pub story_id: felt252,
        pub moderator: ContractAddress,
        pub reason: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ChapterMinted {
        pub chapter_id: felt252,
        pub author: ContractAddress,
        pub token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ModeratorAdded {
        pub story_id: felt252,
        pub moderator: ContractAddress,
        pub added_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ModeratorRemoved {
        pub story_id: felt252,
        pub moderator: ContractAddress,
        pub removed_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ModerationRulesUpdated {
        pub story_id: felt252,
        pub new_rules: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoyaltiesDistributed {
        pub story_id: felt252,
        pub total_amount: u256,
        pub distributor: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoyaltiesClaimed {
        pub story_id: felt252,
        pub contributor: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoyaltyPercentageUpdated {
        pub story_id: felt252,
        pub new_percentage: u8,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransferSingle {
        pub operator: ContractAddress,
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub id: u256,
        pub value: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransferBatch {
        pub operator: ContractAddress,
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub ids: Array<u256>,
        pub values: Array<u256>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ApprovalForAll {
        pub account: ContractAddress,
        pub operator: ContractAddress,
        pub approved: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct URI {
        pub value: felt252,
        pub id: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress, base_uri: felt252) {
        self.admin.write(admin);
        self.base_uri.write(base_uri);
        self.next_story_id.write(1);
        self.next_chapter_id.write(1);
        self.next_token_id.write(1);
    }

    #[abi(embed_v0)]
    impl IPStoryImpl of IIPStory<ContractState> {
        // Story Management Functions
        fn create_story(
            ref self: ContractState,
            title: felt252,
            description: felt252,
            governance_rules: felt252,
            royalty_percentage: u8,
        ) -> felt252 {
            let caller = get_caller_address();
            assert(title != 0, IPStoryErrors::STORY_TITLE_EMPTY);
            assert(royalty_percentage <= 100, IPStoryErrors::INVALID_ROYALTY_PERCENTAGE);

            let story_id = self.next_story_id.read();
            let current_time = get_block_timestamp();

            let story = Story {
                creator: caller,
                title: title,
                description: description,
                governance_rules: governance_rules,
                royalty_percentage: royalty_percentage,
                active: true,
                created_at: current_time,
                total_chapters: 0,
            };

            self.stories.entry(story_id).write(story);
            self.user_stories.entry(caller).push(story_id);

            // Creator is automatically a moderator
            self.story_moderators.entry(story_id).entry(caller).write(true);
            self.story_moderator_list.entry(story_id).push(caller);

            self.next_story_id.write(story_id + 1);

            self
                .emit(
                    Event::StoryCreated(
                        StoryCreated {
                            story_id: story_id,
                            creator: caller,
                            title: title,
                            description: description,
                            royalty_percentage: royalty_percentage,
                        },
                    ),
                );

            story_id
        }

        fn update_story_metadata(
            ref self: ContractState, story_id: felt252, new_description: felt252,
        ) {
            let caller = get_caller_address();
            let mut story = self.stories.entry(story_id).read();

            assert(story.creator == caller, IPStoryErrors::ONLY_STORY_CREATOR_CAN_UPDATE);

            story.description = new_description;
            self.stories.entry(story_id).write(story);

            self
                .emit(
                    Event::StoryUpdated(
                        StoryUpdated { story_id: story_id, new_description: new_description },
                    ),
                );
        }

        fn set_story_status(ref self: ContractState, story_id: felt252, active: bool) {
            let caller = get_caller_address();
            let mut story = self.stories.entry(story_id).read();

            assert(story.creator == caller, IPStoryErrors::ONLY_STORY_CREATOR_CAN_UPDATE);

            story.active = active;
            self.stories.entry(story_id).write(story);

            self
                .emit(
                    Event::StoryStatusChanged(
                        StoryStatusChanged { story_id: story_id, active: active },
                    ),
                );
        }

        // Chapter Management Functions
        fn submit_chapter(
            ref self: ContractState,
            story_id: felt252,
            content_hash: felt252,
            chapter_title: felt252,
        ) -> felt252 {
            let caller = get_caller_address();
            let mut story = self.stories.entry(story_id).read();

            assert(story.active, IPStoryErrors::STORY_NOT_ACTIVE);
            assert(content_hash != 0, IPStoryErrors::CHAPTER_CONTENT_EMPTY);
            assert(chapter_title != 0, IPStoryErrors::CHAPTER_TITLE_EMPTY);

            let chapter_id = self.next_chapter_id.read();
            let current_time = get_block_timestamp();

            story.total_chapters += 1;
            let chapter_number = story.total_chapters;

            let chapter = Chapter {
                story_id: story_id,
                author: caller,
                content_hash: content_hash,
                title: chapter_title,
                status: 0, // pending
                minted: false,
                nft_token_id: 0,
                submitted_at: current_time,
                chapter_number: chapter_number,
            };

            self.chapters.entry(chapter_id).write(chapter);
            self.stories.entry(story_id).write(story);
            self.user_chapters.entry(caller).push(chapter_id);
            self.story_pending_chapters.entry(story_id).push(chapter_id);
            self.next_chapter_id.write(chapter_id + 1);

            self
                .emit(
                    Event::ChapterSubmitted(
                        ChapterSubmitted {
                            chapter_id: chapter_id,
                            story_id: story_id,
                            author: caller,
                            title: chapter_title,
                            chapter_number: chapter_number,
                        },
                    ),
                );

            chapter_id
        }

        fn approve_chapter(ref self: ContractState, chapter_id: felt252) {
            let caller = get_caller_address();
            let mut chapter = self.chapters.entry(chapter_id).read();

            assert(chapter.status == 0, IPStoryErrors::CHAPTER_ALREADY_APPROVED);

            let is_moderator = self.story_moderators.entry(chapter.story_id).entry(caller).read();
            assert(is_moderator, IPStoryErrors::NOT_AUTHORIZED_TO_MODERATE);

            chapter.status = 1; // approved
            self.chapters.entry(chapter_id).write(chapter);

            // Move from pending to approved chapters
            self.story_chapters.entry(chapter.story_id).push(chapter_id);
            self._remove_from_pending_chapters(chapter.story_id, chapter_id);

            self
                .emit(
                    Event::ChapterApproved(
                        ChapterApproved {
                            chapter_id: chapter_id, story_id: chapter.story_id, moderator: caller,
                        },
                    ),
                );
        }

        fn reject_chapter(ref self: ContractState, chapter_id: felt252, reason: felt252) {
            let caller = get_caller_address();
            let mut chapter = self.chapters.entry(chapter_id).read();

            assert(chapter.status == 0, IPStoryErrors::CHAPTER_ALREADY_REJECTED);

            let is_moderator = self.story_moderators.entry(chapter.story_id).entry(caller).read();
            assert(is_moderator, IPStoryErrors::NOT_AUTHORIZED_TO_MODERATE);

            chapter.status = 2; // rejected
            self.chapters.entry(chapter_id).write(chapter);

            // Remove from pending chapters
            self._remove_from_pending_chapters(chapter.story_id, chapter_id);

            self
                .emit(
                    Event::ChapterRejected(
                        ChapterRejected {
                            chapter_id: chapter_id,
                            story_id: chapter.story_id,
                            moderator: caller,
                            reason: reason,
                        },
                    ),
                );
        }

        fn mint_chapter_nft(ref self: ContractState, chapter_id: felt252) -> u256 {
            let caller = get_caller_address();
            let mut chapter = self.chapters.entry(chapter_id).read();

            assert(chapter.author == caller, IPStoryErrors::ONLY_CHAPTER_AUTHOR_CAN_MINT);
            assert(chapter.status == 1, IPStoryErrors::CHAPTER_NOT_APPROVED);
            assert(!chapter.minted, IPStoryErrors::CHAPTER_ALREADY_MINTED);

            let token_id = self.next_token_id.read();

            // Mint NFT
            self.balances.entry((caller, token_id)).write(1);

            // Update chapter with NFT info
            chapter.minted = true;
            chapter.nft_token_id = token_id;
            self.chapters.entry(chapter_id).write(chapter);

            // Store token metadata
            let token_metadata = TokenMetadata {
                chapter_id: chapter_id, uri: self._generate_token_uri(chapter_id),
            };
            self.token_metadata.entry(token_id).write(token_metadata);

            self.next_token_id.write(token_id + 1);

            self
                .emit(
                    Event::ChapterMinted(
                        ChapterMinted {
                            chapter_id: chapter_id, author: caller, token_id: token_id,
                        },
                    ),
                );

            self
                .emit(
                    Event::TransferSingle(
                        TransferSingle {
                            operator: caller,
                            from: starknet::contract_address_const::<0>(),
                            to: caller,
                            id: token_id,
                            value: 1,
                        },
                    ),
                );

            token_id
        }

        // Moderation Functions
        fn add_moderator(ref self: ContractState, story_id: felt252, moderator: ContractAddress) {
            let caller = get_caller_address();
            let story = self.stories.entry(story_id).read();

            assert(story.creator == caller, IPStoryErrors::ONLY_STORY_CREATOR);

            let is_already_moderator = self
                .story_moderators
                .entry(story_id)
                .entry(moderator)
                .read();
            assert(!is_already_moderator, IPStoryErrors::MODERATOR_ALREADY_EXISTS);

            self.story_moderators.entry(story_id).entry(moderator).write(true);
            self.story_moderator_list.entry(story_id).push(moderator);

            self
                .emit(
                    Event::ModeratorAdded(
                        ModeratorAdded {
                            story_id: story_id, moderator: moderator, added_by: caller,
                        },
                    ),
                );
        }

        fn remove_moderator(
            ref self: ContractState, story_id: felt252, moderator: ContractAddress,
        ) {
            let caller = get_caller_address();
            let story = self.stories.entry(story_id).read();

            assert(story.creator == caller, IPStoryErrors::ONLY_STORY_CREATOR);
            assert(moderator != story.creator, IPStoryErrors::CANNOT_REMOVE_STORY_CREATOR);

            let is_moderator = self.story_moderators.entry(story_id).entry(moderator).read();
            assert(is_moderator, IPStoryErrors::MODERATOR_NOT_FOUND);

            self.story_moderators.entry(story_id).entry(moderator).write(false);
            self._remove_from_moderator_list(story_id, moderator);

            self
                .emit(
                    Event::ModeratorRemoved(
                        ModeratorRemoved {
                            story_id: story_id, moderator: moderator, removed_by: caller,
                        },
                    ),
                );
        }

        fn set_moderation_rules(ref self: ContractState, story_id: felt252, new_rules: felt252) {
            let caller = get_caller_address();
            let mut story = self.stories.entry(story_id).read();

            assert(story.creator == caller, IPStoryErrors::ONLY_STORY_CREATOR);

            story.governance_rules = new_rules;
            self.stories.entry(story_id).write(story);

            self
                .emit(
                    Event::ModerationRulesUpdated(
                        ModerationRulesUpdated { story_id: story_id, new_rules: new_rules },
                    ),
                );
        }

        // Royalty Functions
        fn claim_royalties(ref self: ContractState, story_id: felt252) {
            let caller = get_caller_address();
            let _ = self.stories.entry(story_id).read();

            let balance = self.royalty_balances.entry((story_id, caller)).read();
            assert(balance > 0, IPStoryErrors::NO_ROYALTIES_TO_CLAIM);

            self.royalty_balances.entry((story_id, caller)).write(0);

            self
                .emit(
                    Event::RoyaltiesClaimed(
                        RoyaltiesClaimed {
                            story_id: story_id, contributor: caller, amount: balance,
                        },
                    ),
                );
        }

        fn distribute_royalties(ref self: ContractState, story_id: felt252, amount: u256) {
            let caller = get_caller_address();
            let story = self.stories.entry(story_id).read();

            assert(story.creator == caller, IPStoryErrors::ONLY_STORY_CREATOR);
            assert(amount > 0, IPStoryErrors::INSUFFICIENT_ROYALTY_FUNDS);

            // Get all approved chapters for this story
            let story_chapters = self.story_chapters.entry(story_id);
            let chapters_count = story_chapters.len();

            if chapters_count > 0 {
                let amount_per_chapter = amount / chapters_count.into();
                let mut i = 0;
                loop {
                    if i >= chapters_count {
                        break;
                    }
                    let chapter_id = story_chapters.at(i).read();
                    let chapter = self.chapters.entry(chapter_id).read();

                    let current_balance = self
                        .royalty_balances
                        .entry((story_id, chapter.author))
                        .read();
                    self
                        .royalty_balances
                        .entry((story_id, chapter.author))
                        .write(current_balance + amount_per_chapter);

                    i = i + 1;
                };
            }

            let current_total = self.story_total_royalties.entry(story_id).read();
            self.story_total_royalties.entry(story_id).write(current_total + amount);

            self
                .emit(
                    Event::RoyaltiesDistributed(
                        RoyaltiesDistributed {
                            story_id: story_id, total_amount: amount, distributor: caller,
                        },
                    ),
                );
        }

        fn update_royalty_percentage(
            ref self: ContractState, story_id: felt252, new_percentage: u8,
        ) {
            let caller = get_caller_address();
            let mut story = self.stories.entry(story_id).read();

            assert(story.creator == caller, IPStoryErrors::ONLY_STORY_CREATOR);
            assert(new_percentage <= 100, IPStoryErrors::ROYALTY_PERCENTAGE_TOO_HIGH);

            story.royalty_percentage = new_percentage;
            self.stories.entry(story_id).write(story);

            self
                .emit(
                    Event::RoyaltyPercentageUpdated(
                        RoyaltyPercentageUpdated {
                            story_id: story_id, new_percentage: new_percentage,
                        },
                    ),
                );
        }

        // ERC1155 Functions
        fn balance_of(self: @ContractState, account: ContractAddress, token_id: u256) -> u256 {
            self.balances.entry((account, token_id)).read()
        }

        fn balance_of_batch(
            self: @ContractState, accounts: Array<ContractAddress>, token_ids: Array<u256>,
        ) -> Array<u256> {
            assert(accounts.len() == token_ids.len(), IPStoryErrors::ARRAY_LENGTH_MISMATCH);

            let mut balances: Array<u256> = array![];
            let mut i = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                let account = *accounts.at(i);
                let token_id = *token_ids.at(i);
                balances.append(self.balance_of(account, token_id));
                i = i + 1;
            }
            balances
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool,
        ) {
            let caller = get_caller_address();
            assert(caller != operator, IPStoryErrors::UNAUTHORIZED_ACCESS);

            self.operator_approvals.entry((caller, operator)).write(approved);

            self
                .emit(
                    Event::ApprovalForAll(
                        ApprovalForAll { account: caller, operator: operator, approved: approved },
                    ),
                );
        }

        fn is_approved_for_all(
            self: @ContractState, account: ContractAddress, operator: ContractAddress,
        ) -> bool {
            self.operator_approvals.entry((account, operator)).read()
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>,
        ) {
            let caller = get_caller_address();
            assert(
                from == caller || self.is_approved_for_all(from, caller),
                IPStoryErrors::CALLER_NOT_OWNER_OR_APPROVED,
            );
            assert(
                to != starknet::contract_address_const::<0>(),
                IPStoryErrors::TRANSFER_TO_ZERO_ADDRESS,
            );

            let from_balance = self.balances.entry((from, token_id)).read();
            assert(from_balance >= value, IPStoryErrors::INSUFFICIENT_BALANCE);

            self.balances.entry((from, token_id)).write(from_balance - value);
            let to_balance = self.balances.entry((to, token_id)).read();
            self.balances.entry((to, token_id)).write(to_balance + value);

            self
                .emit(
                    Event::TransferSingle(
                        TransferSingle {
                            operator: caller, from: from, to: to, id: token_id, value: value,
                        },
                    ),
                );
        }

        fn safe_batch_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Array<u256>,
            values: Array<u256>,
            data: Span<felt252>,
        ) {
            let caller = get_caller_address();
            assert(
                from == caller || self.is_approved_for_all(from, caller),
                IPStoryErrors::CALLER_NOT_OWNER_OR_APPROVED,
            );
            assert(
                to != starknet::contract_address_const::<0>(),
                IPStoryErrors::TRANSFER_TO_ZERO_ADDRESS,
            );
            assert(token_ids.len() == values.len(), IPStoryErrors::ARRAY_LENGTH_MISMATCH);

            let mut i = 0;
            loop {
                if i >= token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(i);
                let value = *values.at(i);

                let from_balance = self.balances.entry((from, token_id)).read();
                assert(from_balance >= value, IPStoryErrors::INSUFFICIENT_BALANCE);

                self.balances.entry((from, token_id)).write(from_balance - value);
                let to_balance = self.balances.entry((to, token_id)).read();
                self.balances.entry((to, token_id)).write(to_balance + value);

                i = i + 1;
            }

            self
                .emit(
                    Event::TransferBatch(
                        TransferBatch {
                            operator: caller, from: from, to: to, ids: token_ids, values: values,
                        },
                    ),
                );
        }

        // View Functions
        fn get_story_details(self: @ContractState, story_id: felt252) -> Story {
            self.stories.entry(story_id).read()
        }

        fn get_chapter_details(self: @ContractState, chapter_id: felt252) -> Chapter {
            self.chapters.entry(chapter_id).read()
        }

        fn get_story_chapters(self: @ContractState, story_id: felt252) -> Array<felt252> {
            let story_chapters = self.story_chapters.entry(story_id);
            let mut chapter_ids: Array<felt252> = array![];
            let len = story_chapters.len();
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                chapter_ids.append(story_chapters.at(i).read());
                i = i + 1;
            }
            chapter_ids
        }

        fn get_user_stories(self: @ContractState, creator: ContractAddress) -> Array<felt252> {
            let user_stories = self.user_stories.entry(creator);
            let mut story_ids: Array<felt252> = array![];
            let len = user_stories.len();
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                story_ids.append(user_stories.at(i).read());
                i = i + 1;
            }
            story_ids
        }

        fn get_user_chapters(self: @ContractState, author: ContractAddress) -> Array<felt252> {
            let user_chapters = self.user_chapters.entry(author);
            let mut chapter_ids: Array<felt252> = array![];
            let len = user_chapters.len();
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                chapter_ids.append(user_chapters.at(i).read());
                i = i + 1;
            }
            chapter_ids
        }

        fn is_moderator(self: @ContractState, story_id: felt252, user: ContractAddress) -> bool {
            self.story_moderators.entry(story_id).entry(user).read()
        }

        fn get_story_moderators(self: @ContractState, story_id: felt252) -> Array<ContractAddress> {
            let moderator_list = self.story_moderator_list.entry(story_id);
            let mut moderators: Array<ContractAddress> = array![];
            let len = moderator_list.len();
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                let moderator = moderator_list.at(i).read();
                if self.story_moderators.entry(story_id).entry(moderator).read() {
                    moderators.append(moderator);
                }
                i = i + 1;
            }
            moderators
        }

        fn get_pending_chapters(self: @ContractState, story_id: felt252) -> Array<felt252> {
            let pending_chapters = self.story_pending_chapters.entry(story_id);
            let mut chapter_ids: Array<felt252> = array![];
            let len = pending_chapters.len();
            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                chapter_ids.append(pending_chapters.at(i).read());
                i = i + 1;
            }
            chapter_ids
        }

        fn get_royalty_balance(
            self: @ContractState, story_id: felt252, contributor: ContractAddress,
        ) -> u256 {
            self.royalty_balances.entry((story_id, contributor)).read()
        }

        fn get_chapter_nft_uri(self: @ContractState, token_id: u256) -> felt252 {
            let token_metadata = self.token_metadata.entry(token_id).read();
            token_metadata.uri
        }

        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            // ERC1155 interface ID: 0xd9b67a26
            // ERC1155MetadataURI interface ID: 0x0e89341c
            interface_id == 0xd9b67a26 || interface_id == 0x0e89341c
        }
    }

    #[generate_trait]
    impl HelperImpl of HelperTrait {
        fn _remove_from_pending_chapters(
            ref self: ContractState, story_id: felt252, chapter_id: felt252,
        ) {
            let mut pending_chapters = self.story_pending_chapters.entry(story_id);
            let mut temp_chapters: Array<felt252> = array![];
            let len = pending_chapters.len();

            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                let current_chapter = pending_chapters.at(i).read();
                if current_chapter != chapter_id {
                    temp_chapters.append(current_chapter);
                }
                i = i + 1;
            }

            // Clear and repopulate
            let mut current_len = pending_chapters.len();
            while current_len > 0 {
                if let Option::Some(_) = pending_chapters.pop() {}
                current_len -= 1;
            }

            let mut j = 0;
            loop {
                if j >= temp_chapters.len() {
                    break;
                }
                pending_chapters.push(*temp_chapters.at(j));
                j = j + 1;
            };
        }

        fn _remove_from_moderator_list(
            ref self: ContractState, story_id: felt252, moderator: ContractAddress,
        ) {
            let mut moderator_list = self.story_moderator_list.entry(story_id);
            let mut temp_moderators: Array<ContractAddress> = array![];
            let len = moderator_list.len();

            let mut i = 0;
            loop {
                if i >= len {
                    break;
                }
                let current_moderator = moderator_list.at(i).read();
                if current_moderator != moderator {
                    temp_moderators.append(current_moderator);
                }
                i = i + 1;
            }

            // Clear and repopulate
            let mut current_len = moderator_list.len();
            while current_len > 0 {
                if let Option::Some(_) = moderator_list.pop() {}
                current_len -= 1;
            }

            let mut j = 0;
            loop {
                if j >= temp_moderators.len() {
                    break;
                }
                moderator_list.push(*temp_moderators.at(j));
                j = j + 1;
            };
        }

        fn _generate_token_uri(self: @ContractState, chapter_id: felt252) -> felt252 {
            // In a real implementation, this would generate a proper URI
            // For now, we'll return a placeholder based on chapter_id
            let base_uri = self.base_uri.read();
            // This is simplified - in practice you'd concatenate base_uri with chapter_id
            base_uri + chapter_id
        }
    }
}
