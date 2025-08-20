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

    (forwarder_disp, claim_disp)
}

#[test]
fn test_deploy() {
    let (forwarder_disp, claim_disp) = setup();

    println!("     forwarder_address: 0x{:x}", forwarder_disp.contract_address);
    println!("claim_contract_address: 0x{:x}", claim_disp.contract_address);
    // forwarder_address: 0x366c14bcd226468d3f30999774e3a1fc4c49efcb6b1a0ca0fe5d54e5bc33e3f
// claim_contract_address: 0x24e1322e4a9f29289643fe8c21e2a869b98bb9df3fe5dfb3e285c100541ca62
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


#[test]
fn test__drop() {
    let (forwarder_disp, claim_disp) = setup();

    let key = MerkleTreeKey {
        chain_id: 'ETHEREUM',
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder"),
    };

    let root = 0x015a47b37ba1e8fb61474b55fc6104793650d7d6e99b3c44100c095c3188b9a9;
    forwarder_disp.initialize_drop(key, root);

    let leaf_data = LeafData::<
        EthAddress,
    > {
        address: ETH_ADDRESS.try_into().unwrap(),
        claim_contract_address: claim_disp.contract_address,
        entrypoint: selector!("claim_from_forwarder"),
        data: array![297, 483, 678, 707, 865],
    };

    let mut leaf_data_serialized = array![];
    leaf_data.serialize(ref leaf_data_serialized);

    let proof = array![
        0x02a0ebc09d4a568fd7f1ae663469247dbad163429ec54887b672162770ae45e0,
        0x0471f3483e0fb75722464e44568db264cb48b5545fb38ce2a146b36fe123a91e,
        0x046ed79819945532eb7744e8f5db1f871765899e7d74a09d838e64bc8d692e8b,
        0x27fb995695b667441728062fa5d47056ec65a530f0398b5980d07778e1126b,
        0x023c0f0d962ad65f5635c61e18b415c9dc58a53bcc219f98ad7d361fcc39d8e5,
        0x058fe8e0b2088c16abeb1ebf234a74a0f647a82e6d9244bbaaca6fbabeb68a79,
        0x0210059388023d26123bfa59e75fea7d80e8346687325deb7be99451362dbffb,
        0x0459777566b02cce6dc8fe4cdf86cbef91392ae37b52d814d48cc275f8b4d3c1,
        0x041bf2499ddd486ed85f8a865453a6bbf4dc4a1cbf3e9be814054e80fe2ae3fc,
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


