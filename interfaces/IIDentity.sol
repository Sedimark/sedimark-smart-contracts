// SPDX-FileCopyrightText: 2024 Fondazione LINKS
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.18;

interface IIdentity {
    function getFreeVCid() external view returns(uint256);

    function add_user(
        uint256 _vc_id,
        bytes calldata _pseudo_signature,
        string calldata _did,
        uint256 _expiration_date,
        uint256 _issuance_date,
        bytes32 _vc_hash
    ) external;

    function isVCExpired(uint256 _vc_id) external view returns(bool);
    function isVCRevoked(uint256 _vc_id) external view returns(bool);

    function isVCExpired_Addr(address vc_holder) external view returns(bool);
    function isVCRevoked_Addr(address vc_holder) external view returns(bool);

}