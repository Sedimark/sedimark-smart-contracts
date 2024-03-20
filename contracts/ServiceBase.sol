// SPDX-FileCopyrightText: 2024 Fondazione LINKS
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../interfaces/IServiceBase.sol";
import "../interfaces/IAccessTokenBase.sol";
import "../interfaces/IFactory.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// ERC-721
contract ServiceBase is
    Initializable, 
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable {
    
    using SafeMathUpgradeable for uint256;

    address private _factory;
    address[] private deployedAccessTokens;
    string private _serviceUrl;

    event NFTminted(
        address owner,
        string name, 
        string symbol,
        address factory
    );  

    event TokenCreated(
        string name,
        string symbol,
        address owner,
        address erc721address_, 
        address newERC20Address,
        uint256 maxSupply_,
        uint256 initialSupply_
    );

    modifier onlyServiceOwner() {
        require(msg.sender == ownerOf(1), "Not the NFT owner!");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == _factory, "Not the Factory address!");
        _;
    }

    // ONLY FACTORY
    function initialize(
        address owner,
        address factory,
        string memory name_, 
        string memory symbol_,
        string memory _tokenURI,
        string memory serviceUrl
    ) external initializer returns(bool) {
        require(owner != address(0), "Invalid NFT owner: zero address not valid!");

        __ERC721_init(name_, symbol_);
        __ERC721URIStorage_init();
        _factory = factory;

        require(msg.sender == _factory, "Not the Factory address!");

        _safeMint(owner, 1);
        _setTokenURI(1, _tokenURI);
        _serviceUrl = serviceUrl;

        emit NFTminted(owner, name_, symbol_, _factory);
        return true;
    }

    // function called only directly by the NFT owner and not by any contract.
    function createServiceToken(
        string calldata name,
        string calldata symbol,
        // address owner, // should be already msg.sender.
        // address erc721address_, // it is the NFT contract that is calling the factory function. So it will be msg.sender on the other side
        uint256 maxSupply_
    ) external onlyServiceOwner returns (address accessToken) {
        require(maxSupply_ > 0, "Cap and initial supply not valid");
        // already checked by the onlyServiceOwner modifier
        // require(msg.sender != address(0), "ERC721Base: Minter cannot be address(0)");

        accessToken = IFactory(_factory).deployERC20Contract(
            name,
            symbol,
            msg.sender, // == new DT owner = NFTowner
            address(this),
            maxSupply_,
            false
        );
        deployedAccessTokens.push(accessToken);
        emit TokenCreated(name, symbol, msg.sender, address(this), accessToken, 0, maxSupply_);
    }

    function getServiceOwner() external view returns (address owner) {
        return ownerOf(1);
    }

    function getATaddresses() external view returns (address[] memory) {
        return deployedAccessTokens;
    }

    function addNewAccessToken(address accessToken) external onlyFactory {
        deployedAccessTokens.push(accessToken);
    }

    function getAssetDownloadURL() external view returns(string memory) {
        return _serviceUrl;
    }

    // The following functions are overrides required by Solidity.
    function burn(uint256 tokenId) external onlyServiceOwner {
        _burn(tokenId);
    }


    function _burn(uint256 tokenId) internal override(ERC721URIStorageUpgradeable, ERC721Upgradeable) onlyServiceOwner {
        super._burn(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721URIStorageUpgradeable, ERC721Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function balanceOf(address caller) public view override(ERC721Upgradeable, IERC721Upgradeable) returns(uint256) {
        return super.balanceOf(caller);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721URIStorageUpgradeable, ERC721Upgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function verifyProofOfPurchase(
        bytes calldata _eth_signature,
        bytes calldata _challenge // bytes32 _hash
    ) external view returns(bool) {
        address extractedAddress = extractSourceFromSignature(_challenge, _eth_signature);
        require(extractedAddress != address(0), "ERC721: extracted signature is 0x00");

        IAccessTokenBase accessTokenInstance = IAccessTokenBase(deployedAccessTokens[0]);
        // >= 1 ether cause the price is fixed to 1 for now. This needs to be changed if prices will be added.
        return (accessTokenInstance.balanceOf(extractedAddress) >= 1 ether);
    }

    // TODO: define this in a library Smart Contract (almost common to IDentity.sol)
    // function extractSourceFromSignature(bytes32 _hash, bytes calldata _pseudo_signature) internal pure returns(address) {
    //     bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash));
    //     (bytes32 r, bytes32 s, uint8 v) = splitSignature(_pseudo_signature);
    //     return ecrecover(signedHash, v, r, s);
    // }
    function extractSourceFromSignature(bytes calldata _challenge, bytes calldata _pseudo_signature) internal pure returns(address) {
        bytes32 signedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n", 
            Strings.toString(_challenge.length), 
            _challenge)
        );
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_pseudo_signature);
        return ecrecover(signedHash, v, r, s);
    }

    // TODO: define this in a library Smart Contract (almost common to IDentity.sol)
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

    /**
     * @dev fallback function
     *      this is a default fallback function in which receives
     *      the collected ether.
     */
    fallback() external payable {}

    /**
     * @dev receive function
     *      this is a default receive function in which receives
     *      the collected ether.
     */
    receive() external payable {}
}