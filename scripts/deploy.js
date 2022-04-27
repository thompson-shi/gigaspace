require('dotenv').config();

const adminSigner = process.env.ADMIN_SIGNER;
const uri = "https://gateway.pinata.cloud/ipfs/";
//const { deployProxy } = require('@openzeppelin/truffle-upgrades');
//const { ethers, upgrades } = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
   // Grab the contract factory 

   const Gigaspace = await ethers.getContractFactory("Gigaspace");

   // Start deployment, returning a promise that resolves to a contract object
   //const gigaSpace = await Gigaspace.deploy(adminSigner, uri); // Instance of the contract 
   const gigaSpace = await Gigaspace.deploy(); // Instance of the contract 
   //const gigaLandBase = await GigaLandBase.deploy("0x10858130d017b46cd720709E85Cb9577a66Be146", uri); // Instance of the contract 
   await gigaspace.deployed();
   console.log("gigaspace deployed to:", gigaspace.address);

   //const proxy = await upgrades.deployProxy(GigaLandBase, [adminSigner, uri], { initializer: 'initialize' });
   //await proxy.deployed();

   //console.log("Contract deployed to address:", proxy.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
