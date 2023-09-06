// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/IERC20Base.sol";

contract FixedRateExchange {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    address private _router;

    uint256 private constant BASE = 1e18;
    uint256 public constant MIN_RATE = 1e10;

    struct Exchange {
        bool active;
        bool mintPermission;
        address exchangeOwner;
        address datatoken;
        uint256 fixedRate;
        uint256 dtDecimals;
        uint256 dtBalance; 
    }

    bytes32[] private exchangeIds;
    mapping(bytes32 => Exchange) private exchanges;

    event ExchangeCreated(
        bytes32 exchangeId,
        address datatoken,
        address exchangeowner,
        uint256 fixedRate
    );
    event SuccessfulSwap(
        bytes32 exchangeID, 
        address buyer, 
        address exchangeOwner, 
        uint256 dtamountBougth, 
        uint256 smrReceived
    );

    modifier onlyRouter() {
        require(msg.sender == _router, "CALLER NOT THE VALID ROUTER");
        _;
    }

    modifier activeExchange(bytes32 exchangeId) {
        require(exchanges[exchangeId].active, "EXCHANGE IS NOT ACTIVE");
        _;
    }

    modifier onlyExchangeOwner(bytes32 exchangeId) {
        require(msg.sender == exchanges[exchangeId].exchangeOwner, "CALLER NOT THE EXCHANGE OWNER");
        _;
    }

    constructor(address router_) {
        _router = router_;
    }

    // exchange is unique per each datatoken-owner pair
    function generateExchangeID(address datatoken, address owner) internal pure returns(bytes32) {
        return keccak256(abi.encode(datatoken, owner));
    }

    function setupSMRExchange_for_datatoken(
        address datatokenAddress_,
        address owner_, 
        uint256 fixedRate_,
        uint256 dataTokenDecimals_,
        uint256 giveMintPerm_to_Exch_
    ) external onlyRouter returns (bytes32 exchangeID) {
        require(datatokenAddress_ != address(0), "FIXEDRATE: INVALID DATATOKEN ADDRESS");
        // owner address checked in Router impl
        require(fixedRate_ >= MIN_RATE, "FIXEDRATE: RATE IS TOO LOW");
        
        exchangeID = generateExchangeID(datatokenAddress_, owner_);
        bool mintPerm = true;
        if(giveMintPerm_to_Exch_ == 0) mintPerm = false;

        exchanges[exchangeID] = Exchange({
            active: true,
            mintPermission: mintPerm,
            exchangeOwner: owner_,
            datatoken: datatokenAddress_,
            fixedRate: fixedRate_,
            dtDecimals: dataTokenDecimals_,
            dtBalance: 0
        });
        exchangeIds.push(exchangeID);

        emit ExchangeCreated(exchangeID, datatokenAddress_, owner_, fixedRate_);
    }

    function calcDT_to_SMR(bytes32 exchangeID, uint256 dtamount) internal view returns(uint256 priceTopay) {
        priceTopay = (dtamount
            .mul(exchanges[exchangeID].fixedRate)
            .div(BASE));
    }

    function getSMRcostFor1DT(bytes32 exchangeId) external view activeExchange(exchangeId) returns(uint256) {
        return calcDT_to_SMR(exchangeId, 1 * 10 ** exchanges[exchangeId].dtDecimals);
    }

    function getExchangeFixedRate(bytes32 exchangeId) external view activeExchange(exchangeId) returns(uint256) {
        return exchanges[exchangeId].fixedRate;
    }

    /**
     * sell DT amount only if expected SMR are received
     * 
     * @param exchangeId exchangeID for given DT 
     * @param dtamount amount of DTs that are requested to be sold 
     */
    function sellDT(bytes32 exchangeId, uint256 dtamount) payable external activeExchange(exchangeId) {
        require(dtamount > 0, "FIXEDRATE: PROVIDED A 0 DT AMOUNT");

        uint256 swapPrice = calcDT_to_SMR(exchangeId, dtamount);
        require(swapPrice > 0, "FIXEDRATE: CALUCLATED SWAP PRICE IS 0!");
        require(msg.value >= swapPrice, "FIXEDRATE: SENT FUNDS ARE NOT ENOUGH");

        if(dtamount > exchanges[exchangeId].dtBalance) { // exchange does not have tokens
            // try to mint if no DT available
            if(exchanges[exchangeId].mintPermission && IERC20Base(exchanges[exchangeId].datatoken).isMinter(address(this))) {
                // move DTs to buyer account
                IERC20Base(exchanges[exchangeId].datatoken).mint(msg.sender, dtamount);
            } else { 
                // have to retrieve dts from the exchangeOwner
                moveDTfromOwnerAccount(
                    exchanges[exchangeId].datatoken,
                    exchanges[exchangeId].exchangeOwner,
                    msg.sender,
                    dtamount
                );
            }
        } else { // exchange already has liquidity, so DTs are available
            exchanges[exchangeId].dtBalance = (exchanges[exchangeId].dtBalance).sub(dtamount);
            IERC20(exchanges[exchangeId].datatoken).safeTransfer(msg.sender, dtamount); 
        }

        // move SMR to the seller account (the DT owner=exchangeOwner)
        // maybe have to send SMR to the exchange contract otherwise in case of
        // "buyDT" the contract should move SMR from the owner account (is this possible)?
        payable(exchanges[exchangeId].exchangeOwner).transfer(msg.value);

        emit SuccessfulSwap(
            exchangeId,
            msg.sender,
            exchanges[exchangeId].exchangeOwner,
            dtamount,
            msg.value
        );
    }
    
    /**
     * Get DT back in exchange of SMR
     * 
     * @param exchangeId exchangeID for given DT
     */
    function buyDT(bytes32 exchangeId) external activeExchange(exchangeId) {
        
    }

    // does it require an aporoval ??? I think owner should approve the exchange to move dts
    function moveDTfromOwnerAccount(
        address dtAddress,
        address from,
        address to,
        uint256 dtamount
    ) internal {
        uint256 balanceBefore = IERC20Base(dtAddress).balanceOf(to);
        IERC20Base(dtAddress).transferFrom(from, to, dtamount);
        require(
            IERC20Base(dtAddress).balanceOf(to) >= balanceBefore.add(dtamount),
            "Transfer amount is too low"
        );
    }

    // remeber to parse amount to ether in frontend
    function safeDeposit(
        address dtaddress_,
        uint8 v, bytes32 r, bytes32 s,
        bytes32 exchangeId, 
        uint256 amount
    ) external activeExchange(exchangeId) returns(bool){
        IERC20Base(dtaddress_).permit(
            msg.sender,
            address(this),
            amount,
            type(uint256).max,
            v, r, s
        );
        (bool sent) = IERC20Base(dtaddress_).transferFrom(msg.sender, address(this), amount);
        if(sent) exchanges[exchangeId].dtBalance = (exchanges[exchangeId].dtBalance).add(amount);
        return sent; 
    } 

    function disactivateExchange(bytes32 exchangeId) external onlyExchangeOwner(exchangeId) {
        exchanges[exchangeId].active = false;
    }

    function reactivateExchange(bytes32 exchangeId) external onlyExchangeOwner(exchangeId) {
        exchanges[exchangeId].active = true;
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