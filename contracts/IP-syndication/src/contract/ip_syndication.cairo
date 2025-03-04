///
/// @title IP Syndication Contract
/// @notice Implements an IP syndication protocol allowing fractionalized IP ownership
/// @dev Uses ERC20 for payments and a custom NFT contract for asset ownership tokens
///
#[starknet::contract]
pub mod IPSyndication {
    use core::num::traits::Zero;
    use ip_syndication::contract::asset_nft::{IAssetNFTDispatcher, IAssetNFTDispatcherTrait};
    use ip_syndication::errors::Errors;
    use ip_syndication::interface::{IIPSyndication};
    use ip_syndication::types::{IPMetadata, SyndicationDetails, Status, Mode, ParticipantDetails};
    use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, MutableVecTrait,
        Vec, VecTrait,
    };
    use starknet::{
        ContractAddress, get_block_timestamp, get_caller_address, contract_address_const,
        get_contract_address
    };

    #[storage]
    struct Storage {
        // IP Metadata
        ip_metadata: Map<u256, IPMetadata>, // ip_id -> IPMetadata
        ip_count: u256, // Counter for IP IDs
        // Syndication details
        syndication_details: Map<u256, SyndicationDetails>, // ip_id -> SyndicationDetails
        // Participant details
        ip_whitelist: Map<u256, Map<ContractAddress, bool>>, // ip_id -> address -> status 
        participant_addresses: Map<u256, Vec<ContractAddress>>, // ip_id -> Vec<ContractAddress> 
        participants_details: Map<
            u256, Map<ContractAddress, ParticipantDetails>
        >, // ip_id -> participant -> ParticipantDetails
        // External contract addresses
        asset_nft_address: ContractAddress, // Address of the NFT contract for minting ownership tokens
    }

    ///
    /// @notice Contract events for important state changes
    ///
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        IPRegistered: IPRegistered,
        ParticipantAdded: ParticipantAdded,
        DepositReceived: DepositReceived,
        SyndicationCompleted: SyndicationCompleted,
        WhitelistUpdated: WhitelistUpdated,
        SyndicationCancelled: SyndicationCancelled,
        AssetMinted: AssetMinted,
    }

    /// @notice Emitted when a new IP is registered for syndication
    #[derive(Drop, starknet::Event)]
    struct IPRegistered {
        owner: ContractAddress,
        price: u256,
        name: felt252,
        mode: Mode,
        token_id: u256,
        currency_address: ContractAddress,
    }

    /// @notice Emitted when a new participant joins a syndication
    #[derive(Drop, starknet::Event)]
    struct ParticipantAdded {
        ip_id: u256,
        participant: ContractAddress,
    }

    /// @notice Emitted when a deposit is received
    #[derive(Drop, starknet::Event)]
    struct DepositReceived {
        from: ContractAddress,
        amount: u256,
        total: u256,
    }

    /// @notice Emitted when a syndication reaches its funding goal
    #[derive(Drop, starknet::Event)]
    struct SyndicationCompleted {
        total_raised: u256,
        participant_count: u32,
        timestamp: u64,
    }

    /// @notice Emitted when whitelist status is updated for an address
    #[derive(Drop, starknet::Event)]
    struct WhitelistUpdated {
        address: ContractAddress,
        status: bool,
    }

    /// @notice Emitted when a syndication is cancelled
    #[derive(Drop, starknet::Event)]
    struct SyndicationCancelled {
        timestamp: u64,
    }

    /// @notice Emitted when a participant mints their ownership token
    #[derive(Drop, starknet::Event)]
    struct AssetMinted {
        recipient: ContractAddress,
        share: u256,
    }

    ///
    /// @notice Contract constructor
    /// @param asset_nft_address The address of the NFT contract for minting ownership tokens
    ///
    #[constructor]
    fn constructor(ref self: ContractState, asset_nft_address: ContractAddress) {
        self.asset_nft_address.write(asset_nft_address);
    }

    #[abi(embed_v0)]
    pub impl IIPSyndicationImpl of IIPSyndication<ContractState> {
        ///
        /// @notice Register a new IP for syndication
        /// @param price: The target fundraising amount for the IP
        /// @param name: The name of the IP
        /// @param description: The description of the IP
        /// @param uri: The URI pointing to IP metadata
        /// @param licensing_terms: Terms governing the usage rights
        /// @param mode: The syndication mode (Public or Whitelist)
        /// @param currency_address: The ERC20 token used for deposits
        /// @return The ID of the newly registered IP
        ///
        fn register_ip(
            ref self: ContractState,
            price: u256,
            name: felt252,
            description: ByteArray,
            uri: ByteArray,
            licensing_terms: felt252,
            mode: Mode,
            currency_address: ContractAddress,
        ) -> u256 {
            let caller = get_caller_address();
            assert(!price.is_zero(), Errors::PRICE_IS_ZERO);
            assert(!currency_address.is_zero(), Errors::INVALID_CURRENCY_ADDRESS);

            // Generate a new IP ID
            let ip_id = self.ip_count.read() + 1;

            // Set IP metadata
            let ip_metadata = IPMetadata {
                ip_id,
                owner: caller,
                price,
                name,
                description,
                uri,
                licensing_terms,
                token_id: ip_id
            };
            self.ip_metadata.entry(ip_id).write(ip_metadata);

            // Set syndication details with initial Pending status
            let syndication_details = SyndicationDetails {
                ip_id,
                status: Status::Pending,
                mode,
                total_raised: 0_u256,
                participant_count: self.get_participant_count(ip_id),
                currency_address,
            };
            self.syndication_details.entry(ip_id).write(syndication_details);

            // Update the IP counter
            self.ip_count.write(ip_id);

            // Emit event
            self
                .emit(
                    IPRegistered {
                        owner: caller, price, name, mode, token_id: ip_id, currency_address
                    }
                );

            ip_id
        }

        ///
        /// @notice Activate a pending syndication to start accepting deposits
        /// @param ip_id: The ID of the IP to activate
        /// @dev Only the IP owner can activate a syndication
        ///
        fn activate_syndication(ref self: ContractState, ip_id: u256) {
            // Validate caller is the IP owner
            let caller = get_caller_address();
            let ip_metadata = self.get_ip_metadata(ip_id);
            assert(ip_metadata.owner == caller, Errors::NOT_IP_OWNER);

            // Validate syndication is in Pending status
            let status = self.get_syndication_status(ip_id);
            assert(status == Status::Pending, Errors::SYNDICATION_IS_ACTIVE);

            // Update status to Active
            let mut syndication_details = self.get_syndication_details(ip_id);
            syndication_details.status = Status::Active;
            self.syndication_details.entry(ip_id).write(syndication_details);
        }

        ///
        /// @notice Deposit funds toward an IP syndication
        /// @param ip_id: The ID of the IP to deposit funds for
        /// @param amount: The amount of tokens to deposit
        /// @dev For whitelist mode, caller must be whitelisted
        ///
        fn deposit(ref self: ContractState, ip_id: u256, amount: u256) {
            let caller = get_caller_address();
            let mut syndication_details = self.syndication_details.entry(ip_id).read();

            // Validate syndication state and deposit amount
            assert(syndication_details.status == Status::Active, Errors::SYNDICATION_NON_ACTIVE);
            assert(!amount.is_zero(), Errors::AMOUNT_IS_ZERO);

            // Check if caller has sufficient balance
            assert(
                self._has_sufficient_funds(syndication_details.currency_address, amount),
                Errors::INSUFFICIENT_BALANCE
            );

            // Check whitelist status for whitelist mode
            if syndication_details.mode == Mode::Whitelist {
                assert(self.is_whitelisted(ip_id, caller), Errors::ADDRESS_NOT_WHITELISTED);
            }

            // Check if more deposits are needed
            let total_deposited = syndication_details.total_raised;
            let ip_price = self.get_ip_metadata(ip_id).price;
            assert(total_deposited < ip_price, Errors::FUNDRAISING_COMPLETED);

            // Calculate the actual deposit amount (cap at remaining amount needed)
            let remaining = ip_price - total_deposited;
            let deposit_amount = if amount > remaining {
                remaining
            } else {
                amount
            };

            // Add participant if first deposit
            let mut participant_details = self.get_participant_details(ip_id, caller);
            let current_deposit = participant_details.amount_deposited;

            if current_deposit == 0 && participant_details.address.is_zero() {
                // Initialize participant details for new participants
                participant_details.address = caller;
                participant_details.token_id = ip_id;

                // Add to participant list
                self.participant_addresses.entry(ip_id).append().write(caller);

                // Emit event for new participant
                self.emit(ParticipantAdded { ip_id, participant: caller });
            }

            // Update participant deposit
            participant_details.amount_deposited = current_deposit + deposit_amount;

            // Update syndication totals
            syndication_details.total_raised = total_deposited + deposit_amount;
            syndication_details.participant_count = self.get_participant_count(ip_id);

            // Emit deposit event
            self
                .emit(
                    DepositReceived {
                        from: caller,
                        amount: deposit_amount,
                        total: total_deposited + deposit_amount
                    }
                );

            // Check if target reached and update status if completed
            if total_deposited + deposit_amount >= ip_price {
                syndication_details.status = Status::Completed;
                self
                    .emit(
                        SyndicationCompleted {
                            total_raised: total_deposited + deposit_amount,
                            participant_count: self.get_all_participants(ip_id).len(),
                            timestamp: get_block_timestamp(),
                        }
                    );
            }

            // Save updated state
            self.syndication_details.entry(ip_id).write(syndication_details);
            self.participants_details.entry(ip_id).entry(caller).write(participant_details);

            // Transfer tokens from caller to contract
            self
                ._erc20_dispatcher(ip_id)
                .transfer_from(caller, get_contract_address(), deposit_amount);
        }

        ///
        /// @notice Get the count of participants for an IP
        /// @param ip_id: The ID of the IP
        /// @return The number of participants
        ///
        fn get_participant_count(self: @ContractState, ip_id: u256) -> u256 {
            self.participant_addresses.entry(ip_id).len().into()
        }

        ///
        /// @notice Get all participants for an IP
        /// @param ip_id: The ID of the IP
        /// @return A span containing all participant addresses
        ///
        fn get_all_participants(self: @ContractState, ip_id: u256) -> Span<ContractAddress> {
            let mut participants = array![];
            let count = self.get_participant_count(ip_id);

            let mut idx = 0;
            while (idx < count.try_into().unwrap()) {
                participants.append(self.participant_addresses.entry(ip_id).at(idx).read());
                idx += 1;
            };

            participants.span()
        }

        ///
        /// @notice Add or remove an address from the whitelist
        /// @param ip_id: The ID of the IP
        /// @param address: The address to update
        /// @param status: The new whitelist status (true for included, false for excluded)
        /// @dev Only the IP owner can update the whitelist and only in whitelist mode
        ///
        fn update_whitelist(
            ref self: ContractState, ip_id: u256, address: ContractAddress, status: bool
        ) {
            // Validate caller is the IP owner
            let caller = get_caller_address();
            let ip_metadata = self.get_ip_metadata(ip_id);
            let syndication_details = self.syndication_details.entry(ip_id).read();

            assert(ip_metadata.owner == caller, Errors::NOT_IP_OWNER);
            assert(syndication_details.status == Status::Active, Errors::SYNDICATION_NON_ACTIVE);
            assert(syndication_details.mode == Mode::Whitelist, Errors::NOT_IN_WHITELIST_MODE);

            // Update whitelist status
            self.ip_whitelist.entry(ip_id).entry(address).write(status);

            // Emit event
            self.emit(WhitelistUpdated { address, status });
        }

        ///
        /// @notice Check if an address is whitelisted for an IP
        /// @param ip_id: The ID of the IP
        /// @param address: The address to check
        /// @return True if the address is whitelisted, false otherwise
        ///
        fn is_whitelisted(self: @ContractState, ip_id: u256, address: ContractAddress) -> bool {
            self.ip_whitelist.entry(ip_id).entry(address).read()
        }

        ///
        /// @notice Cancel a syndication and refund all deposits
        /// @param ip_id: The ID of the IP
        /// @dev Only the IP owner can cancel a syndication and only if not completed
        ///
        fn cancel_syndication(ref self: ContractState, ip_id: u256) {
            // Validate caller is the IP owner
            let caller = get_caller_address();
            assert(self.get_ip_metadata(ip_id).owner == caller, Errors::NOT_IP_OWNER);

            // Validate syndication is in a cancellable state
            let status = self.get_syndication_details(ip_id).status;
            assert(
                status == Status::Active || status == Status::Pending,
                Errors::COMPLETED_OR_CANCELLED
            );

            // Update status to Cancelled
            let mut syndication_details = self.get_syndication_details(ip_id);
            syndication_details.status = Status::Cancelled;
            self.syndication_details.entry(ip_id).write(syndication_details);

            // Emit cancellation event
            self.emit(SyndicationCancelled { timestamp: get_block_timestamp() });

            // Process refunds for all participants
            self._refund(ip_id);
        }

        ///
        /// @notice Get the metadata for an IP
        /// @param ip_id: The ID of the IP
        /// @return The IP metadata
        ///
        fn get_ip_metadata(self: @ContractState, ip_id: u256) -> IPMetadata {
            self.ip_metadata.entry(ip_id).read()
        }

        ///
        /// @notice Get the syndication details for an IP
        /// @param ip_id: The ID of the IP
        /// @return The syndication details
        ///
        fn get_syndication_details(self: @ContractState, ip_id: u256) -> SyndicationDetails {
            self.syndication_details.entry(ip_id).read()
        }

        ///
        /// @notice Get the current status of a syndication
        /// @param ip_id: The ID of the IP
        /// @return The syndication status
        ///
        fn get_syndication_status(self: @ContractState, ip_id: u256) -> Status {
            self.get_syndication_details(ip_id).status
        }

        ///
        /// @notice Get the details for a participant in a syndication
        /// @param ip_id: The ID of the IP
        /// @param participant The address of the participant
        /// @return The participant details
        ///
        fn get_participant_details(
            self: @ContractState, ip_id: u256, participant: ContractAddress
        ) -> ParticipantDetails {
            self.participants_details.entry(ip_id).entry(participant).read()
        }

        ///
        /// @notice Mint a fractionalized ownership token for a participant
        /// @param ip_id: The ID of the IP
        /// @dev Only participants can mint their tokens and only after syndication is completed
        /// @dev Share amount is 1:1 with deposit amount (minus any refunds)
        ///
        fn mint_asset(ref self: ContractState, ip_id: u256) {
            let caller = get_caller_address();

            // Validate syndication state
            let ip_metadata = self.get_ip_metadata(ip_id);
            let syndication_details = self.get_syndication_details(ip_id);
            let mut participants_details = self.get_participant_details(ip_id, caller);

            assert(
                syndication_details.status == Status::Completed, Errors::SYNDICATION_NOT_COMPLETED
            );

            // Validate caller is a participant
            assert(self._is_participant(ip_id, caller), Errors::NON_SYNDICATE_PARTICIPANT);

            // Validate token hasn't already been minted
            assert(!participants_details.minted, Errors::ALREADY_MINTED);

            // Calculate share based on net deposit (1:1 ratio with amount deposited minus refunds)
            let share = participants_details.amount_deposited
                - participants_details.amount_refunded;

            // Mark as minted
            participants_details.minted = true;
            participants_details.share = share;
            self.participants_details.entry(ip_id).entry(caller).write(participants_details);

            // Emit mint event
            self.emit(AssetMinted { recipient: caller, share });

            // Mint token through the asset NFT contract
            IAssetNFTDispatcher { contract_address: self.asset_nft_address.read() }
                .mint(caller, ip_id, share);
        }
    }

    ///
    /// @notice Internal utility functions
    ///
    #[generate_trait]
    pub impl InternalFunctions of InternalFunctionsTrait {
        ///
        /// @notice Check if an address is a participant in a syndication
        /// @param ip_id: The ID of the IP
        /// @param participant The address to check
        /// @return True if the address is a participant, false otherwise
        ///
        fn _is_participant(
            self: @ContractState, ip_id: u256, participant: ContractAddress
        ) -> bool {
            let participants = self.get_all_participants(ip_id);

            let mut is_participant = false;
            let mut idx = 0;
            while (idx < participants.len()) {
                if *participants.at(idx) == participant {
                    is_participant = true;
                    break;
                }
                idx += 1;
            };
            is_participant
        }

        ///
        /// @notice Check if an address has sufficient token balance
        /// @param currency_address: The address of the ERC20 token
        /// @param amount: The amount to check
        /// @return True if the caller has sufficient balance, false otherwise
        ///
        fn _has_sufficient_funds(
            self: @ContractState, currency_address: ContractAddress, amount: u256
        ) -> bool {
            let erc20 = IERC20Dispatcher { contract_address: currency_address };
            erc20.balance_of(get_caller_address()) >= amount
        }

        ///
        /// @notice Process refunds for all participants when a syndication is cancelled
        /// @param ip_id: The ID of the IP
        /// @dev Calculates refund amount as deposit minus any previous refunds
        ///
        fn _refund(ref self: ContractState, ip_id: u256) {
            let depositors_len = self.participant_addresses.entry(ip_id).len();
            let mut idx = 0;

            // Process each participant
            while idx < depositors_len {
                let participant = self.participant_addresses.entry(ip_id).at(idx).read();
                let mut participant_details = self.get_participant_details(ip_id, participant);

                // Calculate refund amount (net of previous refunds)
                let amount = participant_details.amount_deposited
                    - participant_details.amount_refunded;

                assert(!amount.is_zero(), Errors::ALREADY_REFUNDED);

                // Update refunded amount
                participant_details.amount_refunded += amount;
                self
                    .participants_details
                    .entry(ip_id)
                    .entry(participant)
                    .write(participant_details);

                // Transfer tokens back to participant
                self._erc20_dispatcher(ip_id).transfer(participant, amount);

                idx += 1;
            }
        }

        ///
        /// @notice Create an ERC20 dispatcher for the token used by an IP
        /// @param ip_id: The ID of the IP
        /// @return An ERC20 contract dispatcher
        ///
        fn _erc20_dispatcher(self: @ContractState, ip_id: u256) -> IERC20Dispatcher {
            let contract_address = self.get_syndication_details(ip_id).currency_address;
            IERC20Dispatcher { contract_address }
        }
    }
}
