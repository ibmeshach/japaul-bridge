const { ethers, upgrades } = require("hardhat");

async function main() {
  const BSCBridgeMintableTokenV1 = await ethers.getContractFactory(
    "BSCBridgeMintableToken"
  );
  console.log("Deploying BSC TOKEN...");
  const bsc_token_bridge = await upgrades.deployProxy(
    BSCBridgeMintableTokenV1,
    ["Wrapped JPGC", "WJPGC", "0x963194A12420bC8cfc4F2CdBd5E550FaE137fd48"],
    {
      initializer: "initialize",
    }
  );
  await bsc_token_bridge.deployed();
  console.log("bsc_token_bridge deployed to:", bsc_token_bridge.address);
}

main();
