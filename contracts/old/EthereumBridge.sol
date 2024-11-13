// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EthereumBridge is Ownable {
    IERC20 public jpgcToken;
    mapping(bytes32 => bool) public processedTransactions;

    event Locked(address indexed from, uint256 amount, bytes32 indexed id);

    constructor(address _jpgcToken) Ownable(msg.sender) {
        jpgcToken = IERC20(_jpgcToken);
    }

    // Lock tokens on Ethereum
    function lockTokens(uint256 amount, bytes32 id) external {
        require(processedTransactions[id] == false, "Already processed");

        jpgcToken.transferFrom(msg.sender, address(this), amount);
        processedTransactions[id] = true;

        emit Locked(msg.sender, amount, id);
    }
}
