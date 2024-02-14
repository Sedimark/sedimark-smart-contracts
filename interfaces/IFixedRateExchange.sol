// SPDX-FileCopyrightText: 2024 Fondazione LINKS
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.18;

interface IFixedRateExchange {
    
function setupSMRExchange_for_datatoken(
        address datatokenAddress_,
        address owner_, 
        uint256 fixedRate_,
        uint256 dataTokenDecimals_,
        uint256 giveMintPerm_to_Exch_
    ) external returns (bytes32 exchangeID);

    function isExchangeActive(bytes32 exchangeID) external view returns(bool);
}