## PP Contracts

### Holesky

MINTER_ROLE=0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6

Mock GRT: 0x6Df4dC6B2E5991Ce296Cfc3B2A28087Bb09a0771

Mock LPT: 0xD8B053cE5386Af103e7b5232AEFcA9257c79646F

Bridger: 0xDa204Bb33a22fC5b732e388FaD18176c7EA69a00

MultiMint: 0x89178B0BcF803f442984DF1B1986eafAE23389D9

### Morph testnet

Minter: 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35

Mapped GRT: 0x67F89748Da3349e394A0474A2EF0BC380aE21f4b

Mapped LPT: 0x83576E2B35F858aB47E32A2e9B9Af6ea68BaD839

GRT StakerVault: 0xDF1dd95ec44Ac8237eFf23bf07654eD3Af0F9c58

LPT StakerVault: 0x17944e5F86BaB6252Be16088c1030f62B56d844F

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
