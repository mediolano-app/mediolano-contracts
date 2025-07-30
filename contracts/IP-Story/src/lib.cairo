// SPDX-License-Identifier: MIT

pub mod errors;
pub mod events;

// Contract modules
pub mod factory;
pub mod interfaces;
pub mod registry;
pub mod revenue;
pub mod story;
pub mod types;

// Export main components
pub use errors::*;
pub use events::*;

// Export contract modules
pub use factory::IPStoryFactory;
pub use interfaces::*;
pub use registry::ModerationRegistry;
pub use revenue::RevenueManager;
pub use story::IPStory;
pub use types::*;
