use core::hash::{HashStateExTrait, HashStateTrait};
use core::pedersen::{PedersenTrait, pedersen};
use core::poseidon::poseidon_hash_span;
use starknet::ContractAddress;

pub trait LeadDataHasher<T, +Serde<T>> {
    fn hash<T, +Serde<T>>(self: @T) -> felt252;
}

#[derive(Debug, Clone, Drop, Serde)]
pub struct LeafData<T> {
    pub address: T,
    pub claim_contract_address: ContractAddress,
    pub entrypoint: felt252,
    pub data: Array<felt252>,
}

pub impl LeafDataHashImpl<T, +Serde<T>> of LeadDataHasher<T> {
    fn hash<T, +Serde<T>>(self: @T) -> felt252 {
        let mut serialized = array![];
        self.serialize(ref serialized);

        let hashed = poseidon_hash_span(serialized.span());

        let hash_state = PedersenTrait::new(0);
        pedersen(0, hash_state.update_with(hashed).update_with(1).finalize())
    }
}

