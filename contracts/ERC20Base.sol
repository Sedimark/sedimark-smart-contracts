// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "../interfaces/IERC721Base.sol";
import "../interfaces/IFactoryRouter.sol";
import "../interfaces/IERC20Base.sol";

contract ERC20Base is
    Initializable,
    ERC20Upgradeable,
    IERC20Base {

    using SafeMathUpgradeable for uint256;

    address private _erc721address;
    address private _owner;
    address private _router;
    uint256 private _maxSupply;
    
    mapping(address => bool) private _allowedMinters;
    mapping(address => uint256) public nonces_;

    struct FixedRate {
        address fixedRateExchange;
        bytes32 exchangeID;
    }
    FixedRate[] private fixedRateExchanges;

    event InitializedDT(string name, string symbol, address owner, address erc721address, address router);
    event Permit(address recoveredAddress, address owner, address spender, uint256 amount);
    event PermitData(bytes32 domain_separator, bytes32 permit_gasg, bytes32 digest);
    event FixedRateCreated(bytes32 exchangeID, address owner, address fixedRateAddress);

    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address owner_, // minter = DT owner = NFT owner
        address erc721address_,
        address router_,
        uint256 maxSupply_
    ) external initializer returns (bool){
        require(owner_ != address(0), "Minter cannot be 0x00!");
        require(owner_ == IERC721Base(erc721address_).getNFTowner(), "NOT THE NFT OWNER");
        require(
            erc721address_ != address(0),
            "ERC721Factory address cannot be 0x00!" 
        );
        require(router_ != address(0), "ERC20: ROUTER CANNOT BE THE 0 ADDRESS");
        require(maxSupply_ > 0, "The maximum supply must be > 0");

        __ERC20_init(name_, symbol_);
        _erc721address = erc721address_;
        _owner = owner_;
        _router = router_;
        _maxSupply = maxSupply_;
        /**
         * ERC20 tokens have 18 decimals => Number of tokens minted = n * 10^18
         * This way the decimals are transparent to the clients.
         */
        nonces_[_owner] = 0;
        emit InitializedDT(name_, symbol_, owner_, _erc721address, _router);
        return true;
    }

    function _addMinter(address newminter) internal {
        _allowedMinters[newminter] = true;
    }

    function isAllowedMinter(address isminter) internal view returns (bool) {
        return _allowedMinters[isminter];
    }

    function isMinter(address isminter) external view returns(bool) {
        return isAllowedMinter(isminter);
    }
    
    function mint(address to, uint256 amount) external {
        require(msg.sender == _owner || isAllowedMinter(msg.sender), "NOT ALLOWED TO MINT DTs");
        require(totalSupply().add(amount) <= _maxSupply, "Cannot exceed the cap");
        _mint(to, amount);
    }

    function createFixedRate(
        address fixedRateAddress_,
        uint256 fixedrate_,
        uint256 giveMintPerm_toExchange
    ) external onlyOwner returns (bytes32 exchangeID) {
        if(giveMintPerm_toExchange > 0) _addMinter(fixedRateAddress_);
        exchangeID = IFactoryRouter(_router).createFixedRate(
            fixedRateAddress_,
            _owner,
            fixedrate_,
            decimals(),
            giveMintPerm_toExchange
        );
        emit FixedRateCreated(exchangeID, _owner, fixedRateAddress_);
        fixedRateExchanges.push(FixedRate(fixedRateAddress_, exchangeID));
    }

    function getDTowner() external view returns (address) {
        return _owner;
    } 

    function getMaxSupply() external view returns(uint256) {
        return _maxSupply;
    }

    function balanceOf(address caller) public view override(ERC20Upgradeable, IERC20Base) returns(uint256) {
        return super.balanceOf(caller);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(ERC20Upgradeable, IERC20Base) returns (bool){
        return super.transferFrom(from, to, amount);
    }

    /**
    * Allow the (NFT owner/DT owner) of the contract to withdraw SMR
    */
    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "No balance to withdraw");
        (bool sent,) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to withdraw");
    }

    function burn(uint256 amount) external {
        require(msg.sender == _owner, "NOT ALLOWED TO BURN");
        _burn(msg.sender, amount);
    }

    /*
        Support for EIP-2612 
        https://eips.ethereum.org/EIPS/eip-2612
        https://soliditydeveloper.com/erc20-permit
    */

    function DOMAIN_SEPARATOR() internal view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        (bytes32 domain) = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name())),
                keccak256(bytes("1")), // version, could be any other value
                chainId,
                address(this)
            )
        );
        return domain;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.number, "ERC20DT EXPIRED");
        require(owner == IERC721Base(_erc721address).getNFTowner(), "Owner not the NFT owner");
        require(value > 0, "Cannot permit 0 value");
        uint256 nonceBefore = nonces_[owner];
        bytes32 domain_separator = DOMAIN_SEPARATOR();
        bytes32 permit_hash = keccak256(abi.encode(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    owner,
                    spender,
                    value,
                    nonceBefore,
                    deadline
                ));
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domain_separator,
                permit_hash
            )
        );
        nonces_[owner] += 1;
        require(nonces_[owner] == nonceBefore + 1, "ERC20Base: permit did not succeed. Nonce mismatch!");

        address recoveredAddress = ecrecover(digest, v, r, s); 
        require(
            recoveredAddress == owner, 
            "ERC20 datatoken: INVALID SIGNATURE IN ERC20-PERMIT"
        );
        emit Permit(recoveredAddress, owner, spender, value);
        emit PermitData(domain_separator, permit_hash, digest);
        _approve(owner, spender, value);
    }

    function nonces(address requester) external view returns(uint256) {
        return nonces_[requester];
    }

    // function approve()

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