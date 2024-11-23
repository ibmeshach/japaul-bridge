const { ethers, upgrades } = require("hardhat");

async function main() {
  const TokenMintERC20TokenV1 = await ethers.getContractFactory(
    "TokenMintERC20Token"
  );
  console.log("Deploying ETH TOKEN...");
  const eth_token_bridge = await upgrades.deployProxy(
    TokenMintERC20TokenV1,
    [
      "JPGC Token",
      "JPGC",
      "1000000000000000000000000",
      "0x963194A12420bC8cfc4F2CdBd5E550FaE137fd48",
    ],
    {
      initializer: "initialize",
    }
  );
  await eth_token_bridge.deployed();
  console.log("eth_token_bridge deployed to:", eth_token_bridge.address);
}

main();
