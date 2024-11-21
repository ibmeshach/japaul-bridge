const { ethers, upgrades } = require("hardhat");

async function main() {
  const BSCBridgeMintableTokenV1 = await ethers.getContractFactory(
    "BSCBridgeMintableToken"
  );
  console.log("Deploying ETH BRIDGE...");
  const bsc_token_bridge = await upgrades.deployProxy(
    BSCBridgeMintableTokenV1,
    ["name", "symbol", "initialSupply", "initialOwner"],
    {
      initializer: "initialize",
    }
  );
  await bsc_token_bridge.deployed();
  console.log("bsc_token_bridge deployed to:", bsc_token_bridge.address);
}

main();
