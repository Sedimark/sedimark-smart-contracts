// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IERC721Factory.sol";
import "../interfaces/IFixedRateExchange.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RouterFactory {
    using SafeMath for uint256;

    address private _routerOwner;
    address private _factory;
    address[] private _fixedRateAddresses;

    event FixedRateContractAdded(
        address indexed caller,
        address indexed contractAddress
    );
    event FixedRateContractRemoved(
        address indexed caller,
        address indexed contractAddress
    );

    modifier onlyRouterOwner() {
        require(_routerOwner == msg.sender, "ROUTER: NOT THE OWNER");
        _;
    }

    constructor(address routerOwner_) {
        require(routerOwner_ != address(0), "Router owner cannot be the 0 address");
        _routerOwner = routerOwner_;
    }

    // to be called during deployement
    // only router owner
    function addFactoryAddress(address factory_) external onlyRouterOwner {
        require(factory_ != address(0), "ERC721Factory address cannot be the 0 address");
        require(_factory == address(0), "ERC721Factory address already set");

        _factory = factory_;
    }

    // checks if the provided address is already present in the list of
    // addresses added before using the addFixedrateAddress() function
    function isNewFixedRateAddress(address fixedRate_) public view returns(bool) {
        for(uint256 i = 0; i < _fixedRateAddresses.length; i++) {
            if(_fixedRateAddresses[i] == fixedRate_) return false;
        }
        return true;
    }

    // Add the address to the list of valid FixedRate contracts
    // only router owner 
    function addFixedRateAddress(address fixedRate_) external onlyRouterOwner {
        require(
            fixedRate_ != address(0), 
            "ROUTER: trying to add an invalid FixedRate address"
        );
        // check that the provided address has not been already added
        if(isNewFixedRateAddress(fixedRate_)) {
            _fixedRateAddresses.push(fixedRate_);
            emit FixedRateContractAdded(msg.sender, fixedRate_);
        }
    }

    function removeFixedRateContract(address fixedRateAddress_) external onlyRouterOwner {
        require(fixedRateAddress_ != address(0), "ROUTER: INVALID ADDRESS IN REMOVE FIXED RATE");
        uint256 i;
        for(i = 0; i < _fixedRateAddresses.length; i++) {
            if(_fixedRateAddresses[i] == fixedRateAddress_) break;
        }
        if(i < _fixedRateAddresses.length) {
            // the address to remove is in the array
            // swap with the last
            _fixedRateAddresses[i] = _fixedRateAddresses[_fixedRateAddresses.length - 1];
            _fixedRateAddresses.pop(); 
            emit FixedRateContractRemoved(msg.sender, fixedRateAddress_);
        }
    }

    function getFixedrateContracts() public view returns (address[] memory) {
        return _fixedRateAddresses;
    }

    // msg.sender should be the DataToken contract address
    // so msg.sender will be passed as param in exchange setup
    function createFixedRate(
        address fixedRateAddress_, 
        address owner_, 
        uint256 fixedRate_, 
        uint256 dataTokenDecimals_,
        uint256 giveMintPerm_to_Exch_
    ) external returns (bytes32 exchangeID) {
        // Verify that the caller (DT contract) has been created by the erc721factory contract
        require(
            IERC721Factory(_factory).createdERC20List(msg.sender) == msg.sender,
            "ROUTER: ERC20 Address is not a valid token"
        );
        // check that the fixedRateAddress is valid (must be an existing fixedrate address, so not new)
        require(
            !isNewFixedRateAddress(fixedRateAddress_),
            "ROUTER: FIXED PRICE CONTRACT ADDRESS IS NOT VALID"
        );
        // check that received owner param is actually also the DT owner = NFT owner = Dataset owner
        require(IERC721Factory(_factory).eRC20_to_owner(msg.sender) == owner_);

        // use the fixedRate exchange contract to create/setup a new exchange
        exchangeID = IFixedRateExchange(fixedRateAddress_).setupSMRExchange_for_datatoken(
            msg.sender,
            owner_,
            fixedRate_,
            dataTokenDecimals_,
            giveMintPerm_to_Exch_
        );
    }

}