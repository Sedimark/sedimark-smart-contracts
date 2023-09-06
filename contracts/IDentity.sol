// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract IDentity is Ownable {
    
    struct VerifiableCredential {
        string did;
        address vc_owner;
        uint256 issuance_date;
        uint256 expiration_date;
        bool revoked;
        bool status;
    }

    uint256 private _free_vc_id = 1;
    // vc_id => VerifiableCredential mapping
    mapping(uint256 => VerifiableCredential) private _vcId_to_VC;

    event NewVCRequestRegistered(uint256 vc_id, address extracted, uint256 expiration, uint256 block);
    event VC_Activated(uint256 vc_id, uint256 blockTimestamp, uint256 expirationTimestamp);

    constructor() {}

    function getFreeVCid() external view onlyOwner returns(uint256) {
       return _free_vc_id;
    }

    function validate_and_store_VC(
        uint256 _vc_id,
        bytes calldata _pseudo_signature,
        string calldata _did,
        uint256 _expiration_date,
        uint256 _issuance_date,
        bytes32 _vc_hash
    ) external onlyOwner {
        require(_vc_id >= 0, "VC identitifier must be greater than 0");
        require(_vc_id <= _free_vc_id, "Received VC id is invalid");
        require(_vcId_to_VC[_vc_id].vc_owner == address(0), "VC has already a VC owner: request already stored, remember to activate it");
        // If 'now' > expiration ==> expired
        require(block.timestamp < _expiration_date, "Got invalid/expired expiration date");
        require(_issuance_date <= block.timestamp, "Issuance date is in the future");

        address extractedAddress = extractSourceFromSignature(_vc_hash, _pseudo_signature);
        require(extractedAddress != address(0), "Invalid Extracted address");

        // Initially the VC is not enabled ==> status == false.
        _vcId_to_VC[_vc_id] = VerifiableCredential(_did, extractedAddress, _issuance_date, _expiration_date, false, false);

        // update free vc id
        _free_vc_id+=1;

        emit NewVCRequestRegistered(_vc_id, _vcId_to_VC[_vc_id].vc_owner, _vcId_to_VC[_vc_id].expiration_date, block.timestamp);
    }

    function activateVC(uint256 _vc_id) external {
        require(msg.sender != address(0), "Sender is invalid");
        require(_vc_id >= 0, "VC identitifier must be greater than 0");
        require(_vcId_to_VC[_vc_id].status == false, "VC already activated");
        require(block.timestamp < _vcId_to_VC[_vc_id].expiration_date, "Cannot activate VC: VC has expired");
        require(msg.sender == address(_vcId_to_VC[_vc_id].vc_owner), "Cannot activate VC: sender is not who expcted");

        // activate VC
        _vcId_to_VC[_vc_id].status = true;

        emit VC_Activated(_vc_id, block.timestamp, _vcId_to_VC[_vc_id].expiration_date);
    }

    function extractSourceFromSignature(bytes32 _vc_hash, bytes calldata _pseudo_signature) internal pure returns(address) {
        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _vc_hash));
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_pseudo_signature);
        return ecrecover(signedHash, v, r, s);
    }

    // https://solidity-by-example.org/signature/
    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature
            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature
            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function isVCActive(uint256 _vc_id) external view returns(bool) {
        return _vcId_to_VC[_vc_id].status;
    }

    // returns true if expired
    function isVCExpired(uint256 _vc_id) external view returns(bool) {
        return block.timestamp > _vcId_to_VC[_vc_id].expiration_date;
    }
}