// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract MachineTickets is AccessControl, ERC721 {
    using Strings for uint256;

    string public baseURI;
    uint256 public nextTokenId;

    // payment token
    IERC20 public token;

    struct TicketType {
        uint256 duration; // in seconds
        uint256 price; // in token
    }

    // ticket type id => ticket type
    mapping(uint256 => TicketType) public ticketTypes;

    // nft token id => ticket type id
    mapping(uint256 => uint256) public nftTypes;

    /**
     * @dev Thrown when transfer failed
     */
    error TransferFailed();

    /**
     * @dev Thrown when ticket type is wrong
     */
    error InvalidTicketType(uint256 typeId);

    event TicketTypeAdded(uint256 typeId, uint256 duration, uint256 price);

    event TicketMinted(address to, uint256 tokenId, uint256 typeId);

    constructor(string memory _name, string memory _symbol, IERC20 _token) ERC721(_name, _symbol) {
        token = _token;
    }

    function getTicketDuration(uint256 tokenId) public view returns (uint256){
        return ticketTypes[nftTypes[tokenId]].duration;
    }

    function setBaseURI(string memory _baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _baseURI;
    }

    function setTicketType(uint256 typeId, uint256 duration, uint256 price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ticketTypes[typeId] = TicketType(duration, price);
        emit TicketTypeAdded(typeId, duration, price);
    }

    function mint(uint256 typeId) public {
        if (ticketTypes[typeId].duration == 0) {
            revert InvalidTicketType(typeId);
        }

        TicketType memory ticketType = ticketTypes[typeId];

        bool res = token.transferFrom(msg.sender, address(this), ticketType.price);
        if (!res) {
            revert TransferFailed();
        }

        _mint(msg.sender, nextTokenId);
        nextTokenId++;

        nftTypes[nextTokenId] = typeId;
        emit TicketMinted(msg.sender, nextTokenId, typeId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        uint256 typeId = nftTypes[tokenId];
        return string.concat(baseURI, typeId.toString());
    }

    function withdraw(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
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
