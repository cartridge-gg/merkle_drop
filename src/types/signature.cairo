
#[derive(Drop, Copy, Clone, Serde, PartialEq)]
pub struct EthereumSignature {
    pub v: u32,
    pub r: u256,
    pub s: u256,
}
