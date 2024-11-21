// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IWormholeRelayer.sol";
import "./interfaces/IWormholeReceiver.sol";

interface IBridgeMintableToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function decimals() external view returns (uint8);
}

contract BSCBridgeContract is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IWormholeReceiver
{
    IWormholeRelayer public wormholeRelayer;
    IBridgeMintableToken public token;

    uint256 public gasLimit;
    uint16 public senderChainId;
    uint256 public gasMultiplier;
    uint256 public costMultiplier;

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
    event SenderRegistered(uint16 sourceChain, bytes32 sourceAddress);
    event Minted(address indexed user, uint256 amount, uint256 timestamp);
    event Burned(address indexed user, uint256 amount, uint256 timestamp);
    event UnlockRequestSent(
        address indexed user,
        uint256 amount,
        uint16 targetChain
    );

    // UUPS initializer
    function initialize(
        address _wormholeRelayer,
        address _token
    ) public initializer {
        require(_token != address(0), "Token address cannot be zero");
        require(_wormholeRelayer != address(0), "Invalid relayer address");

        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        token = IBridgeMintableToken(_token);
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);

        gasLimit = 200000;
        senderChainId = 10002;
        gasMultiplier = 3;
        costMultiplier = 2;
    }

    // UUPS authorization function
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

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

        token.mint(to, amount);
        mintedTokens[to] += amount;
        emit Minted(to, amount, block.timestamp);
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

        processedMessages[deliveryHash] = true;

        (address sender, uint256 amount) = abi.decode(
            payload,
            (address, uint256)
        );
        require(sender != address(0), "Invalid sender");
        require(amount > 0, "Invalid amount");

        emit MessageReceived(sender, amount, sourceChain);
        mint(sender, amount);
    }

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

        token.burn(msg.sender, amount);
        burntTokens[msg.sender] += amount;

        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(msg.sender, amount),
            0,
            gasLimit * gasMultiplier,
            senderChainId,
            msg.sender
        );

        emit Burned(msg.sender, amount, block.timestamp);
        emit UnlockRequestSent(msg.sender, amount, targetChain);
    }

    function updateGasLimit(uint256 _newGasLimit) external onlyOwner {
        gasLimit = _newGasLimit;
    }

    function updateGasMultiplier(uint256 _newMultiplier) external onlyOwner {
        gasMultiplier = _newMultiplier;
    }

    function updateSenderChainId(uint16 _chainId) external onlyOwner {
        senderChainId = _chainId;
    }

    function updateCostMultiplier(uint256 _newMultiplier) external onlyOwner {
        costMultiplier = _newMultiplier;
    }

    function updateChainAllowance(
        uint16 _chain,
        bool _status
    ) external onlyOwner {
        allowedTargetChains[_chain] = _status;
    }
}
