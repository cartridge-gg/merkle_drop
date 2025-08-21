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

    let root = 0x04ab96f453c99bf262e658499fc369f5711ab1232d44e4b6f18fded1f6daee43;
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
        0x066e39a5d2d4723d803f449de56723b00668a879c89ca99deea16e271b486067,
        0x02644c696711ac69f6e47be4871b257c4f1e01759ba9c25319416812649c1b50,
        0x06465b2b8fe714c8f358d31eecc699fccb4f50bdf8760cdeacce1824bdb8ca95,
        0x0548a9da036809dffa408de9c84e935dd5fbfac33b714acedeabcd69eca3fc3f,
        0x3e631faf351715bf0ef92e746dcf26288f47ef5b50e241612710fc87ad3e7e,
        0x0291d2f413cef8acff3e4f6a939ec45f3aea13640af236a315937dab0e813f75,
        0x01a69824bbfc04bc381507bac6e836fc5e52fd3ebecf397d2faba575d61c89d3,
        0x054db4ee545cda1750d8fe7ca32a033ce5dca641116ae7b19f0c0edac65c5d2e,
        0x0181376f195d235c137a42246122f6e5f07a0ba60a938b484b41bbc326ab311e,
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

pub fn STARKNET_PROOF() -> Array<felt252> {
    array![
        0x0247e33257a7f0345a7783a124c36262d7b23506fd9c4f01f8a6007c25a53e4a,
        0x016153b7a29382b49a7233d335524e415ee5cc48403a5eed1b972a3ba12ca449,
        0x08e756f2bbe422d1e17b19170511b35e134c9e952e4bb38ee8e90e4cf9226a,
        0x07ec082aefc9265acdae8cc3323e9037e2537cd79f947b984341b4df403a5210,
        0x0167a2199272f2842840050662527775fedafdd87eba1247c07e78db75b82cd6,
        0x0408bc75d619e61daf50ca3cbe3180c3c0e260464dc170fbce3132122676acaa,
        0x01816f8c79e990857b989d912350a0b337062a07de96dc6005707d46d419aad8,
        0x05508e688cf62be34f9f832d45a094b46a16c779708c987ccdc8df6ce292bd9a,
        0x04246df82281f7aa65a99b2e76e66bdcfa91b3ac389f0f12bd451a03f0dc3bc8,
    ]
}

#[test]
fn test__STARKNET_drop() {
    let (forwarder_disp, claim_disp) = setup();

    let key = MerkleTreeKey {
        chain_id: 'STARKNET',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder_with_extra_data"),
    };

    let root = 0x0411aeeadabadc9471e14f90bdc1077597b74082bc1420105733f002661520be;
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

    let proof = STARKNET_PROOF().span();

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
    };

    let root = 0x0411aeeadabadc9471e14f90bdc1077597b74082bc1420105733f002661520be;
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

    let proof = STARKNET_PROOF().span();

    forwarder_disp
        .verify_and_forward(
            key, proof.clone(), leaf_data_serialized.span(), Option::None, Option::None,
        );

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
    };

    let root = 0x0411aeeadabadc9471e14f90bdc1077597b74082bc1420105733f002661520be;
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

    let mut proof = STARKNET_PROOF();
    let _ = proof.pop_front();

    forwarder_disp
        .verify_and_forward(
            key, proof.span(), leaf_data_serialized.span(), Option::None, Option::None,
        );
}
