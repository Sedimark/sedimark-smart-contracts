// SPDX-FileCopyrightText: 2024 Fondazione LINKS
//
// SPDX-License-Identifier: GPL-3.0-or-later

require("dotenv").config();
const ethers = require("ethers");
const fs =require("fs") ;


const addresses = JSON.parse(fs.readFileSync(process.env.ADDRESS_FILE)).addresses;

console.log(`Deployer address: ${addresses.Deployer}`)
console.log(`ERC721Base address: ${addresses.ERC721Base}`)
console.log(`ERC721Factory address: ${addresses.ERC721Factory}`)
console.log(`ERC20Base address: ${addresses.ERC20Base}`)
console.log(`FixedRateExchange address: ${addresses.FixedRateExchange}`)
console.log(`IDentityAddress address: ${addresses.IDentityAddress}`)


