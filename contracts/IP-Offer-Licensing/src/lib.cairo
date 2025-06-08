mod interfaces;
pub mod IPOfferLicensing;
#[cfg(test)]
mod test;

pub use interfaces::IIPOfferLicensing;
pub use IPOfferLicensing::IPOfferLicensing as IPOfferLicensingContract;
