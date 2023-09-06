const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());
  
    const IDentityFactory = await ethers.getContractFactory("IDentity");
    const token = await IDentityFactory.deploy();
    const IDentityAddress = await token.address
    console.log("IDentitySC address:", IDentityAddress);
    
    const json = JSON.stringify({IDentity: IDentityAddress});
    await fs.promises.writeFile(__dirname.replace('scripts','addresses/IDentity_address.json'), json)
    .catch((err) => {
      console.log("Error in writing addresses file!", err);
    });
    console.log("Addresses file correctly generated. Have a look in the ../addresses folder");
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });