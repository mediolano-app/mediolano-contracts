pub mod asset;
pub mod ownership;
pub mod revenue;
pub mod license;

pub use asset::{IIPAssetManager, IIPAssetManagerDispatcher, IIPAssetManagerDispatcherTrait};
pub use ownership::{
    IOwnershipRegistry, IOwnershipRegistryDispatcher, IOwnershipRegistryDispatcherTrait,
};
pub use revenue::{
    IRevenueDistribution, IRevenueDistributionDispatcher, IRevenueDistributionDispatcherTrait,
};
pub use license::{ILicenseManager, ILicenseManagerDispatcher, ILicenseManagerDispatcherTrait};
