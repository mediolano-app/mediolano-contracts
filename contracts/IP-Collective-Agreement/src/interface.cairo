pub mod asset;
pub mod ownership;
pub mod revenue;
pub mod license;
pub mod governance;
pub mod compliance;

pub use asset::{IIPAssetManager, IIPAssetManagerDispatcher, IIPAssetManagerDispatcherTrait};
pub use ownership::{
    IOwnershipRegistry, IOwnershipRegistryDispatcher, IOwnershipRegistryDispatcherTrait,
};
pub use revenue::{
    IRevenueDistribution, IRevenueDistributionDispatcher, IRevenueDistributionDispatcherTrait,
};
pub use license::{ILicenseManager, ILicenseManagerDispatcher, ILicenseManagerDispatcherTrait};
pub use governance::{IGovernance, IGovernanceDispatcher, IGovernanceDispatcherTrait};
pub use compliance::{IBerneCompliance, IBerneComplianceDispatcher, IBerneComplianceDispatcherTrait};
