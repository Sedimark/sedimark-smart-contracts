// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IIDentity {
    function getFreeVCid() external view returns(uint256);

    function add_user(
        uint256 _vc_id,
        bytes calldata _pseudo_signature,
        string calldata _did,
        uint256 _expiration_date,
        uint256 _issuance_date,
        bytes32 _vc_hash
    ) external;

    function activateVC(uint256 _vc_id) external;

    function isVCActive(uint256 _vc_id) external view returns(bool);
    function isVCExpired(uint256 _vc_id) external view returns(bool);
    function isVCRevoked(uint256 _vc_id) external view returns(bool);

    function isVCActive_Addr(address vc_holder) external view returns(bool);
    function isVCExpired_Addr(address vc_holder) external view returns(bool);
    function isVCRevoked_Addr(address vc_holder) external view returns(bool);

}