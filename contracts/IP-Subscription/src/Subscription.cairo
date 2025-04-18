#[starknet::contract]
pub mod Subscription {
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::pedersen::PedersenTrait;
    use ip_subscription::interface::ISubscription;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_block_number, get_block_timestamp, get_caller_address};
    // Struct to hold subscription plan details
    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct SubscriptionPlan {
        price: u256,
        duration: u64, // Duration in seconds
        tier: felt252 // Subscription tier (e.g., basic, premium)
    }

    // Struct to hold subscriber information
    #[derive(Copy, Drop, starknet::Store)]
    struct SubscriberInfo {
        subscription_start: u64,
        subscription_end: u64,
        active: bool,
    }

    #[storage]
    struct Storage {
        // Mapping from plan ID to subscription plan details
        subscription_plans: Map<felt252, SubscriptionPlan>,
        // Mapping from subscriber address to subscriber information
        subscribers: Map<ContractAddress, SubscriberInfo>,
        // Owner of the contract, who can create subscription plans
        owner: ContractAddress,
        // Vector to store plan IDs for each subscriber
        subscriber_plan_ids: Map<ContractAddress, Vec<felt252>>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PlanCreated: PlanCreated,
        Subscribed: Subscribed,
        Unsubscribed: Unsubscribed,
        SubscriptionRenewed: SubscriptionRenewed,
        SubscriptionUpgraded: SubscriptionUpgraded,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PlanCreated {
        pub plan_id: felt252,
        pub price: u256,
        pub duration: u64,
        pub tier: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Subscribed {
        pub subscriber: ContractAddress,
        pub plan_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Unsubscribed {
        pub subscriber: ContractAddress,
        pub plan_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscriptionRenewed {
        pub subscriber: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscriptionUpgraded {
        pub subscriber: ContractAddress,
        pub new_plan_id: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl SubscriptionImpl of ISubscription<ContractState> {
        // Allows the owner to create a subscription plan
        // the plan_id is generated randomly inside this function
        fn create_plan(
            ref self: ContractState, price: u256, duration: u64, tier: felt252,
        ) -> felt252 {
            assert(get_caller_address() == self.owner.read(), 'Only owner can create plans');

            // Generate a random plan_id using block timestamp and block number
            let plan_id = generate_random_felt252(price, duration, tier);

            assert(self.subscription_plans.entry(plan_id).read().price == 0, 'Plan already exists');

            self
                .subscription_plans
                .entry(plan_id)
                .write(SubscriptionPlan { price: price, duration: duration, tier: tier });

            self
                .emit(
                    Event::PlanCreated(
                        PlanCreated {
                            plan_id: plan_id, price: price, duration: duration, tier: tier,
                        },
                    ),
                );

            plan_id
        }

        // Allows a user to subscribe to a plan
        fn subscribe(ref self: ContractState, plan_id: felt252) {
            let caller = get_caller_address();
            assert(self.subscription_plans.entry(plan_id).read().price != 0, 'Plan does not exist');

            let current_timestamp = get_block_timestamp();

            let mut subscriber_info = self.subscribers.entry(caller).read();
            if !subscriber_info.active {
                // If the user is not currently subscribed, initialize a new subscription
                subscriber_info =
                    SubscriberInfo {
                        subscription_start: current_timestamp, subscription_end: 0, active: true,
                    };
            }

            self.subscribers.entry(caller).write(subscriber_info);

            // Append the new plan_id to the user's list of subscriptions
            self.subscriber_plan_ids.entry(caller).push(plan_id);
            subscriber_info.subscription_end = current_timestamp
                + self.subscription_plans.entry(plan_id).read().duration;

            self.emit(Event::Subscribed(Subscribed { subscriber: caller, plan_id: plan_id }));
        }

        // Allows a user to unsubscribe from a specific plan
        fn unsubscribe(ref self: ContractState, plan_id: felt252) {
            let caller = get_caller_address();
            let mut subscriber_info = self.subscribers.entry(caller).read();
            let mut subscriber_plan_ids = self.subscriber_plan_ids.entry(caller);

            // Check if the user is subscribed to the plan
            let mut is_subscribed = false;
            let len: u64 = subscriber_plan_ids.len();
            let mut index: Option<u64> = Option::None;

            for i in 0..len {
                if subscriber_plan_ids.at(i).read() == plan_id {
                    is_subscribed = true;
                    index = Option::Some(i);
                    break;
                }
            }

            assert(is_subscribed, 'Not subscribed to this plan');

            // Remove the plan_id from the user's list of subscriptions
            if let Option::Some(i) = index {
                let mut temp_vec = array![];
                let len: u64 = subscriber_plan_ids.len();
                for j in 0..len {
                    if j != i {
                        temp_vec.append(subscriber_plan_ids.at(j).read());
                    }
                }

                // Clear the existing plan IDs
                let mut len: u64 = subscriber_plan_ids.len();
                while len != 0 {
                    if let Option::Some(_value) = subscriber_plan_ids.pop() {}
                    len -= 1;
                }

                // replace the new value
                for k in 0..temp_vec.len() {
                    subscriber_plan_ids.push(*temp_vec.at(k));
                }
            }

            if subscriber_plan_ids.len() == 0 {
                subscriber_info.active = false;
            }

            self.subscribers.entry(caller).write(subscriber_info);
            self.emit(Event::Unsubscribed(Unsubscribed { subscriber: caller, plan_id: plan_id }));
        }

        // Allows a user to renew their subscription
        fn renew_subscription(ref self: ContractState) {
            let caller = get_caller_address();
            let subscriber_info = self.subscribers.entry(caller).read();
            assert(subscriber_info.active, 'Not currently subscribed');

            let current_timestamp = get_block_timestamp();
            let subscriber_plan_ids = self.subscriber_plan_ids.entry(caller);
            let plan_id = subscriber_plan_ids
                .at(0)
                .read(); // Assuming the first plan is the one to renew
            let duration = self.subscription_plans.entry(plan_id).read().duration;

            let mut updated_subscriber_info = subscriber_info;
            updated_subscriber_info.subscription_end = current_timestamp + duration;
            self.subscribers.entry(caller).write(updated_subscriber_info);

            self.emit(Event::SubscriptionRenewed(SubscriptionRenewed { subscriber: caller }));
        }

        // Allows a user to upgrade their subscription to a new plan
        fn upgrade_subscription(ref self: ContractState, new_plan_id: felt252) {
            let caller = get_caller_address();
            let subscriber_info = self.subscribers.entry(caller).read();
            assert(subscriber_info.active, 'Not currently subscribed');
            assert(
                self.subscription_plans.entry(new_plan_id).read().price != 0, 'Plan does not exist',
            );

            let current_timestamp = get_block_timestamp();
            let duration = self.subscription_plans.entry(new_plan_id).read().duration;

            let mut updated_subscriber_info = subscriber_info;
            let mut subscriber_plan_ids = self.subscriber_plan_ids.entry(caller);

            let mut len: u64 = subscriber_plan_ids.len();
            while len != 0 {
                if let Option::Some(_value) = subscriber_plan_ids.pop() {}
                len -= 1;
            }
            // Add the new plan ID
            subscriber_plan_ids.push(new_plan_id);
            updated_subscriber_info.subscription_start = current_timestamp;
            updated_subscriber_info.subscription_end = current_timestamp + duration;
            self.subscribers.entry(caller).write(updated_subscriber_info);

            // self.subscriber_plan_ids.entry(caller).write(subscriber_plan_ids);

            self
                .emit(
                    Event::SubscriptionUpgraded(
                        SubscriptionUpgraded { subscriber: caller, new_plan_id: new_plan_id },
                    ),
                );
        }

        // Returns the subscription status of a user
        fn get_subscription_status(self: @ContractState) -> bool {
            let caller = get_caller_address();
            self.subscribers.entry(caller).read().active
        }

        // Returns the details of a subscription plan
        fn get_plan_details(self: @ContractState, plan_id: felt252) -> (u256, u64, felt252) {
            let plan = self.subscription_plans.entry(plan_id).read();
            (plan.price, plan.duration, plan.tier)
        }

        fn get_user_plan_ids(self: @ContractState) -> Array<felt252> {
            let caller = get_caller_address();
            let subscriber_plan_ids = self.subscriber_plan_ids.entry(caller);
            let mut plan_ids: Array<felt252> = array![];
            let len: u64 = subscriber_plan_ids.len();
            for i in 0..len {
                plan_ids.append(subscriber_plan_ids.at(i).read());
            }
            plan_ids
        }
    }

    // Helper function to generate a random felt252 value using block timestamp and block number
    fn generate_random_felt252(price: u256, duration: u64, tier: felt252) -> felt252 {
        let block_number = get_block_number();
        let timestamp = get_block_timestamp();

        let mut state = PedersenTrait::new(0)
            .update_with(block_number)
            .update_with(timestamp)
            .update_with(price.low)
            .update_with(price.high)
            .update_with(duration)
            .update_with(tier);
        let output = state.finalize();

        output
    }
}
