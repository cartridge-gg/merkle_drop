use starknet::ContractAddress;

#[starknet::interface]
pub trait IClaim<T> {
    fn claim_from_forwarder(ref self: T, recipient: ContractAddress, leaf_data: Span<felt252>);
    fn get_balance(self: @T, address: ContractAddress) -> u32;
}

#[derive(Drop, Copy, Clone, Serde, PartialEq)]
pub struct LeafData {
    pub token_ids: Span<felt252>,
}

// #[derive(Drop, Copy, Clone, Serde, PartialEq)]
// pub struct LeafDataWithAmounts {
//     pub token_A_amount: u32,
//     pub token_B_amount: u32,
// }

#[starknet::contract]
mod ClaimContract {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use super::*;

    #[storage]
    struct Storage {
        forwarder_address: ContractAddress,
        balance: Map<ContractAddress, u32>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, forwarder_address: ContractAddress) {
        self.forwarder_address.write(forwarder_address);
    }


    #[abi(embed_v0)]
    impl ClaimImpl of IClaim<ContractState> {
        fn get_balance(self: @ContractState, address: ContractAddress) -> u32 {
            self.balance.entry(address).read()
        }

        fn claim_from_forwarder(
            ref self: ContractState, recipient: ContractAddress, leaf_data: Span<felt252>,
        ) {
            // println!("recipient: 0x{:x}", recipient);
            // println!("leaf_data: {:?}", leaf_data);

            // MUST check caller is forwarder
            self.assert_caller_is_forwarder();

            // deserialize leaf_data
            let mut leaf_data = leaf_data;
            let data = Serde::<LeafData>::deserialize(ref leaf_data).unwrap();

            // then use recipient / data
            let amount = data.token_ids.len();

            // increase balance
            let balance = self.balance.entry(recipient).read();
            self.balance.entry(recipient).write(balance + amount);
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
