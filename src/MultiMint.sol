// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IMockToken.sol";

contract MultiMint is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public proverAddress = 0x4a6A31787fcef281c426529061eD13aFFCD28724;

    uint256 public totalClaimedAmount;
    mapping(address => uint256) public userClaimedAmount;
    mapping(string => bool) public claimedIds;
    uint256 public totalTxAmount;

    address[] public tokens;

    /**
   * @dev Thrown when the signer is not prover address
     */
    error WrongSignature(string id);

    error RepeatedID(string id);

    constructor(address minter, address[] memory _tokens) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(MINTER_ROLE, msg.sender);

        tokens = _tokens;
    }

    function setTokens(address[] memory _tokens) public onlyRole(MINTER_ROLE) {
        tokens = _tokens;
    }

    function setProverAddress(address _proverAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        proverAddress = _proverAddress;
    }

    function claim(string memory id, uint256 amount, bytes memory proof) public {
        if (claimedIds[id]) {
            revert RepeatedID(id);
        }

        bytes32 signedHash = keccak256(abi.encodePacked(id, amount, msg.sender));

        address signer = ECDSA.recover(signedHash, proof);
        if (signer != proverAddress) {
            revert WrongSignature(id);
        }

        for (uint i = 0; i < tokens.length; i++) {
            IMockToken(tokens[i]).mint(msg.sender, amount);
        }

        userClaimedAmount[msg.sender] += amount;
        totalClaimedAmount += amount;
        claimedIds[id] = true;
        totalTxAmount += 1;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        for (uint i = 0; i < tokens.length; i++) {
            IMockToken(tokens[i]).mint(to, amount);
        }
    }
}
