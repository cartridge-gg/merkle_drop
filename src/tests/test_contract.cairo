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

fn setup() -> (IForwarderABIDispatcher, IClaimDispatcher) {
    let admin_address_felt: felt252 = ADMIN.into();
    let forwarder_address = deploy_contract(
        "Forwarder", @array![admin_address_felt, admin_address_felt, admin_address_felt],
    );
    let forwarder_disp = IForwarderABIDispatcher { contract_address: forwarder_address };

    let claim_contract_address = deploy_contract(
        "ClaimContract", @array![forwarder_address.into()],
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

    let root = 0x04f62437709789fce6e111fb7aaecd04078136042ec81a0f53f32c8c7884bf2d;
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
        0x042a27058a977b14bb033e5daf508a60ead1f22a5576c08899e8be4c81e39377,
        0xb72259c3dbe23111ebb9b44fd713b0a313073c060352452802f89bef7fe284,
        0x0796d0efba69110bb3542064454a0996bb685b08fbefb04d7d1b299a54edc292,
        0x020126e1cd62542e792fc21ac81eb83fc0f4ced84f29e7102c7a6dacaef44eeb,
        0x06aeaa92656e20a87e5ea4a535092665299e840e9f7c603bca4a77dc0163d405,
        0x065bc9eafd4577564f986822bddeba913addac79e728b83005be3f7cdbf8cd06,
        0x04e5d7d879c3bd35fbf47d89be62474783c19e019b6c10ce47a2ad417f92b274,
        0x01695443d6ca9d90645139cd67f04ebbb0334be84b4b59e0e325ac710dac6413,
        0x0daecad22c4c31fd0d5b7142b654469dcf969c861d9452ced9910864be9c14,
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

    let balance = claim_disp.get_balance(recipient_address);
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


