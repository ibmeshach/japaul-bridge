// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract JPGCPegged is ERC20, Ownable {
    constructor() ERC20("JPGC Pegged", "JPGC-B") Ownable(msg.sender) {
        // Removed Ownable(msg.sender);
    }

    // Mint function only callable by bridge contract
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Burn function only callable by bridge contract
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
