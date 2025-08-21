use openzeppelin_upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use starknet::eth_address::EthAddress;
use crate::consumer::example::{IClaimDispatcher, IClaimDispatcherTrait};
use crate::forwarder::{IForwarderABIDispatcher, IForwarderABIDispatcherTrait};
use crate::types::{EthereumSignature, LeafData, MerkleTreeKey};

const ADMIN: ContractAddress = 0x1111.try_into().unwrap();

// pk: 0x420
const ETH_ADDRESS: felt252 = 0x4884ABe82470adf54f4e19Fa39712384c05112be;

fn deploy_contract(name: ByteArray, calldata: @Array<felt252>) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(calldata).unwrap();
    contract_address
}

fn deploy_contract_and_upgrade(
    proxy: ByteArray, name: ByteArray, calldata: @Array<felt252>,
) -> ContractAddress {
    let proxy = declare(proxy).unwrap().contract_class();
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = proxy.deploy(@array![]).unwrap();

    let proxy_disp = IUpgradeableDispatcher { contract_address };
    proxy_disp.upgrade(*contract.class_hash);

    starknet::syscalls::call_contract_syscall(
        contract_address, selector!("initialize"), calldata.span(),
    );

    contract_address
}


fn setup() -> (IForwarderABIDispatcher, IClaimDispatcher) {
    let admin_address_felt: felt252 = ADMIN.into();
    let forwarder_address = deploy_contract(
        "Forwarder", @array![admin_address_felt, admin_address_felt, admin_address_felt],
    );
    let forwarder_disp = IForwarderABIDispatcher { contract_address: forwarder_address };

    // make claim_contract_address deterministic
    let claim_contract_address = deploy_contract_and_upgrade(
        "ClaimContractProxy", "ClaimContract", @array![forwarder_address.into()],
    );

    let claim_disp = IClaimDispatcher { contract_address: claim_contract_address };

    println!("     forwarder_address: 0x{:x}", forwarder_disp.contract_address);
    println!("claim_contract_address: 0x{:x}", claim_disp.contract_address);

    (forwarder_disp, claim_disp)
}

#[test]
fn test_deploy() {
    let (forwarder_disp, claim_disp) = setup();
}

#[test]
fn test___initialize_drop() {
    let (forwarder_disp, claim_disp) = setup();

    let key = MerkleTreeKey {
        chain_id: 'ETHEREUM',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder"),
    };

    let init_root = 0x123;
    forwarder_disp.initialize_drop(key, init_root);

    let root = forwarder_disp.get_merkle_root(key);
    assert!(root == init_root, "invalid root")
}

#[test]
#[should_panic(expected: "merkle_drop: already initialized")]
fn test___initialize_drop_cannot_reiint() {
    let (forwarder_disp, claim_disp) = setup();

    let key = MerkleTreeKey {
        chain_id: 'ETHEREUM',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder"),
    };

    let init_root = 0x123;
    forwarder_disp.initialize_drop(key, init_root);
    forwarder_disp.initialize_drop(key, 0x666);
}


// #[derive(Drop, Copy, Clone, Serde, PartialEq)]
// pub struct Data {
//     pub token_ids: Span<felt252>,
// }

// #[test]
// fn test_ser() {
//     let data = Data { token_ids: array![333, 444, 555].span() };

//     let mut res = array![];
//     data.serialize(ref res);
//     println!("{:?}", res);
// }

#[test]
fn test__ETHEREUM_drop() {
    let (forwarder_disp, claim_disp) = setup();

    let key = MerkleTreeKey {
        chain_id: 'ETHEREUM',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder"),
    };

    let root = 0x019de87d774d09f2224622078499527edf4aa5ed00c7a8858aa7d30ecebbfee7;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data = LeafData::<
        EthAddress,
    > {
        address: ETH_ADDRESS.try_into().unwrap(),
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder"),
        data: array![5, 297, 483, 678, 707, 865],
    };

    let mut leaf_data_serialized = array![];
    leaf_data.serialize(ref leaf_data_serialized);

    let proof = array![
        0x023bce5a12fbf63e57e6fac449daf28ab3dffa8a33a8760239cbcbdc7f2942ba,
        0x04a7333f0452b4c247b6644d40668321e2518ff662f13c59c3ac251e200abb08,
        0x03a00ff744b8c707c6d2d3954711ea9ab6d57eb354621a059e9933d11c1ee601,
        0x0390a96315e83779890d720a65c06dca215ff73c4069b2eb3e51283727c67875,
        0x04167089f6022f2532bf6dda89041f20c59c253b8d8175b4cd82384f1640309a,
        0x05ff3b592f62e2ce7b74c91838a0a5e93072ddcdc4d1507dd06d8da64d603416,
        0x03e73901a7b03974dbd851b2844f4d9e90cb09ed07e1b5247a8aaafb8183ac4b,
        0x023df1a6e2290fd02746ddb4f532acde71884d62656e8e11fc898de7275d1128,
        0x0112d9ba96008dc89ac84b09759ee62bbbf16485e319e9eb4d907b44d76c141f,
    ]
        .span();

    let recipient_address: ContractAddress =
        0x7db9cc4a5e5485becbde0c40e71af59d72c543dea4cdeddf3c54ba03fdf14eb
        .try_into()
        .unwrap();

    let signature = EthereumSignature {
        v: 28,
        r: 0x8a616cce850f16086b7f189ca3075e730cc8e3c891adb3ce6ff32e2ae5441fa4,
        s: 0x20b6bd7126554394b4d9ebc9b57f95aa21f0d84a1211499d5bc6ec4faad266e3,
    };

    forwarder_disp
        .verify_and_forward(
            key,
            proof,
            leaf_data_serialized.span(),
            Option::Some(recipient_address),
            Option::Some(signature),
        );

    let balance = claim_disp.get_balance('TOKEN_A', recipient_address);
    assert!(balance == 5, "invalid recipient balance")
}
// #[test]
// #[feature("safe_dispatcher")]
// fn test_cannot_increase_balance_with_zero_value() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let balance_before = safe_dispatcher.get_balance().unwrap();
//     assert(balance_before == 0, 'Invalid balance');

//     match safe_dispatcher.increase_balance(0) {
//         Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
//         Result::Err(panic_data) => {
//             assert(*panic_data.at(0) == 'Amount cannot be 0', *panic_data.at(0));
//         },
//     };
// }


