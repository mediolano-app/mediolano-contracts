
#[starknet::contract]
pub mod Subscription {
    use ip_subscription::interface::ISubscription;
    use core::starknet::{ContractAddress, get_caller_address};
    use core::starknet::storage::{Map, StoragePathEntry};
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    // Struct to hold subscription plan details
    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct SubscriptionPlan {
        price: u256,
        duration: u64, // Duration in seconds
        tier: felt252, // Subscription tier (e.g., basic, premium)
    }

    // Struct to hold subscriber information
    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct SubscriberInfo {
        plan_id: felt252,
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
        fn create_plan(
            ref self: ContractState,
            plan_id: felt252,
            price: u256,
            duration: u64,
            tier: felt252
        ) {
            assert(get_caller_address() == self.owner.read(), 'Only owner can create plans');
            assert(self.subscription_plans.entry(plan_id).read().price == 0, 'Plan already exists'); // Assuming default value for price is 0

            self.subscription_plans.entry(plan_id).write(SubscriptionPlan {
                price: price,
                duration: duration,
                tier: tier,
            });

            self.emit(Event::PlanCreated(PlanCreated {
                plan_id: plan_id,
                price: price,
                duration: duration,
                tier: tier,
            }));
        }

        // Allows a user to subscribe to a plan
        fn subscribe(ref self: ContractState, plan_id: felt252) {
            let caller = get_caller_address();
            assert(self.subscription_plans.entry(plan_id).read().price != 0, 'Plan does not exist');

            let current_timestamp = starknet::get_block_timestamp();

            self.subscribers.entry(caller).write(SubscriberInfo {
                plan_id: plan_id,
                subscription_start: current_timestamp,
                subscription_end: current_timestamp + self.subscription_plans.entry(plan_id).read().duration,
                active: true,
            });

            self.emit(Event::Subscribed(Subscribed {
                subscriber: caller,
                plan_id: plan_id,
            }));
        }

        // Allows a user to unsubscribe from their current plan
        fn unsubscribe(ref self: ContractState) {
            let caller = get_caller_address();
            assert(self.subscribers.entry(caller).read().active == true, 'Not currently subscribed');

            let mut subscriber_info = self.subscribers.entry(caller).read();
            subscriber_info.active = false;
            self.subscribers.entry(caller).write(subscriber_info);

            self.emit(Event::Unsubscribed(Unsubscribed { subscriber: caller }));
        }

        // Allows a user to renew their subscription
        fn renew_subscription(ref self: ContractState) {
            let caller = get_caller_address();
            assert(self.subscribers.entry(caller).read().active == true, 'Not currently subscribed');

            let current_timestamp = starknet::get_block_timestamp();
            let plan_id = self.subscribers.entry(caller).read().plan_id;
            let duration = self.subscription_plans.entry(plan_id).read().duration;

            let mut subscriber_info = self.subscribers.entry(caller).read();
            subscriber_info.subscription_end = current_timestamp + duration;
            self.subscribers.entry(caller).write(subscriber_info);

            self.emit(Event::SubscriptionRenewed(SubscriptionRenewed { subscriber: caller }));
        }

        // Allows a user to upgrade their subscription to a new plan
        fn upgrade_subscription(ref self: ContractState, new_plan_id: felt252) {
            let caller = get_caller_address();
            assert(self.subscribers.entry(caller).read().active == true, 'Not currently subscribed');
            assert(self.subscription_plans.entry(new_plan_id).read().price != 0, 'Plan does not exist');

            let current_timestamp = starknet::get_block_timestamp();
            let duration = self.subscription_plans.entry(new_plan_id).read().duration;

            let mut subscriber_info = self.subscribers.entry(caller).read();
            subscriber_info.plan_id = new_plan_id;
            subscriber_info.subscription_start = current_timestamp;
            subscriber_info.subscription_end = current_timestamp + duration;
            self.subscribers.entry(caller).write(subscriber_info);

            self.emit(Event::SubscriptionUpgraded(SubscriptionUpgraded {
                subscriber: caller,
                new_plan_id: new_plan_id,
            }));
        }

        // Returns the subscription status of a user
        fn get_subscription_status(self: @ContractState) -> bool {
            let caller = get_caller_address();
            self.subscribers.entry(caller).read().active
        }

        // Returns the details of a subscription plan
        fn get_plan_details(
            self: @ContractState,
            plan_id: felt252
        ) -> (u256, u64, felt252) {
            let plan = self.subscription_plans.entry(plan_id).read();
            (plan.price, plan.duration, plan.tier)
        }
    }
}
