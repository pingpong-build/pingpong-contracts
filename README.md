## PP Contracts

### Sepolia

Mock GRT: 0xBd7260B122F7baD2b299C8D8f6dB7B9889f0aeb7

Mock AKT: 0x0658417F1Af705a20333Ac1b1B01A2Bf0c139eB3

Bridger: 0x67F89748Da3349e394A0474A2EF0BC380aE21f4b

### Morph testnet

Minter: 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35

Mapped GRT: 0x07511e0c7Ea791c396cc30Dbc2542FAF5D406294

Mapped LPT: 0x076EA2DE7675e0400C344fCeefE807c7E3646E3B

GRT StakerVault: 0x21045EE677E5c185C1dA54040f92e23400837652
LPT StakerVault: 0x488D475c85d1Fa5631Df265aAac98912EB66Ce0f

### How to work

`Bridger` will emit `Bridged` event, when user bridge token,

```solidity
 event Bridged(address token, address from, address to, uint256 amount);
```

abi:

```json
[
  {
    "type": "event",
    "name": "Bridged",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "from",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "to",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  }
]
```

Minter mints mapped token.

```solidity
function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    _mint(to, amount);
}
```

### StakerVault

```json
[{
  "type":"event",
  "name":"Deposit",
  "inputs":[{
    "name":"sender",
    "type":"address",
    "indexed":true,
    "internalType":"address"}
]
```
