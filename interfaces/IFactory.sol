// SPDX-FileCopyrightText: 2024 Fondazione LINKS
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.18;

interface IFactory {

    function deployERC20Contract(
        string memory name_,
        string memory symbol_,
        address owner_, // minter = DT owner = NFT owner
        address erc721address_, // should be the calling NFT contract = msg.sender. Not true if "all in one"
        uint256 maxSupply_,
        bool is_form_all_inOne
    ) external returns (address erc20Instance);

    function createdERC20List(address erc20dt) external view returns(address);
    function eRC20_to_owner(address erc20dt) external view returns(address);
    
}