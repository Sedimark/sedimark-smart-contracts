// SPDX-FileCopyrightText: 2024 Fondazione LINKS
//
// SPDX-License-Identifier: GPL-3.0-or-later

const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {

    let obtainedAddresses = {}
    const name = "addresses"
    obtainedAddresses[name] = {};

    addresses = obtainedAddresses[name];

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const DeployerSC = await ethers.getContractFactory("Deployer");
    let deployerInstance = await DeployerSC.deploy();
    addresses.Deployer = deployerInstance.address;
    console.log("Deployer address:", deployerInstance.address);
    
    const ServiceBase = await ethers.getContractFactory("ServiceBase");
    const serviceBaseInstance = await ServiceBase.deploy();
    addresses.ServiceBase = serviceBaseInstance.address;
    console.log("ServiceBase SC address:", serviceBaseInstance.address);

    const AccessTokenBase = await ethers.getContractFactory("AccessTokenBase");
    const accessTokenBaseInstance = await AccessTokenBase.deploy();
    addresses.AccessTokenBase = accessTokenBaseInstance.address;
    console.log("AccessTokenBase SC address:", accessTokenBaseInstance.address);

    const RouterFactory = await ethers.getContractFactory("RouterFactory");
    const routerFactoryInstance = await RouterFactory.deploy(deployer.address);
    addresses.RouterFactory = routerFactoryInstance.address;
    console.log("RouterFactory SC address:", routerFactoryInstance.address);

    const Identity = await ethers.getContractFactory("Identity");
    const identityInstance = await Identity.deploy();
    // const identityAddress = await identityInstance.address
    addresses.Identity = identityInstance.address;
    console.log("Identity SC address:", identityInstance.address);

    const FixedRateExchange = await ethers.getContractFactory("FixedRateExchange");
    const fixedRateExchangeInstance = await FixedRateExchange.deploy(
      routerFactoryInstance.address,
      identityInstance.address
    );
    addresses.FixedRateExchange = fixedRateExchangeInstance.address;
    console.log("FixedRateExchange SC address:", fixedRateExchangeInstance.address);

    const Factory = await ethers.getContractFactory("Factory");
    const factoryInstance = await Factory.deploy(
      serviceBaseInstance.address, 
      accessTokenBaseInstance.address, 
      routerFactoryInstance.address, 
      fixedRateExchangeInstance.address, 
      identityInstance.address
    );
    addresses.Factory = factoryInstance.address;
    console.log("Factory SC address:", factoryInstance.address);

    // add factory and exchange address to router
    const box = RouterFactory.attach(routerFactoryInstance.address);
    await box.addFactoryAddress(factoryInstance.address);
    await box.addFixedRateAddress(fixedRateExchangeInstance.address);


    obtainedAddresses[name] = addresses;

    const json = JSON.stringify(obtainedAddresses, null, 2);
    await fs.promises.writeFile(__dirname.replace('scripts','addresses/contractAddresses.json'), json)
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