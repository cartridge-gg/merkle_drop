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
const SN_ADDRESS: ContractAddress = 0x9aa528ac622ad7cf637e5b8226f465da1080c81a2daeb37a97ee6246ae2301
    .try_into()
    .unwrap();

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

    // println!("     forwarder_address: 0x{:x}", forwarder_disp.contract_address);
    // println!("claim_contract_address: 0x{:x}", claim_disp.contract_address);

    (forwarder_disp, claim_disp)
}

#[test]
fn test_deploy() {
    let (forwarder_disp, claim_disp) = setup();
}

#[test]
fn test__initialize_drop() {
    let (forwarder_disp, claim_disp) = setup();

    let key = MerkleTreeKey {
        chain_id: 'ETHEREUM',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder"),
        salt: 0x123,
    };

    let init_root = 0x123;
    forwarder_disp.initialize_drop(key, init_root);

    let root = forwarder_disp.get_merkle_root(key);
    assert!(root == init_root, "invalid root")
}

#[test]
#[should_panic(expected: "merkle_drop: already initialized")]
fn test__initialize_drop_cannot_reiint() {
    let (forwarder_disp, claim_disp) = setup();

    let key = MerkleTreeKey {
        chain_id: 'ETHEREUM',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder"),
        salt: 0x123,
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
        salt: 0x123,
    };

    let root = 0x078a4171d7a74082438af64eb26ed803f136698a0cd4f7c5ff80a057e042b823;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data = LeafData::<
        EthAddress,
    > {
        address: ETH_ADDRESS.try_into().unwrap(),
        claim_contract_address: key.claim_contract_address,
        entrypoint: key.entrypoint,
        data: array![8, 21, 207, 295, 472, 570, 900, 943, 974],
    };

    let mut leaf_data_serialized = array![];
    leaf_data.serialize(ref leaf_data_serialized);

    let proof = array![
        0x049efe7c451054b64079a86c6f0df54aafb4b5e7cc0a9fc98fb6bd5de2280ad5,
        0x04bcafe857270465726cb2895f4da727446962660bbe1dae46555cd3f64bd17f,
        0x074efaae4e4c3b9bdc64c97a0e4a3848de7aaaf47d4be40b159303af8fef3e2d,
        0x03f622fa1f1329d1453bde872c5c6bb2f6a0fbc94fc811feb5ac63c0306c9df5,
        0x07b682376744cde36f6fd98286e4cee873beb8c5890fa05590edf79171cf8c32,
        0x03dc286e0fc2508659a71773faa6c79ae9b6195319cce70ebb51e456b36aac40,
        0x05a9eac042e7f9f20cbed2da69631f5a4dc2138f22b5feb0a94524b490becbcb,
        0x0768e0e76a2be560fb65cc228ad05ddaa84879d499793063f35ffe57e088d516,
        0x03daf8d4d1e545ab1c3f275339af1b80a38281bdc626a5cedfdb61ee486a002c,
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
    assert!(balance == 8, "invalid recipient balance")
}


#[test]
fn test__STARKNET_drop() {
    let (forwarder_disp, claim_disp) = setup();

    let key = MerkleTreeKey {
        chain_id: 'STARKNET',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder_with_extra_data"),
        salt: 0x123,
    };

    let root = 0x03d6e082642d2a98b04998020c24e993fec512d45e8e2c6738bf0c71998b39b6;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data = LeafData::<
        ContractAddress,
    > {
        address: SN_ADDRESS,
        claim_contract_address: key.claim_contract_address,
        entrypoint: key.entrypoint,
        data: array![
            20, 10, 20, 95, 231, 232, 323, 334, 393, 439, 460, 534, 537, 576, 704, 743, 808, 902,
            922, 928, 931, 933, 949,
        ],
    };

    let mut leaf_data_serialized = array![];
    leaf_data.serialize(ref leaf_data_serialized);

    let proof = array![
        0x0713a9fbd467722c207f41269abd3542ea6d71f605c730bf88fb3ed20b00ad5b,
        0x02aec2a0c5e96aaeffe2d674423574ad9c7b2c8ed29915b5f453f8aec06177f8,
        0x62d2ea592cdce23fc6c02d0d99858cdd9d8857aa03cbe703613a8ffd3c1090,
        0x04233a1040604b6262ea02d26eaf738fc846399f332ac1ddcfdde325ff98102c,
        0x04fb444aa4c91df19432e7737956bba76dc69a8cf5520529946d6eb90f831bf1,
        0xbdc9206817ac505bc65419c943fe8dec122d10051d515d8c681a3a5c1904c3,
        0xca85167f27bae2b7251f45e75e3a435b4379dcff27df436d819a8abc6f94d1,
        0x0623148f5a7eb3515b9da98e2d1345662f97192b1493466d521f959be39d86b0,
    ]
        .span();

    forwarder_disp
        .verify_and_forward(key, proof, leaf_data_serialized.span(), Option::None, Option::None);

    let balance_A = claim_disp.get_balance('TOKEN_A', SN_ADDRESS);
    assert!(balance_A == 20, "invalid recipient balance TOKEN_A")

    let balance_B = claim_disp.get_balance('TOKEN_B', SN_ADDRESS);
    assert!(balance_B == 10, "invalid recipient balance TOKEN_B")
}


#[test]
#[should_panic(expected: "merkle_drop: already consumed")]
fn test__STARKNET_drop_cannot_claim_twice() {
    let (forwarder_disp, claim_disp) = setup();

    let key = MerkleTreeKey {
        chain_id: 'STARKNET',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder_with_extra_data"),
        salt: 0x123,
    };

    let root = 0x03d6e082642d2a98b04998020c24e993fec512d45e8e2c6738bf0c71998b39b6;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data = LeafData::<
        ContractAddress,
    > {
        address: SN_ADDRESS,
        claim_contract_address: key.claim_contract_address,
        entrypoint: key.entrypoint,
        data: array![
            20, 10, 20, 95, 231, 232, 323, 334, 393, 439, 460, 534, 537, 576, 704, 743, 808, 902,
            922, 928, 931, 933, 949,
        ],
    };

    let mut leaf_data_serialized = array![];
    leaf_data.serialize(ref leaf_data_serialized);

    let proof = array![
        0x0713a9fbd467722c207f41269abd3542ea6d71f605c730bf88fb3ed20b00ad5b,
        0x02aec2a0c5e96aaeffe2d674423574ad9c7b2c8ed29915b5f453f8aec06177f8,
        0x62d2ea592cdce23fc6c02d0d99858cdd9d8857aa03cbe703613a8ffd3c1090,
        0x04233a1040604b6262ea02d26eaf738fc846399f332ac1ddcfdde325ff98102c,
        0x04fb444aa4c91df19432e7737956bba76dc69a8cf5520529946d6eb90f831bf1,
        0xbdc9206817ac505bc65419c943fe8dec122d10051d515d8c681a3a5c1904c3,
        0xca85167f27bae2b7251f45e75e3a435b4379dcff27df436d819a8abc6f94d1,
        0x0623148f5a7eb3515b9da98e2d1345662f97192b1493466d521f959be39d86b0,
    ]
        .span();

    forwarder_disp
        .verify_and_forward(key, proof, leaf_data_serialized.span(), Option::None, Option::None);

    forwarder_disp
        .verify_and_forward(key, proof, leaf_data_serialized.span(), Option::None, Option::None);
}


#[test]
#[should_panic(expected: "merkle_drop: invalid proof")]
fn test__STARKNET_drop_cannot_claim_with_invalid_proof() {
    let (forwarder_disp, claim_disp) = setup();

    let key = MerkleTreeKey {
        chain_id: 'STARKNET',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder_with_extra_data"),
        salt: 0x123,
    };

    let root = 0x03d6e082642d2a98b04998020c24e993fec512d45e8e2c6738bf0c71998b39b6;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data = LeafData::<
        ContractAddress,
    > {
        address: SN_ADDRESS,
        claim_contract_address: key.claim_contract_address,
        entrypoint: key.entrypoint,
        data: array![
            20, 10, 20, 95, 231, 232, 323, 334, 393, 439, 460, 534, 537, 576, 704, 743, 808, 902,
            922, 928, 931, 933, 949,
        ],
    };

    let mut leaf_data_serialized = array![];
    leaf_data.serialize(ref leaf_data_serialized);

    let proof = array![
        0x0713a9fbd467722c207f41269abd3542ea6d71f605c730bf88fb3ed20b00ad5b,
        0x02aec2a0c5e96aaeffe2d674423574ad9c7b2c8ed29915b5f453f8aec06177f8,
        0x62d2ea592cdce23fc6c02d0d99858cdd9d8857aa03cbe703613a8ffd3c1090,
        // 0x04233a1040604b6262ea02d26eaf738fc846399f332ac1ddcfdde325ff98102c,
        0x04fb444aa4c91df19432e7737956bba76dc69a8cf5520529946d6eb90f831bf1,
        0xbdc9206817ac505bc65419c943fe8dec122d10051d515d8c681a3a5c1904c3,
        0xca85167f27bae2b7251f45e75e3a435b4379dcff27df436d819a8abc6f94d1,
        0x0623148f5a7eb3515b9da98e2d1345662f97192b1493466d521f959be39d86b0,
    ]
        .span();

    forwarder_disp
        .verify_and_forward(key, proof, leaf_data_serialized.span(), Option::None, Option::None);
}
