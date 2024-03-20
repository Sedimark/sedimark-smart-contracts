// SPDX-FileCopyrightText: 2024 Fondazione LINKS
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.18;

interface IIdentity {
    function getFreeVCid() external view returns(uint256);

    function addUser(
        uint256 _vc_id,
        bytes calldata _pseudo_signature,
        string calldata _did,
        uint256 _expiration_date,
        uint256 _issuance_date,
        bytes32 _vc_hash
    ) external;

    function isRevoked(uint256 _credentialId) external view returns(bool);
    function isRevokedByAddr(address credentialHolder) external view returns(bool);
    function hasValidStatus(address credentialHolder) external view returns(bool);
}