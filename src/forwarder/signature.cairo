use alexandria_bytes::byte_array_ext::ByteArrayTraitExt;
use starknet::ContractAddress;
use starknet::eth_address::EthAddress;
use starknet::eth_signature::verify_eth_signature;
use starknet::secp256_trait::signature_from_vrs;


pub fn verify_ethereum_signature(
    v: u32, r: u256, s: u256, eth_address: EthAddress, sn_address: ContractAddress,
) {
    // rebuild msg / msg hash with caller address
    let message = get_message(sn_address);
    let msg_hash = hash_message(@message);
    let signature = signature_from_vrs(v, r, s);

    // panic if invalid
    verify_eth_signature(msg_hash, signature, eth_address)
}

pub fn get_message(address: ContractAddress) -> ByteArray {
    let header: ByteArray = "Ethereum Signed Message:\n";
    // the signed message address formatting must match this one:
    // no leading zero
    // minuscules only
    let message: ByteArray = format!("Claim on starknet with: 0x{:x}", address);
    let message_len = format!("{}", message.len());

    format!("{}{}{}", header, message_len, message)
}

pub fn hash_message(message: @ByteArray) -> u256 {
    let mut bytes: ByteArray = ByteArrayTraitExt::new(0, array![]);
    let mut i = 0;

    bytes.append_u8(0x19); // "\x19"
    while i < message.len() {
        let char = message.at(i).unwrap();
        bytes.append_u8(char);
        i += 1;
    }

    let keccak_le = core::keccak::compute_keccak_byte_array(@bytes);

    let keccak_be = u256 {
        high: core::integer::u128_byte_reverse(keccak_le.low),
        low: core::integer::u128_byte_reverse(keccak_le.high),
    };
    keccak_be
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test__hash_message_valid() {
        let message = get_message(0x123456789abcdef.try_into().unwrap());
        let hash = hash_message(@message);
        assert!(
            hash == 0x5d83a04aea393df39186a38ded0f2c6ea638932632af7f729c7a2bb070034ea0,
            "invalid hash_message",
        );
    }

    #[test]
    fn test__verify_ethereum_signature_valid() {
        let eth_address: EthAddress = 0x4884ABe82470adf54f4e19Fa39712384c05112be
            .try_into()
            .unwrap();
        let sn_address: ContractAddress =
            0x07db9cc4a5e5485becbde0c40e71af59d72c543dea4cdeddf3c54ba03fdf14eb
            .try_into()
            .unwrap();

        let v = 28;
        let r = 0x8a616cce850f16086b7f189ca3075e730cc8e3c891adb3ce6ff32e2ae5441fa4;
        let s = 0x20b6bd7126554394b4d9ebc9b57f95aa21f0d84a1211499d5bc6ec4faad266e3;

        verify_ethereum_signature(v, r, s, eth_address, sn_address);
    }

    #[test]
    #[should_panic(expected: 'Invalid signature')]
    fn test__verify_ethereum_signature_invalid() {
        let eth_address: EthAddress = 0x4884ABe82470adf54f4e19Fa39712384c05112be
            .try_into()
            .unwrap();
        let sn_address: ContractAddress =
            0x07db9cc4a5e5485becbde0c40e71af59d72c543dea4cdeddf3c54ba03fdf14eb
            .try_into()
            .unwrap();

        let v = 28;
        let r = 0x8a616cce850f16086b7f189ca3075e730cc8e3c891adb3ce6ff32e2ae5400000; // modified
        let s = 0x20b6bd7126554394b4d9ebc9b57f95aa21f0d84a1211499d5bc6ec4faad266e3;

        verify_ethereum_signature(v, r, s, eth_address, sn_address);
    }
}
