## PP Contracts

### Base

Mapped GRT: 0xf135A23f315509412123F354e3fb4760d93A99EA

Mapped AKT: 0x7f981c871A03903e70e4c8C39b19EcacdeD51683

### How to work

Minter mints mapped token.

```solidity
function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    _mint(to, amount);
}
```
