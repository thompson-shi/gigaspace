require('dotenv').config();

const adminSigner = process.env.ADMIN_SIGNER;
const uri = "https://gateway.pinata.cloud/ipfs/";
const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const { ethers, upgrades } = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
   
   const GigaSpaceLand = await ethers.getContractFactory("GigaSpaceLand");
   console.log("Deploying GigaSpaceLand...")
   const proxy = await upgrades.deployProxy(GigaSpaceLand, [adminSigner, uri], { initializer: 'initialize' });
   await proxy.deployed();

   console.log("Contract deployed to address:", proxy.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
