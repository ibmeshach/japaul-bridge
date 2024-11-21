// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// import "https://raw.githubusercontent.com/wormhole-foundation/wormhole-solidity-sdk/main/src/interfaces/IWormholeRelayer.sol";
// import "https://raw.githubusercontent.com/wormhole-foundation/wormhole-solidity-sdk/main/src/interfaces/IWormholeReceiver.sol";

import "./interfaces/IWormholeRelayer.sol";
import "./interfaces/IWormholeReceiver.sol";

contract ETHBridgeContract is IWormholeReceiver, Ownable, ReentrancyGuard {
    IERC20 public token;
    IWormholeRelayer public wormholeRelayer;

    uint256 public gasLimit = 200000;
    uint16 public senderChainId = 10002;
    uint256 public gasMultiplier = 3;
    uint256 public costMultiplier = 2;

    mapping(uint16 => bytes32) public registeredSenders;
    mapping(bytes32 => bool) public processedMessages;
    mapping(address => uint256) public unLockedTokens;

    mapping(address => uint256) public lockedTokens;
    mapping(uint16 => bool) public allowedTargetChains;

    event MessageReceived(
        address indexed sender,
        uint256 amount,
        uint16 sourceChain
    );
    event SourceChainLogged(uint16 sourceChain);
    event SenderRegistered(uint16 sourceChain, bytes32 sourceAddress);
    event TokensUnlocked(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    event TokensLocked(address indexed user, uint256 amount, uint256 timestamp);
    event ChainStatusUpdated(uint16 chain, bool status);
    event MultiplierUpdated(string multiplierType, uint256 newValue);

    constructor(address _token, address _wormholeRelayer) {
        require(_token != address(0), "Token address cannot be zero");
        require(
            _wormholeRelayer != address(0),
            "Wormhole relayer cannot be zero"
        );

        token = IERC20(_token);
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);

        _transferOwnership(msg.sender);
    }

    // receive
    modifier onlyRegisteredSender(uint16 sourceChain, bytes32 sourceAddress) {
        require(
            registeredSenders[sourceChain] == sourceAddress,
            "Unauthorized sender"
        );
        _;
    }

    function registerSender(
        uint16 sourceChain,
        bytes32 sourceAddress
    ) external onlyOwner {
        require(sourceAddress != bytes32(0), "Invalid sender address");
        registeredSenders[sourceChain] = sourceAddress;
        emit SenderRegistered(sourceChain, sourceAddress);
    }

    function _unlock(address user, uint256 amount) internal {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than 0");

        // Update the user's locked tokens balance
        unLockedTokens[user] += amount;

        // Transfer tokens back to the user
        require(token.transfer(user, amount), "Token transfer failed");

        emit TokensUnlocked(user, amount, block.timestamp);
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    )
        public
        payable
        override
        nonReentrant
        onlyRegisteredSender(sourceChain, sourceAddress)
    {
        require(
            msg.sender == address(wormholeRelayer),
            "Only Wormhole relayer allowed"
        );
        require(!processedMessages[deliveryHash], "Message already processed");

        // Mark message as processed
        processedMessages[deliveryHash] = true;

        // Decode the payload (sender address and amount)
        (address sender, uint256 amount) = abi.decode(
            payload,
            (address, uint256)
        );

        require(sender != address(0), "Invalid sender");
        require(amount > 0, "Invalid amount");

        emit MessageReceived(sender, amount, sourceChain);

        _unlock(sender, amount);
    }

    // send

    function quoteCrossChainCost(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            gasLimit * gasMultiplier
        );
    }

    function lockTokens(
        uint256 _amount,
        uint16 targetChain,
        address targetAddress
    ) external payable nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(targetAddress != address(0), "Target Address not set");
        require(allowedTargetChains[targetChain], "Target chain not allowed");

        uint256 cost = quoteCrossChainCost(targetChain);

        require(
            msg.value >= cost * costMultiplier,
            "Insufficient funds for cross-chain delivery"
        );

        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Allowance too low");
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );

        lockedTokens[msg.sender] += _amount;

        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(msg.sender, _amount),
            0,
            gasLimit * gasMultiplier,
            senderChainId,
            msg.sender
        );

        emit TokensLocked(msg.sender, _amount, block.timestamp);
    }

    // Update functions
    function updateGasLimit(uint256 _newGasLimit) external onlyOwner {
        gasLimit = _newGasLimit;
        emit MultiplierUpdated("gasLimit", _newGasLimit);
    }

    function updateGasMultiplier(uint256 _newMultiplier) external onlyOwner {
        gasMultiplier = _newMultiplier;
        emit MultiplierUpdated("gasMultiplier", _newMultiplier);
    }

    function updateCostMultiplier(uint256 _newMultiplier) external onlyOwner {
        costMultiplier = _newMultiplier;
        emit MultiplierUpdated("costMultiplier", _newMultiplier);
    }

    function updateSenderChainId(uint16 _chainId) external onlyOwner {
        senderChainId = _chainId;
    }

    function updateChainAllowance(
        uint16 _chain,
        bool _status
    ) external onlyOwner {
        allowedTargetChains[_chain] = _status;
        emit ChainStatusUpdated(_chain, _status);
    }

    // Existing functions remain the same
    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(
            token.balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );
        token.transfer(to, amount);
    }

    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getLockedTokens(address user) external view returns (uint256) {
        return lockedTokens[user];
    }
}
