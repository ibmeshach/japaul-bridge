// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./JPGCPegged.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BSCBridge is Ownable {
    JPGCPegged public peggedToken;
    mapping(bytes32 => bool) public processedTransactions;

    event Minted(address indexed to, uint256 amount, bytes32 indexed id);
    event Burned(address indexed from, uint256 amount, bytes32 indexed id);

    constructor(address _peggedToken) Ownable(msg.sender) {
        peggedToken = JPGCPegged(_peggedToken);
    }

    // Mint tokens on BSC
    function mintTokens(
        address to,
        uint256 amount,
        bytes32 id
    ) external onlyOwner {
        require(processedTransactions[id] == false, "Already processed");

        peggedToken.mint(to, amount);
        processedTransactions[id] = true;

        emit Minted(to, amount, id);
    }

    // Burn tokens on BSC to unlock them on Ethereum
    function burnTokens(uint256 amount, bytes32 id) external {
        require(processedTransactions[id] == false, "Already processed");

        peggedToken.burn(msg.sender, amount);
        processedTransactions[id] = true;

        emit Burned(msg.sender, amount, id);
    }
}
