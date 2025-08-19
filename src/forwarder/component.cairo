use starknet::ContractAddress;


#[starknet::component]
pub mod ForwarderComponent {
    use super::*;
    use core::num::traits::Zero;

    use starknet::eth_address::EthAddress;
    use starknet::syscalls::call_contract_syscall;
    use starknet::SyscallResultTrait;
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry,
    };

    use openzeppelin_merkle_tree::merkle_proof;

    use crate::forwarder::signature;
    use crate::types::{LeafData, LeafDataHashImpl, MerkleTreeKey, EthereumSignature};

    #[storage]
    pub struct Storage {
        pub merkle_tree_roots: Map<MerkleTreeKey, felt252>,
        pub fallen_leaves_hashes: Map<(MerkleTreeKey, felt252), bool>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        MerkleDropInitialized: MerkleDropInitialized,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct MerkleDropInitialized {
        #[key]
        pub chain_id: felt252,
        #[key]
        pub claim_contract_address: ContractAddress,
        #[key]
        pub entrypoint: felt252,
        pub merkle_tree_root: felt252,
    }


    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn verify_and_forward_ethereum(
            ref self: ComponentState<TContractState>,
            merkle_tree_key: MerkleTreeKey,
            proof: Span<felt252>,
            leaf_data: LeafData<EthAddress>,
            recipient: ContractAddress,
            eth_signature: EthereumSignature,
        ) {
            let merkle_root = self.assert_valid_merkle_root_and_get(merkle_tree_key);
            let eth_address = leaf_data.address;

            signature::verify_ethereum_signature(
                eth_signature.v, eth_signature.r, eth_signature.s, eth_address, recipient,
            );

            let leaf_hash = LeafDataHashImpl::<LeafData<EthAddress>>::hash(@leaf_data);
            self.assert_leaf_not_consumed_and_consume(merkle_tree_key, leaf_hash);
            self.assert_valid_proof(proof, merkle_root, leaf_hash);

            let data = leaf_data.data.span();
            self.forward(merkle_tree_key, recipient, data);
        }

        fn verify_and_forward_starknet(
            ref self: ComponentState<TContractState>,
            merkle_tree_key: MerkleTreeKey,
            proof: Span<felt252>,
            leaf_data: LeafData<ContractAddress>,
        ) {
            let merkle_root = self.assert_valid_merkle_root_and_get(merkle_tree_key);

            let leaf_hash = LeafDataHashImpl::<LeafData<ContractAddress>>::hash(@leaf_data);
            self.assert_leaf_not_consumed_and_consume(merkle_tree_key, leaf_hash);
            self.assert_valid_proof(proof, merkle_root, leaf_hash);

            let recipient = leaf_data.address;
            let data = leaf_data.data.span();
            self.forward(merkle_tree_key, recipient, data);
        }


        //
        // Helpers
        //

        fn forward(
            ref self: ComponentState<TContractState>,
            merkle_tree_key: MerkleTreeKey,
            recipient: ContractAddress,
            data: Span<felt252>,
        ) {
            let mut calldata = array![];
            recipient.serialize(ref calldata);
            data.serialize(ref calldata);

            call_contract_syscall(
                merkle_tree_key.claim_contract_address, merkle_tree_key.entrypoint, calldata.span(),
            )
                .unwrap_syscall();
        }

        // called by permissioned operator
        fn initialize_drop(
            ref self: ComponentState<TContractState>,
            merkle_tree_key: MerkleTreeKey,
            merkle_tree_root: felt252,
        ) {
            let maybe_root = self.merkle_tree_roots.entry(merkle_tree_key).read();
            assert!(maybe_root.is_zero(), "merkle_drop: already initialized");

            self.merkle_tree_roots.entry(merkle_tree_key).write(merkle_tree_root);
            self
                .emit(
                    MerkleDropInitialized {
                        chain_id: merkle_tree_key.chain_id,
                        claim_contract_address: merkle_tree_key.claim_contract_address,
                        entrypoint: merkle_tree_key.entrypoint,
                        merkle_tree_root,
                    },
                )
        }

        fn assert_valid_merkle_root_and_get(
            self: @ComponentState<TContractState>, merkle_tree_key: MerkleTreeKey,
        ) -> felt252 {
            let root = self.merkle_tree_roots.entry(merkle_tree_key).read();
            assert!(root.is_non_zero(), "merkle_drop: merkle root is 0");
            root
        }

        fn assert_leaf_not_consumed_and_consume(
            ref self: ComponentState<TContractState>,
            merkle_tree_key: MerkleTreeKey,
            leaf_hash: felt252,
        ) {
            let is_consumed = self.fallen_leaves_hashes.entry((merkle_tree_key, leaf_hash)).read();
            assert!(!is_consumed, "merkle_drop: already consumed");

            self.fallen_leaves_hashes.entry((merkle_tree_key, leaf_hash)).write(true);
        }

        fn assert_valid_proof(
            self: @ComponentState<TContractState>,
            proof: Span<felt252>,
            root: felt252,
            leaf_hash: felt252,
        ) {
            // using alexendria
            // let mut tree: MerkleTree<Hasher> = MerkleTreeImpl::<_, PoseidonHasherImpl>::new();
            // let root = self.merkle_tree_root.read();
            // assert(tree.verify(merkle_tree_root, leaf_hash, proof), 'merkle_drop: invalid
            // proof');

            // using OZ
            let is_valid = merkle_proof::verify_poseidon(proof, root, leaf_hash);
            assert!(is_valid, "merkle_drop: invalid proof");
        }
    }
}
