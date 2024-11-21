// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BridgeMintableToken is ERC20, Ownable {
    // Only the bridge contract can mint tokens
    address public bridgeContract;

    // Flag to ensure the bridge contract can only be set once
    // bool public bridgeSet = false;

    // Events to track minting and burning operations
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    // Constructor takes token name, symbol, and initial owner address
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC20(name, symbol) {
        // Start with zero initial supply; only bridge will mint tokens as needed
        _transferOwnership(initialOwner);
    }

    modifier onlyBridge() {
        require(msg.sender == bridgeContract, "Only bridge can mint/burn");
        _;
    }

    // Set the bridge contract address (one-time setup by owner)
    function setBridgeContract(address _bridgeContract) external onlyOwner {
        // require(!bridgeSet, "Bridge contract already set");
        bridgeContract = _bridgeContract;
        // bridgeSet = true;
    }

    // Bridge contract mints tokens on BSC after receiving lock confirmation
    function mint(address to, uint256 amount) external onlyBridge {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    // Bridge contract burns tokens on BSC before unlocking them on Ethereum
    function burn(address from, uint256 amount) external onlyBridge {
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }
}
