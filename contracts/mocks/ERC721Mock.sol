// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Mock is ERC721 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC721(name, symbol) {
        _mint(msg.sender, supply);
    }
}