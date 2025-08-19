use core::poseidon::poseidon_hash_span;

pub trait LeadDataHasher<T, +Serde<T>> {
    fn hash<T, +Serde<T>>(self: @T) -> felt252;
}

#[derive(Debug, Clone, Drop, Serde)]
pub struct LeafData<T> {
    pub address: T,
    pub data: Array<felt252>,
}

pub impl LeafDataHashImpl<T, +Serde<T>> of LeadDataHasher<T> {
    fn hash<T, +Serde<T>>(self: @T) -> felt252 {
        let mut serialized = array![];
        self.serialize(ref serialized);

        poseidon_hash_span(serialized.span())
    }
}

