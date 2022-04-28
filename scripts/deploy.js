require('dotenv').config();

const adminSigner = process.env.ADMIN_SIGNER;
const uri = "https://gateway.pinata.cloud/ipfs/";
//const { deployProxy } = require('@openzeppelin/truffle-upgrades');
//const { ethers, upgrades } = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
   // Grab the contract factory 

   const GigaSpaceLand = await ethers.getContractFactory("GigaSpaceLand");

   // Start deployment, returning a promise that resolves to a contract object
   //const gigaSpaceLand = await GigaSpaceLand.deploy(adminSigner, uri); // Instance of the contract 
   const gigaSpaceLand = await GigaSpaceLand.deploy(); // Instance of the contract 
   await gigaSpaceLand.deployed();
   console.log("GigaSpaceLand deployed to:", gigaspace.address);

   /*
   const proxy = await upgrades.deployProxy(GigaLandBase, [adminSigner, uri], { initializer: 'initialize' });
   await proxy.deployed();
   console.log("Contract deployed to address:", proxy.address);
   */
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
