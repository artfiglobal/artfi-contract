require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");

const keyConfig = require('./config/config.json');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
      forking: {
        enabled: true,
        url: `https://rpc.ankr.com/eth`,
        // blockNumber: 16039069
      }
    },
    mumbai: {
      url: "https://rpc.ankr.com/polygon_mumbai",
      chainId: 80001,
      accounts: [keyConfig.private_key]
    },
    polygon: {
      url: "https://polygon-rpc.com",
      chainId: 137,
      accounts: [keyConfig.private_key]
    }
  },
  etherscan: {
    // bnb network
    apiKey: keyConfig.scan_key,
  },
};
