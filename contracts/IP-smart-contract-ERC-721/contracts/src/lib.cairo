mod MIP;
mod MIPL;
mod components {
    pub mod Counter;
    pub mod ERC721Enumerable;
}

mod dev {
    pub mod EncryptedPreferencesRegistry;  
}

#[cfg(test)]
mod test {
    mod TestContract;
    mod encrypted_preferences_test;  
}

mod mock_contracts {
    pub mod Receiver;
}