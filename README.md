## PP Contracts

MINTER_ROLE=0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6

### Holesky


Mock GRT: 0x3E4511645086a6fabECbAf1c3eE152C067f0AedA

Mock LPT: 0xc144Bf0FF0Ff560784a881024ccA077ebaa5b163

Bridger: 0xbb3fB2aD154E6fCa6DCD35082843d3a5819431c1

BridgerV2:

MultiMint: 0x0888e9E350ae4ac703e1e78341B180A007C15105

### Morph testnet

Mapped GRT: 0xb17bE239cf3C15b33CB865D4AcE5e28aa883440B

Mapped LPT: 0x0d763880cc7E54749E4FE3065DB53DA839a8eF6b

GRT StakerVault: 0xaEBc89aFF5ad69D7Cf8B85C54D394Ad34D9c46bb

LPT StakerVault: 0x7d9F7399951C96C83dF20C4839cFcD1e79C9d7f6

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

```json
{
  "type": "function",
  "name": "mintWithId",
  "inputs": [
    { "name": "to", "type": "address", "internalType": "address" },
    { "name": "amount", "type": "uint256", "internalType": "uint256" },
    { "name": "id", "type": "string", "internalType": "string" }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
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
