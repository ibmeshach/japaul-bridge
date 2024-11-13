import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

require("dotenv").config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.26", // or the version you are using
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // Choose a value that works for your contract
      },
      viaIR: true, // Enable intermediate representation optimization
    },
  },
  sourcify: {
    enabled: true,
  },

  networks: {
    bnbtest: {
      url: `${process.env.JSON_RPC_BNBTEST}`,
      accounts: [`${process.env.PRI_KEY}`],
    },
    mumbai: {
      url: `${process.env.JSON_RPC_MUMBAI}`,
      accounts: [`${process.env.PRI_KEY}`],
    },
    sepolia: {
      url: `${process.env.JSON_RPC_SEPOLIA}`,
      accounts: [`${process.env.PRI_KEY}`],
    },
  },
  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY,
  },
};

export default config;
