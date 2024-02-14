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
  
    const Deployer = await ethers.getContractFactory("Deployer");
    let token = await Deployer.deploy();
    addresses.Deployer = token.address;
    console.log("Deployer address:", token.address);
    
    const ERC721Base = await ethers.getContractFactory("ERC721Base");
    const baseAddress = await ERC721Base.deploy();
    addresses.ERC721Base = baseAddress.address;
    console.log("ERC721Base address:", baseAddress.address);

    const ERC20Base = await ethers.getContractFactory("ERC20Base");
    const base20Address = await ERC20Base.deploy();
    addresses.ERC20Base=base20Address.address;
    console.log("ERC20Base address:", base20Address.address);

    const RouterFactory = await ethers.getContractFactory("RouterFactory");
    const router = await RouterFactory.deploy(deployer.address);
    addresses.RouterFactory = router.address;
    console.log("RouterFactory address:", router.address);

    const FixedRateExchange = await ethers.getContractFactory("FixedRateExchange");
    const a = await FixedRateExchange.deploy(router.address);
    addresses.FixedRateExchange = a.address;
    console.log("FixedRateExchange address:", a.address);

    const IDentityFactory = await ethers.getContractFactory("IDentity");
    const IDtoken = await IDentityFactory.deploy();
    const IDentityAddress = await IDtoken.address
    addresses.IDentityAddress = IDentityAddress;
    console.log("IDentitySC address:", IDentityAddress);

    const ERC721Factory = await ethers.getContractFactory("ERC721Factory");
    token = await ERC721Factory.deploy(baseAddress.address, base20Address.address, router.address, a.address, IDentityAddress);
    addresses.ERC721Factory = token.address;
    console.log("ERC721Factory address:", token.address);

    // add factory and exchange address to router
    const box = RouterFactory.attach(router.address);
    await box.addFactoryAddress(token.address);
    await box.addFixedRateAddress(a.address);


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