use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::snip12::{SNIP12Metadata, StructHash};
use starknet::ContractAddress;

const MESSAGE_TYPE_HASH: felt252 =
    0x31d49010eb1269a2c40e193a2702a53c50f38a2ad3542040c0df09777bc0046;
//const MESSAGE_TYPE_HASH: felt252 = selector!("\"Claim\"(\"recipient\":\"ContractAddress\")");

#[derive(Copy, Drop, Hash)]
pub struct Message {
    pub recipient: ContractAddress,
}

impl StructHashImpl of StructHash<Message> {
    fn hash_struct(self: @Message) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(MESSAGE_TYPE_HASH).update_with(*self).finalize()
    }
}

impl SNIP12MetadataImpl of SNIP12Metadata {
    fn name() -> felt252 {
        'Merkle Drop'
    }

    fn version() -> felt252 {
        1
    }
}
