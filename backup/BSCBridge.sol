// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// import "https://raw.githubusercontent.com/wormhole-foundation/wormhole-solidity-sdk/main/src/interfaces/IWormholeRelayer.sol";
// import "https://raw.githubusercontent.com/wormhole-foundation/wormhole-solidity-sdk/main/src/interfaces/IWormholeReceiver.sol";

import "./interfaces/IWormholeRelayer.sol";
import "./interfaces/IWormholeReceiver.sol";

interface IBridgeMintableToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function decimals() external view returns (uint8);
}

contract BSCBridgeContract is
    IWormholeReceiver,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    IWormholeRelayer public wormholeRelayer;
    IBridgeMintableToken public token;

    uint256 public gasLimit = 200000;
    uint16 public senderChainId = 10002;
    uint256 public gasMultiplier = 3;
    uint256 public costMultiplier = 2;

    mapping(uint16 => bytes32) public registeredSenders;
    mapping(address => uint256) public mintedTokens;
    mapping(bytes32 => bool) public processedMessages;
    mapping(address => uint256) public burntTokens;
    mapping(uint16 => bool) public allowedTargetChains;

    event MessageReceived(
        address indexed sender,
        uint256 amount,
        uint16 sourceChain
    );
    event SourceChainLogged(uint16 sourceChain);
    event SenderRegistered(uint16 sourceChain, bytes32 sourceAddress);
    event Minted(address indexed user, uint256 amount, uint256 timestamp);
    event MintError(address indexed user, uint256 amount, string reason);

    event MultiplierUpdated(string multiplierType, uint256 newValue);
    event ChainStatusUpdated(uint16 chain, bool status);
    event Burned(address indexed user, uint256 amount, uint256 timestamp);
    event UnlockRequestSent(
        address indexed user,
        uint256 amount,
        uint16 targetChain
    );
    event BurnError(address indexed user, uint256 amount, string reason);

    constructor(address _wormholeRelayer, address _token) {
        require(_token != address(0), "Token address cannot be zero");
        require(_wormholeRelayer != address(0), "Invalid relayer address");

        token = IBridgeMintableToken(_token);
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

    function mint(address to, uint256 amount) internal {
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");

        try IBridgeMintableToken(address(token)).mint(to, amount) {
            mintedTokens[to] += amount;
            emit Minted(to, amount, block.timestamp);
        } catch Error(string memory reason) {
            emit MintError(to, amount, reason);
            revert(reason);
        } catch {
            emit MintError(to, amount, "Mint failed");
            revert("Mint failed");
        }
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

        mint(sender, amount);
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

    function burnTokens(
        uint256 amount,
        uint16 targetChain,
        address targetAddress
    ) external payable nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(targetAddress != address(0), "Invalid target address");
        require(allowedTargetChains[targetChain], "Target chain not allowed");

        uint256 cost = quoteCrossChainCost(targetChain);

        require(
            msg.value >= cost * costMultiplier,
            "Insufficient funds for cross-chain delivery"
        );

        // Attempt to burn tokens and track the operation
        try token.burn(msg.sender, amount) {
            // Update the burntTokens mapping
            burntTokens[msg.sender] += amount;

            emit Burned(msg.sender, amount, block.timestamp);

            wormholeRelayer.sendPayloadToEvm{value: cost}(
                targetChain,
                targetAddress,
                abi.encode(msg.sender, amount),
                0,
                gasLimit * gasMultiplier,
                senderChainId,
                msg.sender
            );

            emit UnlockRequestSent(msg.sender, amount, targetChain);
        } catch Error(string memory reason) {
            // Handle any errors thrown by the token's burn function
            emit BurnError(msg.sender, amount, reason);
            revert(reason);
        } catch {
            // Handle unexpected errors
            emit BurnError(msg.sender, amount, "Burn failed");
            revert("Burn failed");
        }
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

    function updateSenderChainId(uint16 _chainId) external onlyOwner {
        senderChainId = _chainId;
    }

    function updateCostMultiplier(uint256 _newMultiplier) external onlyOwner {
        costMultiplier = _newMultiplier;
        emit MultiplierUpdated("costMultiplier", _newMultiplier);
    }

    function updateChainAllowance(
        uint16 _chain,
        bool _status
    ) external onlyOwner {
        allowedTargetChains[_chain] = _status;
        emit ChainStatusUpdated(_chain, _status);
    }

    // View function to check if a message has been processed
    function isMessageProcessed(
        bytes32 deliveryHash
    ) external view returns (bool) {
        return processedMessages[deliveryHash];
    }
}
