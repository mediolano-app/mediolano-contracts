#[starknet::contract]
pub mod IPSyndication {
    // use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use core::num::traits::Zero;
    use ip_syndication::errors::Errors;
    use ip_syndication::interface::{IIPSyndication};
    use ip_syndication::types::{IPMetadata, SyndicationDetails, Status, Mode, ParticipantDetails};


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
        //IP Metadata
        ip_metadata: Map<u256, IPMetadata>, // ip_id -> IPMetadata
        ip_count: u256,
        //Syndication details
        syndication_details: Map<u256, SyndicationDetails>, // ip_id -> SyndicationDetails
        // Participant details
        participants_deposit: Map<
            u256, Map<ContractAddress, u256>
        >, // ip_id -> address -> amount deposited
        ip_whitelist: Map<u256, Map<ContractAddress, bool>>, // ip_id -> address -> status 
        participant_addresses: Map<u256, Vec<ContractAddress>>, // ip_id -> Vec<ContractAddress> 
        participants_details: Map<
            u256, Map<ContractAddress, ParticipantDetails>
        >, // ip_id -> participant -> ParticipantDetails
    }


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

    #[derive(Drop, starknet::Event)]
    struct IPRegistered {
        owner: ContractAddress,
        price: u256,
        name: felt252,
        mode: Mode,
    }

    #[derive(Drop, starknet::Event)]
    struct ParticipantAdded {
        ip_id: u256,
        participant: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct DepositReceived {
        from: ContractAddress,
        amount: u256,
        total: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct SyndicationCompleted {
        total_raised: u256,
        participant_count: u32,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct WhitelistUpdated {
        address: ContractAddress,
        status: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct SyndicationCancelled {
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct AssetMinted {
        recipient: ContractAddress,
        share: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    pub impl IIPSyndicationImpl of IIPSyndication<ContractState> {
        // Register new IP for syndication
        fn register_ip(
            ref self: ContractState,
            price: u256,
            name: felt252,
            description: ByteArray,
            uri: ByteArray,
            licensing_terms: felt252,
            mode: Mode,
        ) {
            let caller = get_caller_address();
            assert(!price.is_zero(), Errors::PRICE_IS_ZERO);

            let ip_id = self.ip_count.read() + 1;

            // set metadata
            let ip_metadata = IPMetadata {
                ip_id, owner: caller, price, name, description, uri, licensing_terms,
            };

            self.ip_metadata.entry(ip_id).write(ip_metadata);

            // set syndication details
            let syndication_details = SyndicationDetails {
                ip_id,
                status: Status::Pending,
                mode,
                total_raised: 0_u256,
                participant_count: self.get_participant_count(ip_id),
            };

            self.syndication_details.entry(ip_id).write(syndication_details);

            self.ip_count.write(ip_id);

            // Emit event
            self.emit(IPRegistered { owner: caller, price, name, mode });
        }

        fn deposit(ref self: ContractState, ip_id: u256, amount: u256) {
            // Validations
            let caller = get_caller_address();
            let mut syndication_details = self.syndication_details.entry(ip_id).read();
            assert(syndication_details.status == Status::Active, Errors::SYNDICATION_NON_ACTIVE);
            assert(!amount.is_zero(), Errors::AMOUNT_IS_ZERO);

            // Check if whitelisted when in whitelist mode
            if syndication_details.mode == Mode::Whitelist {
                assert(self.is_whitelisted(caller, ip_id), Errors::ADDRESS_NOT_WHITELISTED);
            }

            // Check if more deposits are needed
            let total_deposited = syndication_details.total_raised;
            let ip_price = self.get_ip_metadata(ip_id).price;
            assert(total_deposited < ip_price, Errors::FUNDRAISING_COMPLETED);

            // Calculate the actual deposit amount (in case it exceeds the target)
            let remaining = ip_price - total_deposited;
            let deposit_amount = if amount > remaining {
                remaining
            } else {
                amount
            };

            // Add participant if first deposit
            let current_deposit = self.participants_deposit.entry(ip_id).entry(caller).read();
            if current_deposit == 0 {
                self.participant_addresses.entry(ip_id).append().write(caller);
                self.emit(ParticipantAdded { ip_id, participant: caller });
            }

            // Update participant deposit
            self
                .participants_deposit
                .entry(ip_id)
                .entry(caller)
                .write(current_deposit + deposit_amount);

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

            // Check if target reached
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

            let participants_details = ParticipantDetails {
                address: caller,
                amount_deposited: deposit_amount,
                minted: false,
                collection_id: 0, //TODO
            };

            self.syndication_details.entry(ip_id).write(syndication_details);
            self.participants_details.entry(ip_id).entry(caller).write(participants_details);
            //TODO: transfer funds to the contract
        }

        fn get_participant_count(self: @ContractState, ip_id: u256) -> u256 {
            self.participant_addresses.entry(ip_id).len().into()
        }

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

        // Add address to whitelist
        fn update_whitelist(
            ref self: ContractState, ip_id: u256, address: ContractAddress, status: bool
        ) {
            // Validations
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

        fn is_whitelisted(self: @ContractState, address: ContractAddress, ip_id: u256) -> bool {
            self.ip_whitelist.entry(ip_id).entry(address).read()
        }

        fn cancel_syndication(ref self: ContractState, ip_id: u256) {
            // Validations
            let caller = get_caller_address();
            assert(self.get_ip_metadata(ip_id).owner == caller, Errors::NOT_IP_OWNER);

            let status = self.get_syndication_details(ip_id).status;
            assert(
                status == Status::Active || status == Status::Pending,
                Errors::COMPLETED_OR_CANCELLED
            );

            // Update status
            let mut syndication_details = self.get_syndication_details(ip_id);
            syndication_details.status = Status::Cancelled;
            self.syndication_details.entry(ip_id).write(syndication_details);

            // Emit event
            self.emit(SyndicationCancelled { timestamp: get_block_timestamp() });
            // TODO: refund all deposits
        }

        fn get_ip_metadata(self: @ContractState, ip_id: u256) -> IPMetadata {
            self.ip_metadata.entry(ip_id).read()
        }
        fn get_syndication_details(self: @ContractState, ip_id: u256) -> SyndicationDetails {
            self.syndication_details.entry(ip_id).read()
        }

        fn get_syndication_status(self: @ContractState, ip_id: u256) -> Status {
            self.get_syndication_details(ip_id).status
        }

        fn get_participant_details(
            self: @ContractState, ip_id: u256, participant: ContractAddress
        ) -> ParticipantDetails {
            self.participants_details.entry(ip_id).entry(participant).read()
        }

        // Mint fractionalized asset
        fn mint_asset(ref self: ContractState, ip_id: u256) {
            // Validations
            let caller = get_caller_address();
            let ip_metadata = self.get_ip_metadata(ip_id);
            let syndication_details = self.get_syndication_details(ip_id);
            let mut participants_details = self.get_participant_details(ip_id, caller);
            assert(
                syndication_details.status == Status::Completed, Errors::SYNDICATION_NOT_COMPLETED
            );

            // Only participants can mint
            assert(self._is_participant(ip_id, caller), Errors::NON_SYNDICATE_PARTICIPANT);

            // Check if already minted
            assert(!participants_details.minted, Errors::ALREADY_MINTED);

            // Mark as minted
            participants_details.minted = true;
            self.participants_details.entry(ip_id).entry(caller).write(participants_details);

            // Calculate share percentage (deposit_amount / total_price) * 100
            let total_price = ip_metadata.price;
            let deposit_amount = participants_details.amount_deposited;
            let share = (deposit_amount * 10000)
                / total_price; // Multiply by 10000 to preserve 2 decimal points

            // Emit mint event
            self.emit(AssetMinted { recipient: caller, share });
            //TODO: mint token with appropriate fraction
        }
    }

    #[generate_trait]
    pub impl InternalFunctions of InternalFunctionsTrait {
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
    }
}
