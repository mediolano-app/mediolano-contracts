use starknet::ContractAddress;

/// Represents a unique identifier for a token within a collection.
/// The format is `<collection_id:token_id>`, where:
/// - `collection_id`: The unique identifier of the collection.
/// - `:`: A separator indicating the token component.
/// - `token_id`: The unique identifier of the token within the collection.
#[derive(Drop, Copy, Serde)]
pub struct Token {
    /// The unique identifier of the collection.
    pub collection_id: u256,
    /// The unique identifier of the token within the collection.
    pub token_id: u256,
}

/// Trait implementation for Token, providing utility functions.
#[generate_trait]
pub impl TokenImpl of TokenTrait {
    /// Constructs a `Token` from a `ByteArray` formatted as `<collection_id:token_id>`.
    ///
    /// # Arguments
    /// * `data` - A `ByteArray` containing the string representation of the token.
    ///
    /// # Returns
    /// * `Token` - The parsed token with `collection_id` and `token_id` fields.
    fn from_bytes(data: ByteArray) -> Token {
        let mut col_bytes = ""; // Holds bytes for collection_id
        let mut tok_bytes = ""; // Holds bytes for token_id
        let parsing_token: ByteArray = ":"; // Separator between collection_id and token_id
        let mut parsing_token_id = false; // Flag to indicate parsing token_id

        // Iterate through each byte in the input data
        for i in 0..data.len() {
            let byte = data.at(i).unwrap();
            // Check for separator
            if byte == parsing_token.at(0).unwrap() {
                parsing_token_id = true;
                continue;
            }
            // Append byte to the appropriate buffer
            if parsing_token_id {
                tok_bytes.append_byte(byte);
            } else {
                col_bytes.append_byte(byte);
            }
        }

        // Convert byte arrays to u256
        let collection_id = bytearray_to_u256(col_bytes);
        let token_id = bytearray_to_u256(tok_bytes);

        Token { collection_id, token_id }
    }
}

/// Represents a collection of tokens with associated metadata and ownership.
#[derive(Drop, Serde, starknet::Store)]
pub struct Collection {
    /// Name of the collection.
    pub name: ByteArray,
    /// Symbol representing the collection.
    pub symbol: ByteArray,
    /// Base URI for token metadata.
    pub base_uri: ByteArray,
    /// Owner of the collection.
    pub owner: ContractAddress,
    /// Address of the associated IP NFT contract.
    pub ip_nft: ContractAddress,
    /// Indicates if the collection is active.
    pub is_active: bool,
}

/// Represents data associated with a specific token.
#[derive(Drop, Serde, starknet::Store)]
pub struct TokenData {
    /// The unique identifier of the collection this token belongs to.
    pub collection_id: u256,
    /// The unique identifier of the token within the collection.
    pub token_id: u256,
    /// Owner of the token.
    pub owner: ContractAddress,
    /// URI pointing to the token's metadata.
    pub metadata_uri: ByteArray,
}

/// Stores statistics related to a collection.
#[derive(Drop, Serde, starknet::Store)]
pub struct CollectionStats {
    /// Total number of tokens minted in the collection.
    pub total_minted: u256,
    /// Total number of tokens burned in the collection.
    pub total_burned: u256,
    /// Total number of token transfers in the collection.
    pub total_transfers: u256,
    /// Timestamp of the last mint operation.
    pub last_mint_time: u64,
    /// Timestamp of the last burn operation.
    pub last_burn_time: u64,
    /// Timestamp of the last transfer operation.
    pub last_transfer_time: u64,
}

/// Helper function to convert a `ByteArray` containing a decimal string to `u256`.
///
/// # Arguments
/// * `bytes` - A `ByteArray` representing a decimal number as a string.
///
/// # Returns
/// * `u256` - The parsed unsigned integer value.
fn bytearray_to_u256(bytes: ByteArray) -> u256 {
    let mut result = 0_u256;
    // Iterate through each byte, converting ASCII digits to their numeric value
    for i in 0..bytes.len() {
        let byte = bytes.at(i).unwrap();
        let digit = byte - 48; // '0' = 48 in ASCII
        result = result * 10_u256 + digit.try_into().unwrap();
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bytearray_to_u256_single_digit() {
        let data: ByteArray = "7";
        let result = bytearray_to_u256(data);
        assert(result == 7_u256, 'single_digit_failed');
    }

    #[test]
    fn test_bytearray_to_u256_multiple_digits() {
        let data: ByteArray = "123456";
        let result = bytearray_to_u256(data);
        assert(result == 123456_u256, 'multi_digit_failed');
    }

    #[test]
    fn test_token_id_from_bytes_basic() {
        let data: ByteArray = "42:314";
        let token_id = TokenTrait::from_bytes(data);
        assert(token_id.collection_id == 42_u256, 'collection_id_parse_failed');
        assert(token_id.token_id == 314_u256, 'token_id_parse_failed');
    }

    #[test]
    fn test_token_id_from_bytes_large_numbers() {
        let data: ByteArray = "98765432109876543210:12345678901234567890";
        let token_id = TokenTrait::from_bytes(data);
        let expected_col: u256 = 98765432109876543210_u256;
        let expected_tok: u256 = 12345678901234567890_u256;

        assert(token_id.collection_id == expected_col, 'large_col_id_failed');
        assert(token_id.token_id == expected_tok, 'large_token_id_failed');
    }

    #[test]
    fn test_token_id_from_bytes_leading_zeros() {
        let data: ByteArray = "00042:0000314";
        let token_id = TokenTrait::from_bytes(data);
        assert(token_id.collection_id == 42_u256, 'leading_zeros_col_failed');
        assert(token_id.token_id == 314_u256, 'leading_zeros_token_failed');
    }
}
