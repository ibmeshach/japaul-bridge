// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract JPGCToken is ERC20, AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    event BridgeAdded(address indexed bridgeAddress, address indexed addedBy);
    event BridgeRemoved(
        address indexed bridgeAddress,
        address indexed removedBy
    );
    event InitialMintPerformed(address indexed to, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    constructor(
        address initialMintReceiver,
        uint256 initialMintAmount
    ) ERC20("JPGC Token", "JPGC") {
        require(initialMintReceiver != address(0), "Invalid mint receiver");
        require(initialMintAmount > 0, "Invalid initial amount");

        // Grant the contract deployer the admin role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Grant the BRIDGE_ROLE to the initial bridge
        // _grantRole(BRIDGE_ROLE, initialBridge);

        // Mint initial supply to specified address
        _mint(initialMintReceiver, initialMintAmount);

        // emit BridgeAdded(initialBridge, msg.sender);
        emit InitialMintPerformed(initialMintReceiver, initialMintAmount);
    }

    // Function to transfer admin role to a new address (like a bridge operator contract)
    function transferAdmin(
        address newAdmin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAdmin != address(0), "Invalid admin address");
        require(newAdmin != msg.sender, "Already the admin");

        address oldAdmin = msg.sender;

        // Grant admin role to new address
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        // Revoke admin role from caller
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);

        emit AdminChanged(oldAdmin, newAdmin);
    }

    // Function to add new bridge addresses
    function addBridge(
        address newBridge
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newBridge != address(0), "Invalid bridge address");
        require(!hasRole(BRIDGE_ROLE, newBridge), "Bridge already exists");

        _grantRole(BRIDGE_ROLE, newBridge);
        emit BridgeAdded(newBridge, msg.sender);
    }

    // Function to remove bridge access
    function removeBridge(
        address bridge
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(BRIDGE_ROLE, bridge), "Bridge does not exist");

        _revokeRole(BRIDGE_ROLE, bridge);
        emit BridgeRemoved(bridge, msg.sender);
    }

    // Mint function for bridges to mint tokens on destination chain
    function mint(address to, uint256 amount) external onlyRole(BRIDGE_ROLE) {
        require(to != address(0), "Invalid mint recipient");
        require(amount > 0, "Invalid mint amount");
        _mint(to, amount);
    }

    // Burn function for bridges to burn tokens on source chain
    function burn(address from, uint256 amount) external onlyRole(BRIDGE_ROLE) {
        require(amount > 0, "Invalid burn amount");
        _burn(from, amount);
    }

    // View function to check if an address is a bridge
    function isBridge(address bridge) external view returns (bool) {
        return hasRole(BRIDGE_ROLE, bridge);
    }

    // View function to check if an address has admin role
    function isAdmin(address account) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }
}
