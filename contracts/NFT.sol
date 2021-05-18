// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "hardhat/console.sol";

contract NFT is ERC721 {

    constructor (
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
    
    }
    
    function mint(address _to, uint _tokenId) external {
        _mint(_to, _tokenId);
    }
}