const { ethers, upgrades } = require("hardhat");

async function main() {
  const BSCBridgeV1 = await ethers.getContractFactory("BSCBridgeContract");
  console.log("Deploying BSC BRIDGE...");
  const bsc_bridge = await upgrades.deployProxy(
    BSCBridgeV1,
    ["_wormholeRelayer", "_token"],
    {
      initializer: "initialize",
    }
  );
  await bsc_bridge.deployed();
  console.log("bsc_bridge deployed to:", bsc_bridge.address);
}

main();
