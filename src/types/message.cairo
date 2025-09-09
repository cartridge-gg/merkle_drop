use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::snip12::{SNIP12Metadata, StructHash};
use starknet::ContractAddress;

const MESSAGE_TYPE_HASH: felt252 = selector!("\"Message\"(\"Claim on starknet with\":\"ContractAddress\")");

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
        'Merkle Drop Claim'
    }

    fn version() -> felt252 {
        '1'
    }
}
