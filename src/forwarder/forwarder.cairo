// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^2.0.0

const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");
const FORWARDER_ROLE: felt252 = selector!("FORWARDER_ROLE");
use starknet::ContractAddress;
use starknet::eth_address::EthAddress;
use crate::types::{EthereumSignature, LeafData, LeafDataHashImpl, MerkleTreeKey};

#[starknet::interface]
pub trait IForwarder<T> {
    fn initialize_drop(ref self: T, merkle_tree_key: MerkleTreeKey, merkle_tree_root: felt252);

    fn verify_and_forward_ethereum(
        ref self: T,
        merkle_tree_key: MerkleTreeKey,
        proof: Span<felt252>,
        leaf_data: LeafData<EthAddress>,
        recipient: ContractAddress,
        eth_signature: EthereumSignature,
    );

    fn verify_and_forward_starknet(
        ref self: T,
        merkle_tree_key: MerkleTreeKey,
        proof: Span<felt252>,
        leaf_data: LeafData<ContractAddress>,
    );
}

#[starknet::contract]
mod Forwarder {
    use openzeppelin_access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_security::pausable::PausableComponent;
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use starknet::{ClassHash, ContractAddress};
    use crate::forwarder::ForwarderComponent;
    use super::*;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    //
    component!(path: ForwarderComponent, storage: forwarder, event: ForwarderEvent);

    // External
    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;

    // Internal
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl ForwarderInternalImpl = ForwarderComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        //
        #[substorage(v0)]
        forwarder: ForwarderComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        //
        #[flat]
        ForwarderEvent: ForwarderComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        default_admin: ContractAddress,
        upgrader: ContractAddress,
        forwarder: ContractAddress,
    ) {
        self.accesscontrol.initializer();

        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, default_admin);
        self.accesscontrol._grant_role(UPGRADER_ROLE, upgrader);
        self.accesscontrol._grant_role(FORWARDER_ROLE, forwarder);
    }

    #[abi(embed_v0)]
    impl ForwarderImpl of IForwarder<ContractState> {
        fn initialize_drop(
            ref self: ContractState, merkle_tree_key: MerkleTreeKey, merkle_tree_root: felt252,
        ) {
            self.accesscontrol.assert_only_role(FORWARDER_ROLE);
            self.forwarder.initialize_drop(merkle_tree_key, merkle_tree_root);
        }

        fn verify_and_forward_ethereum(
            ref self: ContractState,
            merkle_tree_key: MerkleTreeKey,
            proof: Span<felt252>,
            leaf_data: LeafData<EthAddress>,
            recipient: ContractAddress,
            eth_signature: EthereumSignature,
        ) {
            self.accesscontrol.assert_only_role(FORWARDER_ROLE);

            self
                .forwarder
                .verify_and_forward_ethereum(
                    merkle_tree_key, proof, leaf_data, recipient, eth_signature,
                );
        }

        fn verify_and_forward_starknet(
            ref self: ContractState,
            merkle_tree_key: MerkleTreeKey,
            proof: Span<felt252>,
            leaf_data: LeafData<ContractAddress>,
        ) {
            self.accesscontrol.assert_only_role(FORWARDER_ROLE);

            self.forwarder.verify_and_forward_starknet(merkle_tree_key, proof, leaf_data);
        }
    }

    //
    // Pausable
    //

    #[generate_trait]
    impl PausableExternalImpl of PausableExternalTrait {
        #[external(v0)]
        fn pause(ref self: ContractState) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.pausable.pause();
        }

        #[external(v0)]
        fn unpause(ref self: ContractState) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.pausable.unpause();
        }
    }

    //
    // Upgradeable
    //

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.accesscontrol.assert_only_role(UPGRADER_ROLE);
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
