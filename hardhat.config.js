/**
* @type import('hardhat/config').HardhatUserConfig
*/
require('dotenv').config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');

const { API_URL, PRIVATE_KEY, API_URL_ROPSTEN } = process.env;
module.exports = {
   solidity: {
      version: "0.8.7",
      settings: {
        optimizer: {
          enabled: true,
          runs: 180,
        }
      }  
   },
   defaultNetwork: "rinkeby", 
   networks: {
      hardhat: {},
      rinkeby: { 
         url: API_URL,
         accounts: [`0x${PRIVATE_KEY}`]
      },
      ropsten: {
         url: API_URL_ROPSTEN,
         accounts: [`0x${PRIVATE_KEY}`]
      }
   },
   etherscan: {
      apiKey: {
         rinkeby: "I8QH5RC5KJVPH71KSCGS535CG6HCNPUU3N",
         ropsten: "I8QH5RC5KJVPH71KSCGS535CG6HCNPUU3N"
      }   
   }
}
