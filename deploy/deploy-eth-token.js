const { ethers, upgrades } = require("hardhat");

async function main() {
  const TokenMintERC20TokenV1 = await ethers.getContractFactory(
    "TokenMintERC20Token"
  );
  console.log("Deploying ETH BRIDGE...");
  const eth_token_bridge = await upgrades.deployProxy(
    TokenMintERC20TokenV1,
    ["name", "symbol", "initialSupply", "initialOwner"],
    {
      initializer: "initialize",
    }
  );
  await eth_token_bridge.deployed();
  console.log("eth_token_bridge deployed to:", eth_token_bridge.address);
}

main();
