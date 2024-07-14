// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract MachinePassManager is AccessControl, ERC721 {
    using Strings for uint256;

    string public baseURI;
    uint256 public nextTokenId;

    struct PassType {
        uint256 duration; // in seconds
        mapping(address => uint256) prices; // Mapping of token address to price
    }

    // pass type id => pass type
    mapping(uint256 => PassType) public passTypes;

    // nft token id => pass type id
    mapping(uint256 => uint256) public nftTypes;

    /**
     * @dev Thrown when transfer failed
     */
    error TransferFailed();

    /**
     * @dev Thrown when pass type is wrong
     */
    error InvalidPassType(uint256 typeId);

    /**
     * @dev Thrown when pass price token is wrong
     */
    error InvalidPassPriceToken(address token);

    /**
     * @dev Thrown when to address is empty
     */
    error InvalidToAddress(address to);

    event PassTypeAdded(uint256 typeId, uint256 duration, uint256 price);

    event PassMinted(address to, uint256 tokenId, uint256 typeId, address token);

    event PassPriceAdded(uint256 typeId, address token, uint256 price);

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function setPassPrice(uint256 typeId, address token, uint256 price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        passTypes[typeId].prices[token] = price;
        emit PassPriceAdded(typeId, address(token), price);
    }

    function getPassDuration(uint256 tokenId) public view returns (uint256){
        return passTypes[nftTypes[tokenId]].duration;
    }

    function setBaseURI(string memory _baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _baseURI;
    }

    function setPassType(uint256 typeId, uint256 duration, uint256 price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        passTypes[typeId] = PassType(duration, price);
        emit PassTypeAdded(typeId, duration, price);
    }

    function mint(address to, uint256 typeId, address token) public {
        if (to == address(0)) {
            revert InvalidToAddress(to);
        }

        if (passTypes[typeId].duration == 0) {
            revert InvalidPassType(typeId);
        }

        if (passTypes[typeId].prices[token] == 0) {
            revert InvalidPassPriceToken(token);
        }

        PassType memory passType = passTypes[typeId];

        bool res = IERC20(passTypes[typeId].prices[token]).transferFrom(msg.sender, address(this), passType.prices[token]);
        if (!res) {
            revert TransferFailed();
        }

        uint256 tokenId = nextTokenId;
        _mint(to, tokenId);
        nftTypes[tokenId] = typeId;

        emit PassMinted(to, tokenId, typeId, token);

        nextTokenId++;

        return tokenId;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        uint256 typeId = nftTypes[tokenId];
        return string.concat(baseURI, typeId.toString());
    }

    function withdraw(address to, IERC20 token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 total = token.balanceOf(address(this));
        bool res = token.transfer(to, total);
        if (!res) {
            revert TransferFailed();
        }
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
