use starknet::ContractAddress;

#[starknet::interface]
pub trait IClaim<T> {
    fn claim_from_forwarder(ref self: T, recipient: ContractAddress, leaf_data: Span<felt252>);
}

#[derive(Drop, Copy, Clone, Serde, PartialEq)]
pub struct LeafData {
    token_A_ids: Span<felt252>,
    token_B_ids: Span<felt252>,
}

// #[derive(Drop, Copy, Clone, Serde, PartialEq)]
// pub struct LeafDataWithAmounts {
//     token_A_amount: u32,
//     token_B_amount: u32,
// }

#[starknet::contract]
mod ClaimContract {
    use super::*;

    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        forwarder_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, forwarder_address: ContractAddress) {
        self.forwarder_address.write(forwarder_address);
    }


    #[abi(embed_v0)]
    impl ClaimImpl of IClaim<ContractState> {
        fn claim_from_forwarder(
            ref self: ContractState, recipient: ContractAddress, leaf_data: Span<felt252>,
        ) {
            // MUST check caller is forwarder
            self.assert_caller_is_forwarder();

            // deserialize leaf_data
            let mut leaf_data = leaf_data;
            let _data = Serde::<LeafData>::deserialize(ref leaf_data);
            // then use recipient / data
        }
    }


    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_caller_is_forwarder(self: @ContractState) {
            let caller = starknet::get_caller_address();
            let forwarder_address = self.forwarder_address.read();
            assert!(caller == forwarder_address, "caller is not forwarder");
        }
    }
}
