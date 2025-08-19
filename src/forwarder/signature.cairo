use starknet::ContractAddress;
use starknet::eth_signature::{verify_eth_signature};
use starknet::eth_address::{EthAddress};
use starknet::secp256_trait::signature_from_vrs;
use alexandria_bytes::byte_array_ext::ByteArrayTraitExt;


pub fn verify_ethereum_signature(
    v: u32, r: u256, s: u256, eth_address: EthAddress, sn_address: ContractAddress,
) {
    // rebuild msg / msg hash with caller address
    let message = get_message(sn_address);
    let msg_hash = hash_message(message);

    let signature = signature_from_vrs(v, r, s);

    // panic if invalid
    verify_eth_signature(msg_hash, signature, eth_address)
}

pub fn get_message(address: ContractAddress) -> ByteArray {
    let header: ByteArray = "Ethereum Signed Message:\n";
    let message: ByteArray = format!("Claim on starknet with: 0x{:x}", address);
    let message_len = format!("{}", message.len());

    format!("{}{}{}", header, message_len, message)
}

pub fn hash_message(message: ByteArray) -> u256 {
    let mut bytes: ByteArray = ByteArrayTraitExt::new(0, array![]);
    let mut i = 0;

    bytes.append_u8(0x19); // "\x19"
    while i < message.len() {
        let char = message.at(i).unwrap();
        bytes.append_u8(char);
        i += 1;
    };

    core::keccak::compute_keccak_byte_array(@bytes)
}

