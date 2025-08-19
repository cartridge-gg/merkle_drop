
use starknet::ContractAddress;

#[derive(Drop, Copy, Clone, Serde, PartialEq, Hash)]
pub struct MerkleTreeKey {
    pub chain_id: felt252,
    pub claim_contract_address: ContractAddress,
    pub entrypoint: felt252,
}