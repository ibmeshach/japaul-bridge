// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TokenMintERC20Token is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // Prevent the implementation contract from being initialized
    }

    // Initializer function to replace constructor
    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address initialOwner
    ) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        __UUPSUpgradeable_init();

        _mint(initialOwner, initialSupply); // Mint initial tokens to the owner
        _transferOwnership(initialOwner); // Set the initial owner
    }

    // Burn function to destroy tokens from the owner's account
    function burn(uint256 amount) public onlyOwner {
        _burn(msg.sender, amount);
    }

    // Required by UUPSUpgradeable
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
