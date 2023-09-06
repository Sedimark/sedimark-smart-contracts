// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @dev Required interface of an ERC20 compliant contract.
 */
interface IERC20Base {

    function initialize(
        string memory name_,
        string memory symbol_,
        address owner_, // minter = DT owner = NFT owner
        address erc721address_,
        address router_,
        uint256 maxSupply_
    ) external returns (bool);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function isMinter(address isminter) external view returns(bool);
    function mint(address to, uint256 amount) external;
    function balanceOf(address caller) external view returns(uint256);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}