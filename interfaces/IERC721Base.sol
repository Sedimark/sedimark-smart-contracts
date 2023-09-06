// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Base {
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
        string memory asset_download_URL,
        string memory asset_hash,
        string memory offering_hash,
        string memory trust_sign
    ) external returns(bool);

    function getNFTowner() external view returns (address owner);
}