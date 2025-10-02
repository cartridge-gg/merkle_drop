use openzeppelin_upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, start_cheat_chain_id_global};
use starknet::eth_address::EthAddress;
use starknet::{ContractAddress, SyscallResultTrait};
use crate::consumer::example::{IClaimDispatcher, IClaimDispatcherTrait};
use crate::forwarder::{IForwarderABIDispatcher, IForwarderABIDispatcherTrait};
use crate::types::{EthereumSignature, LeafData, LeafDataHashImpl, MerkleTreeKey, Signature};

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
    )
        .unwrap_syscall();

    contract_address
}


fn setup() -> (IForwarderABIDispatcher, IClaimDispatcher, ContractAddress) {
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

    let eligible_account_address = deploy_contract(
        "SnAccount",
        @array![
            0x6b0aab388dc7b240801b5aa0722bfcd39a1f397e83d5c032c198b18594b665e,
        ] // public key for pk=0x420
    );
    // eligible_account_address : 0x4ce00ffd9b927a25b31291371af851a6d242c18c4e1668dd224484d4a09d556

    start_cheat_chain_id_global('SN_SEPOLIA');

    // println!("     forwarder_address: 0x{:x}", forwarder_disp.contract_address);
    // println!("claim_contract_address: 0x{:x}", claim_disp.contract_address);
    // println!("_eligible_account_address:0x{:x}", eligible_account_address);

    (forwarder_disp, claim_disp, eligible_account_address)
}

#[test]
fn test_deploy() {
    let (_forwarder_disp, _claim_disp, _eligible_account_address) = setup();
}

#[test]
fn test__initialize_drop() {
    let (forwarder_disp, claim_disp, _eligible_account_address) = setup();

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
    let (forwarder_disp, claim_disp, _eligible_account_address) = setup();

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
    let (forwarder_disp, claim_disp, _eligible_account_address) = setup();

    let key = MerkleTreeKey {
        chain_id: 'ETHEREUM',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder"),
        salt: 0x123,
    };

    // println!("claim_disp.contract_address: 0x{:x}", claim_disp.contract_address);

    let root = 0x2f677e32bf42f63aaa944c220b0664594fef1ecf440f07b17595d7443bcd68;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data = LeafData::<
        EthAddress,
    > {
        address: ETH_ADDRESS.try_into().unwrap(),
        index: 0,
        claim_contract_address: key.claim_contract_address,
        entrypoint: key.entrypoint,
        data: array![8, 21, 207, 295, 472, 570, 900, 943, 974],
    };

    let hash = LeafDataHashImpl::<LeafData<EthAddress>>::hash(@leaf_data);
    assert!(forwarder_disp.is_consumed(key, hash) == false, "invalid is_consumed");

    let mut leaf_data_serialized = array![];
    leaf_data.serialize(ref leaf_data_serialized);

    let proof = array![
        0x035a5e4d7ca1d53bf4e148de2adf32f77fb81746a77e64b4432fa501a7275dd6,
        0x07139c81f140c0b0d177e00d12393d430a4e09bc94589a307418bc8adfbc2cd0,
        0x0687db36c7c71f874569918fe929b2465b98dad234925fbc3fe08e1f240ea1cf,
        0x06109e68a53350228595b86d39c4aee537c838edbb351d7592fea8cd38e5e7c6,
        0x05cddc3065840dcd070214641880b91a916a0c8c3d45ec969595200440518f20,
        0x01c1cd2751dc4613574aaf642c4084c60d285c8764c0c9bc216cc256dcb33973,
        0x06aff68ea70c70044170b7069df98fffe3ba1f35c9b0a5852a80a52915bb5456,
        0x064139087092b6f0917b292d1fb075a8ad220faa8c995c9286e88c628caa47bf,
        0x07ceca3c8a14d4c3b542f5a1ef154d2c33bbcf25f43e2883790359f06c2dd6ed,
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
            recipient_address,
            Signature::Ethereum(signature),
        );

    let balance = claim_disp.get_balance('TOKEN_A', recipient_address);
    assert!(balance == 8, "invalid recipient balance")
    assert!(forwarder_disp.is_consumed(key, hash) == true, "invalid is_consumed");
}

#[test]
fn test__STARKNET_drop() {
    let (forwarder_disp, claim_disp, eligible_account_address) = setup();

    let key = MerkleTreeKey {
        chain_id: 'STARKNET',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder_with_extra_data"),
        salt: 0x123,
    };

    let root = 0x82bd6ad245913b137a6429d42069f399eca7f3c11aeaac345847e126d6b26f;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data = LeafData::<
        ContractAddress,
    > {
        address: eligible_account_address,
        index: 0,
        claim_contract_address: key.claim_contract_address,
        entrypoint: key.entrypoint,
        data: array![
            20, 10, 20, 95, 231, 232, 323, 334, 393, 439, 460, 534, 537, 576, 704, 743, 808, 902,
            922, 928, 931, 933, 949,
        ],
    };

    let hash = LeafDataHashImpl::<LeafData<ContractAddress>>::hash(@leaf_data);
    assert!(forwarder_disp.is_consumed(key, hash) == false, "invalid is_consumed");

    let mut leaf_data_serialized = array![];
    leaf_data.serialize(ref leaf_data_serialized);

    let proof = array![
        0xa7e945889cb19fa7e8ebe08ba50bf9a2316dbb96705d522a0ef7aedf029d86,
        0x05aae951f60b60db5be44e3e93a6767604a993d37ce3198a66866151448e6c1b,
        0x05512d7b868e2798ca12352a81931deccc60c465763a57f75d495cce45c7f3a6,
        0x02fc30b93a7c6ca00d7af0a626b376cfff355cc0fa52da102ef35a5903ac0487,
        0x36ffa3b63f2c2f7c7aedc1df36046697d10a405867b41dd4bb5b771bb1762f,
        0x02c7671e1f878b3a4f80596796f020e0fb035ae290c2bc4c505c09d4b926fdcc,
        0x03cbb025516f320bc9a0c48392148ceda1a34e5f3d80ad125a43f7a3104e39cd,
        0x019107c73a86d18e5ec02a6ecc97e01d057eb1b198fb7a84174e8573847b7be6,
        0x02527de293966795b7bc56c520a72c674fc2919729d64e7a84ec2165ccd4ae88,
    ]
        .span();

    forwarder_disp
        .verify_and_forward(
            key,
            proof,
            leaf_data_serialized.span(),
            SN_ADDRESS,
            Signature::Starknet(
                array![
                    2583498682322851288059727624983486435632732766748535066715239362221709468668,
                    3343726062384442414135196406685922125638025173513604381875603144030195394372,
                ]
                    .span(),
            ),
        );

    let balance_A = claim_disp.get_balance('TOKEN_A', SN_ADDRESS);
    assert!(balance_A == 20, "invalid recipient balance TOKEN_A")

    let balance_B = claim_disp.get_balance('TOKEN_B', SN_ADDRESS);
    assert!(balance_B == 10, "invalid recipient balance TOKEN_B")

    assert!(forwarder_disp.is_consumed(key, hash) == true, "invalid is_consumed");
}


#[test]
#[should_panic(expected: "merkle_drop: already consumed")]
fn test__STARKNET_drop_cannot_claim_twice() {
    let (forwarder_disp, claim_disp, eligible_account_address) = setup();

    let key = MerkleTreeKey {
        chain_id: 'STARKNET',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder_with_extra_data"),
        salt: 0x123,
    };

    let root = 0x82bd6ad245913b137a6429d42069f399eca7f3c11aeaac345847e126d6b26f;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data = LeafData::<
        ContractAddress,
    > {
        address: eligible_account_address,
        index: 0,
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
        0xa7e945889cb19fa7e8ebe08ba50bf9a2316dbb96705d522a0ef7aedf029d86,
        0x05aae951f60b60db5be44e3e93a6767604a993d37ce3198a66866151448e6c1b,
        0x05512d7b868e2798ca12352a81931deccc60c465763a57f75d495cce45c7f3a6,
        0x02fc30b93a7c6ca00d7af0a626b376cfff355cc0fa52da102ef35a5903ac0487,
        0x36ffa3b63f2c2f7c7aedc1df36046697d10a405867b41dd4bb5b771bb1762f,
        0x02c7671e1f878b3a4f80596796f020e0fb035ae290c2bc4c505c09d4b926fdcc,
        0x03cbb025516f320bc9a0c48392148ceda1a34e5f3d80ad125a43f7a3104e39cd,
        0x019107c73a86d18e5ec02a6ecc97e01d057eb1b198fb7a84174e8573847b7be6,
        0x02527de293966795b7bc56c520a72c674fc2919729d64e7a84ec2165ccd4ae88,
    ]
        .span();

    forwarder_disp
        .verify_and_forward(
            key,
            proof,
            leaf_data_serialized.span(),
            SN_ADDRESS,
            Signature::Starknet(
                array![
                    2583498682322851288059727624983486435632732766748535066715239362221709468668,
                    3343726062384442414135196406685922125638025173513604381875603144030195394372,
                ]
                    .span(),
            ),
        );

    forwarder_disp
        .verify_and_forward(
            key,
            proof,
            leaf_data_serialized.span(),
            SN_ADDRESS,
            Signature::Starknet(
                array![
                    2583498682322851288059727624983486435632732766748535066715239362221709468668,
                    3343726062384442414135196406685922125638025173513604381875603144030195394372,
                ]
                    .span(),
            ),
        );
}


#[test]
#[should_panic(expected: "merkle_drop: invalid proof")]
fn test__STARKNET_drop_cannot_claim_with_invalid_proof() {
    let (forwarder_disp, claim_disp, eligible_account_address) = setup();

    let key = MerkleTreeKey {
        chain_id: 'STARKNET',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder_with_extra_data"),
        salt: 0x123,
    };

    let root = 0x82bd6ad245913b137a6429d42069f399eca7f3c11aeaac345847e126d6b26f;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data = LeafData::<
        ContractAddress,
    > {
        address: eligible_account_address,
        index: 0,
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
        0xa7e945889cb19fa7e8ebe08ba50bf9a2316dbb96705d522a0ef7aedf029d86,
        0x05aae951f60b60db5be44e3e93a6767604a993d37ce3198a66866151448e6c1b,
        0x05512d7b868e2798ca12352a81931deccc60c465763a57f75d495cce45c7f3a6,
        0x02fc30b93a7c6ca00d7af0a626b376cfff355cc0fa52da102ef35a5903ac0487,
        0x36ffa3b63f2c2f7c7aedc1df36046697d10a405867b41dd4bb5b771bb1762f,
        0x02c7671e1f878b3a4f80596796f020e0fb035ae290c2bc4c505c09d4b926fdcc,
        // 0x03cbb025516f320bc9a0c48392148ceda1a34e5f3d80ad125a43f7a3104e39cd,
        0x019107c73a86d18e5ec02a6ecc97e01d057eb1b198fb7a84174e8573847b7be6,
        0x02527de293966795b7bc56c520a72c674fc2919729d64e7a84ec2165ccd4ae88,
    ]
        .span();

    forwarder_disp
        .verify_and_forward(
            key,
            proof,
            leaf_data_serialized.span(),
            SN_ADDRESS,
            Signature::Starknet(
                array![
                    2583498682322851288059727624983486435632732766748535066715239362221709468668,
                    3343726062384442414135196406685922125638025173513604381875603144030195394372,
                ]
                    .span(),
            ),
        );
}


#[test]
fn test__ETHEREUM_split_drop() {
    let (forwarder_disp, claim_disp, _eligible_account_address) = setup();

    let key = MerkleTreeKey {
        chain_id: 'ETHEREUM',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder"),
        salt: 0x0,
    };

    let root = 0x068807b1aa01b3add91a567648a08cdb2b572c16bab197b962bcd53d5d8a463a;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data_0 = LeafData::<
        EthAddress,
    > {
        address: ETH_ADDRESS.try_into().unwrap(),
        index: 0,
        claim_contract_address: key.claim_contract_address,
        entrypoint: key.entrypoint,
        data: array![5, 21, 207, 295, 472, 570],
    };
    let leaf_data_1 = LeafData::<
        EthAddress,
    > {
        address: ETH_ADDRESS.try_into().unwrap(),
        index: 1,
        claim_contract_address: key.claim_contract_address,
        entrypoint: key.entrypoint,
        data: array![3, 900, 943, 974],
    };

    let mut leaf_data_0_serialized = array![];
    leaf_data_0.serialize(ref leaf_data_0_serialized);

    let mut leaf_data_1_serialized = array![];
    leaf_data_1.serialize(ref leaf_data_1_serialized);

    let proof_0 = array![
        0x03d754b5a72d7a2ead1af45bdf6224371778af50159c3abc3751b331f3ea78b1,
        0x048db58af063baebac941e39ea6bb9bf1f0607d127a98eaf6d44f9bfabcd99c6,
        0x05f3ae9b50767ae195397620a9673cfff112e327ad52b66898b02a6e598059a1,
        0x0347652e426887551be3b9e07576fcd88fe478cfa0ff7f6a21d7500fed56ae34,
        0x023640dc81de140cb10b1eed5a134804133afd32000b6e3a20486d5f6d33d1,
        0x027b800e36f504b1bd2714b010c4e14e533ea0c4a6213159afb212459d6f67ae,
        0x07e49c11119e233e03f6f0393082526e55a8c8978503d089f06889477f48947a,
        0x0388a0971974410925d587ca417b2ab7fecafcca521fbccebaaf76de6dec4485,
        0x693d03da533577a268d488f8c548c909ab0bae49b296164ecee865124c517b,
    ]
        .span();

    let proof_1 = array![
        0x02c99f99afa0d5a643534a57824af47934570875126ff7ac9f0c000557000de8,
        0x048a26ff1a7f9e350e9dfa96e154b4fb0147d171ae39337b0969f7d80d4f6c76,
        0x04fa5ad4bf20c9c502da6898e266ee27682242300732bf5b954bb8d51c693d86,
        0x06a9412b73f28a0f753dd34e88171320a594320a3cb6eb43cfafb1cb37577f86,
        0x0189f5a4589b954fa7fa124b2b2aac69ed0331946a9cca67fad55e6924058996,
        0x063dbab8da3439c3d14b3cc79a137ee9fdbc10348c271d915226921d6a702369,
        0x07e49c11119e233e03f6f0393082526e55a8c8978503d089f06889477f48947a,
        0x0388a0971974410925d587ca417b2ab7fecafcca521fbccebaaf76de6dec4485,
        0x693d03da533577a268d488f8c548c909ab0bae49b296164ecee865124c517b,
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
            proof_0,
            leaf_data_0_serialized.span(),
            recipient_address,
            Signature::Ethereum(signature),
        );

    let balance = claim_disp.get_balance('TOKEN_A', recipient_address);
    assert!(balance == 5, "invalid recipient balance")

    forwarder_disp
        .verify_and_forward(
            key,
            proof_1,
            leaf_data_1_serialized.span(),
            recipient_address,
            Signature::Ethereum(signature),
        );

    let balance = claim_disp.get_balance('TOKEN_A', recipient_address);
    assert!(balance == 8, "invalid recipient balance")
}
