// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Bridge is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    IERC20 public token;
    uint256 public nonce;
    mapping(uint256 => bool) public processedNonces;

    event TransferInitiatedOnSourceChain(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 indexed nonce,
        string targetChain
    );
    event TransferCompletedOnDestinationChain(
        address indexed to,
        uint256 amount,
        uint256 indexed nonce
    );
    event RelayerAdded(address indexed relayer, address indexed addedBy);
    event RelayerRemoved(address indexed relayer, address indexed removedBy);

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Invalid token address");
        token = IERC20(tokenAddress);

        // Grant deployer the admin role and the DEFAULT_ADMIN_ROLE
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // Function to add new relayers
    function addRelayer(address newRelayer) external onlyRole(ADMIN_ROLE) {
        require(newRelayer != address(0), "Invalid relayer address");
        require(!hasRole(RELAYER_ROLE, newRelayer), "Already a relayer");

        _grantRole(RELAYER_ROLE, newRelayer);
        emit RelayerAdded(newRelayer, msg.sender);
    }

    // Function to remove relayers
    function removeRelayer(address relayer) external onlyRole(ADMIN_ROLE) {
        require(hasRole(RELAYER_ROLE, relayer), "Not a relayer");

        _revokeRole(RELAYER_ROLE, relayer);
        emit RelayerRemoved(relayer, msg.sender);
    }

    // Lock tokens on source chain (e.g., Sepolia) and emit an event for cross-chain relayer
    function initiateTransfer(
        address to,
        uint256 amount,
        string memory targetChain
    ) external {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(bytes(targetChain).length > 0, "Invalid target chain");

        // Transfer tokens to this contract to lock them on the source chain
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        emit TransferInitiatedOnSourceChain(
            msg.sender,
            to,
            amount,
            nonce,
            targetChain
        );

        // Increment nonce to ensure unique transactions
        nonce = nonce + 1;
    }

    // Release tokens on destination chain (e.g., BSC) by minting to recipient address
    function completeTransfer(
        address to,
        uint256 amount,
        uint256 _nonce
    ) external onlyRole(RELAYER_ROLE) {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(!processedNonces[_nonce], "Transfer already processed");

        processedNonces[_nonce] = true;
        require(token.transfer(to, amount), "Transfer failed");

        emit TransferCompletedOnDestinationChain(to, amount, _nonce);
    }

    // View function to check if an address is a relayer
    function isRelayer(address account) external view returns (bool) {
        return hasRole(RELAYER_ROLE, account);
    }

    // View function to check if an address is an admin
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    // Placeholder for LayerZero Integration
    // Future modifications could add LayerZero message sending and receiving
    // Here, integrate cross-chain messaging to call initiateTransfer and completeTransfer
}
