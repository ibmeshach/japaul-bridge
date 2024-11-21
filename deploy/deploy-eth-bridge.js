const { ethers, upgrades } = require("hardhat");

async function main() {
  const EthBridgeV1 = await ethers.getContractFactory("ETHBridgeContract");
  console.log("Deploying ETH BRIDGE...");
  const eth_bridge = await upgrades.deployProxy(
    EthBridgeV1,
    [
      "_token",
      "_wormholeRelayer",
      "_gasLimit",
      "_senderChainId",
      "_gasMultiplier",
      "_costMultiplier",
    ],
    {
      initializer: "initialize",
    }
  );
  await eth_bridge.deployed();
  console.log("eth_bridge deployed to:", eth_bridge.address);
}

main();
