// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "./IMachinePassManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MachinePassManager is Ownable, ERC721, IMachinePassManager {
    using Strings for uint256;

    /* ----------------------- Storage ------------------------ */

    /// @notice Base uri for computing tokenURI
    string public baseURI;

    /// @notice Next token id
    uint256 public nextTokenId;

    /// @notice Tracks all pass type, indexed by pass type id
    // pass type id (1, 2, 3, 4...) => pass type
    mapping(uint256 => PassType) public types;

    /// @notice Tracks all nft types, indexed by nft token id
    // nft token id => pass type id
    mapping(uint256 => uint256) public nftTypes;

    /* --------------------- Constructor ---------------------- */

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}


    /* ------------------- Admin functions -------------------- */

    /**
     * @notice admin can set pass type
     * @param typeId The pass type id
     * @param token The payment token address
     * @param price The price of the pass
     */
    function setType(uint256 typeId, address token, uint256 price) external onlyOwner {
        types[typeId].prices[token] = price;
        emit TypeUpdated(typeId, token, price);
    }

    function withdraw(address to, IERC20 token) external onlyOwner {
        uint256 total = token.balanceOf(address(this));
        token.transfer(to, total);
    }

    /**
     * @notice Admin can set base uri
     * @param _baseURI The base uri
     */
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /* ----------------------- User functions ------------------------ */

    /**
     * @notice Allows users to mint a pass nft of a specified type by paying with the specified token.
     * @param to The address that will receive the minted NFT.
     * @param typeId The id of the pass type being minted.
     * @param token The address of the payment token.
     */
    function mint(address to, uint256 typeId, address token) public {
        if (to == address(0)) {
            revert InvalidToAddress(to);
        }

        if (types[typeId].duration == 0) {
            revert InvalidPassType(typeId);
        }

        if (types[typeId].prices[token] == 0) {
            revert InvalidPassPriceToken(token);
        }

        PassType memory passType = types[typeId];

        bool res = IERC20(types[typeId].prices[token]).transferFrom(msg.sender, address(this), passType.prices[token]);
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

    /* ----------------------- View functions ------------------------ */

    /**
     * @notice Get token url of pass nft
     * @param tokenId The pass nft token id
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        uint256 typeId = nftTypes[tokenId];
        return string.concat(baseURI, typeId.toString());
    }

    /**
     * @notice Get duration of pass nft
     * @param tokenId The pass nft token id
     */
    function getPassDuration(uint256 tokenId) public view returns (uint256) {
        return types[nftTypes[tokenId]].duration;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
