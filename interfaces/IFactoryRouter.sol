// SPDX-FileCopyrightText: 2024 Fondazione LINKS
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.18;

interface IFactoryRouter {
    function createFixedRate(
        address fixedRateAddress_, 
        address owner_, 
        uint256 fixedRate_, 
        uint256 dataTokenDecimals_,
        uint256 giveMintPerm_to_Exch_
    ) external returns (bytes32 exchangeID); 
}