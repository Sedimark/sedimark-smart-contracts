// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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
    // assume 1 vc for each eth address
    mapping(address => uint256) private _addr_to_vcId;

    event NewVCRequestRegistered(uint256 vc_id, address extracted, uint256 expiration, uint256 block);
    event VC_Activated(uint256 vc_id, uint256 blockTimestamp, uint256 expirationTimestamp);
    event VC_Revoked(uint256 vc_id);

    constructor() {}

    function getFreeVCid() external view onlyOwner returns(uint256) {
       return _free_vc_id;
    }

    function validate_and_store_VC (
        uint256 _vc_id,
        bytes calldata _pseudo_signature,
        string calldata _did,
        uint256 _expiration_date,
        uint256 _issuance_date,
        bytes calldata _challenge
    ) external onlyOwner {
        require(_vc_id >= 0, "VC identitifier must be greater than 0");
        require(_vc_id <= _free_vc_id, "Received VC id is invalid");
        require(_vcId_to_VC[_vc_id].vc_owner == address(0), "VC has already a VC owner: request already stored, remember to activate it");
        // If 'now' > expiration ==> expired
        require(block.timestamp < _expiration_date, "Got invalid/expired expiration date");
        require(_issuance_date <= block.timestamp, "Issuance date is in the future");

        address extractedAddress = extractSourceFromSignature(_challenge, _pseudo_signature);
        require(extractedAddress != address(0), "Invalid Extracted address");
        uint256 id = _addr_to_vcId[extractedAddress];
        if(id != 0 && !_vcId_to_VC[id].revoked) { // holder already has a vc
            // let the same holder have a second VC only if its previous VC is revoked.
            revert("Trying to issue a second VC to the same holder having the first VC still not revoked");
        }

        // Initially the VC is not enabled ==> status == false.
        _vcId_to_VC[_vc_id] = VerifiableCredential(_did, extractedAddress, _issuance_date, _expiration_date, false, false);

        // update free vc id
        _free_vc_id+=1;
        // update addr to vcid mapping, in case it substitues the old value of ID if the holder has a revoked VC and tries to have a new valid VC
        _addr_to_vcId[extractedAddress] = _vc_id;

        emit NewVCRequestRegistered(_vc_id, _vcId_to_VC[_vc_id].vc_owner, _vcId_to_VC[_vc_id].expiration_date, block.timestamp);
    }

    function activateVC(uint256 _vc_id) external { 
        require(msg.sender != address(0), "Sender is invalid");
        require(_vc_id >= 0, "VC identitifier must be greater than 0");
        VerifiableCredential storage vc = _vcId_to_VC[_vc_id];
        require(vc.status == false, "VC already activated");
        require(block.timestamp < vc.expiration_date, "Cannot activate VC: VC has expired");
        require(msg.sender == address(vc.vc_owner), "Cannot activate VC: sender is not who expcted");  // TODO: why don't user msg.sender to recover the VC? 

        // activate VC
        vc.status = true;

        emit VC_Activated(_vc_id, block.timestamp, vc.expiration_date);
    }

    function revokeVC(uint256 _vc_id) public onlyOwner {
        VerifiableCredential storage vc = _vcId_to_VC[_vc_id];
        require(vc.vc_owner != address(0), "Revoke: VC associated to the given vc_id does not exist/is invalid");
        require(_vc_revoked(_vc_id), "VC is already revoked");
        vc.status = false;
        vc.revoked = true;
        emit VC_Revoked(_vc_id);
    }

    function extractSourceFromSignature(bytes calldata _challenge, bytes calldata _pseudo_signature) internal pure returns(address) {
        bytes32 signedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n", 
            Strings.toString(_challenge.length), 
            _challenge)
        );
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_pseudo_signature);
        return ecrecover(signedHash, v, r, s);
    }

    // https://solidity-by-example.org/signature/
    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
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

    function _vc_active(uint256 _vc_id) internal view returns(bool) {
        require(_vc_id > 0, "Holder does not own a VC");
        return _vcId_to_VC[_vc_id].status;
    }
    function isVCActive(uint256 _vc_id) external view returns(bool) {
        return _vc_active(_vc_id);
    }
    function isVCActive_Addr(address vc_holder) public view returns(bool) {
        return _vc_active(_addr_to_vcId[vc_holder]);
    }

    // returns true if expired
    function _vc_expired(uint256 _vc_id) internal view returns(bool) {
        require(_vc_id > 0, "Holder does not own a VC");
        return block.timestamp > _vcId_to_VC[_vc_id].expiration_date;
    }
    function isVCExpired(uint256 _vc_id) external view returns(bool) {
        return _vc_expired(_vc_id);
    }
    function isVCExpired_Addr(address vc_holder) public view returns(bool) {
        return _vc_expired(_addr_to_vcId[vc_holder]);
    }

    function _vc_revoked(uint256 _vc_id) internal view returns(bool) {
        require(_vc_id > 0, "Holder does not own a VC");
        require(_vc_active(_vc_id), "VC is not active");
        require(!_vc_expired(_vc_id), "VC is expired");
        return _vcId_to_VC[_vc_id].revoked;
    }
    function isVCRevoked(uint256 _vc_id) external view returns(bool) {
        return _vc_revoked(_vc_id);
    }
    function isVCRevoked_Addr(address vc_holder) public view returns(bool) {
        return _vc_revoked(_addr_to_vcId[vc_holder]);
    }

    function getVCownerDID(uint256 vc_id) public view returns(string memory) {
        return _vcId_to_VC[vc_id].did;
    }
    function getVCownerDID_Addr(address vc_owner) public view returns(string memory) {
        return _vcId_to_VC[_addr_to_vcId[vc_owner]].did;
    }
}