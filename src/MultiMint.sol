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

    struct Claim {
        string id;
        uint256 amount;
        bytes signature;
    }

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

    function multiClaim(Claim[] memory claims) public {
        for (uint256 i = 0; i < claims.length; i++) {
            claim(claims[i]);
        }
    }

    function claim(Claim memory singleClaim) public {
        if (claimedIds[singleClaim.id]) {
            revert RepeatedID(singleClaim.id);
        }

        bytes32 signedHash = keccak256(abi.encodePacked(singleClaim.id, singleClaim.amount, msg.sender));

        address signer = ECDSA.recover(signedHash, singleClaim.signature);
        if (signer != proverAddress) {
            revert WrongSignature(singleClaim.id);
        }

        for (uint i = 0; i < tokens.length; i++) {
            IMockToken(tokens[i]).mint(msg.sender, singleClaim.amount);
        }

        userClaimedAmount[msg.sender] += singleClaim.amount;
        totalClaimedAmount += singleClaim.amount;
        claimedIds[singleClaim.id] = true;
        totalTxAmount += 1;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        for (uint i = 0; i < tokens.length; i++) {
            IMockToken(tokens[i]).mint(to, amount);
        }
    }
}
