// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BSCBridgeMintableToken is
    ERC20Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // Only the bridge contract can mint tokens
    address public bridgeContract;

    // Events to track minting and burning operations
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // Initializer function to replace constructor
    function initialize(
        string memory name,
        string memory symbol,
        address initialOwner
    ) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        __UUPSUpgradeable_init();

        // Transfer ownership to the provided owner
        _transferOwnership(initialOwner);
    }

    // Modifier to restrict actions to the bridge contract
    modifier onlyBridge() {
        require(msg.sender == bridgeContract, "Only bridge can mint/burn");
        _;
    }

    // Set the bridge contract address (one-time setup by owner)
    function setBridgeContract(address _bridgeContract) external onlyOwner {
        bridgeContract = _bridgeContract;
    }

    // Bridge contract mints tokens
    function mint(address to, uint256 amount) external onlyBridge {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    // Bridge contract burns tokens
    function burn(address from, uint256 amount) external onlyBridge {
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    // Authorization function for UUPS upgrades
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
