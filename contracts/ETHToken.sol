// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenMintERC20Token is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address initialOwner // The address that will be the owner of the contract
    ) ERC20(name, symbol) {
        _mint(initialOwner, initialSupply); // Mint initial tokens to the owner
        _transferOwnership(msg.sender);
    }

    // Burn function to destroy tokens from the owner's account
    function burn(uint256 amount) public onlyOwner {
        _burn(msg.sender, amount);
    }
}
