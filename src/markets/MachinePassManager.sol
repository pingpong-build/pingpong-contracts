// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IMachinePassManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MachinePassManager is Ownable, ERC721, IMachinePassManager {
    using Strings for uint256;

    /* ----------------------- Storage ------------------------ */

    /// @notice MachineMarket contract address
    address public machineMarketAddress;

    /// @notice Base uri for computing tokenURI
    string public baseURI;

    /// @notice Next token id
    uint256 public nextTokenId;

    /// @notice Tracks all pass type, indexed by pass type
    // pass type (1, 2, 3, 4...) => pass type
    mapping(uint256 => PassType) public types;

    /// @notice Tracks all nft types, indexed by nft token id
    // nft token id => pass type id
    mapping(uint256 => uint256) public nftTypes;

    /* --------------------- Constructor ---------------------- */

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) Ownable(msg.sender) {}


    /* ------------------- Admin functions -------------------- */

    /**
     * @notice Admin can set pass type
     * @param typeId The pass type id
     * @param token The payment token address
     * @param price The price of the pass
     */
    function setType(uint256 typeId, uint256 duration, address token, uint256 price) external onlyOwner {
        types[typeId].duration = duration;
        types[typeId].prices[token] = price;
        emit TypeUpdated(typeId, duration, token, price);
    }

    /**
     * @notice Admin can set machine market address
     * @param newMachineMarketAddress new machineMarketAddress
     */
    function setMachineMarketAddress(address newMachineMarketAddress) external onlyOwner {
        machineMarketAddress = newMachineMarketAddress;
        emit MachineMarketAddressUpdated(newMachineMarketAddress);
    }

    function rescueToken(address to, IERC20 token) external onlyOwner {
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
    function mint(address to, uint256 typeId, address token) public returns (uint256) {
        if (machineMarketAddress == address(0)) revert InvalidMachineMarketAddress();
        if (to == address(0)) revert InvalidToAddress();
        if (types[typeId].duration == 0) revert InvalidPassType();

        uint256 price = types[typeId].prices[token];
        if (price == 0) revert InvalidPassPriceToken();

        bool res = IERC20(token).transferFrom(msg.sender, machineMarketAddress, price);
        if (!res) revert TransferFailed();

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

    function getPassPrice(uint256 typeId, address token) public view returns (uint256) {
        return types[typeId].prices[token];
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
