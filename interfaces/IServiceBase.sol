// SPDX-FileCopyrightText: 2024 Fondazione LINKS
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.18;

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IServiceBase {
    event NFTminted(
        address owner,
        string name, 
        string symbol,
        address factory
    ); 

    function initialize(
        address owner,
        address factory,
        string memory name_, 
        string memory symbol_,
        string memory _tokenURI,
        string memory serviceUrl
    ) external returns(bool);

    function createServiceToken(
        string calldata name,
        string calldata symbol,
        // address owner, // should be already msg.sender.
        // address erc721address_, // it is the NFT contract that is calling the factory function. So it will be msg.sender on the other side
        uint256 maxSupply_
    ) external returns (address erc20token);

    function getServiceOwner() external view returns (address owner);
    function addNewAccessToken(address accessToken) external;
    function balanceOf(address caller) external view returns(uint256);
}