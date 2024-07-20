// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./ExternalLib.sol"; /// @dev import external libraries for error and event handling

/// @dev implements ErrorLib & EventLib

contract itETH is OFT, AccessControl {
    /// @title Insane Technology Restaked Ether Basket (itETH)
    /// @author Insane Technology
    /// @custom:description ether wrapper which deposits into LRT protocols and uses a pass-through formula for distributing points to depositors

    /// @dev struct that holds the request payloads
    struct RequestPayload {
        address owner; /// @dev owner of the request
        uint256 amount; /// @dev the amount of itETH requested for withdrawal
        bool fulfilled; /// @dev whether the request has been filled already or not
    }
    mapping(uint256 => RequestPayload) public payloads; /// @dev mapping for tracking requests
    mapping(address => uint256) public cooked; /// @dev mapping for tracking the user's point qualifications for minting itETH
    mapping(address => address) public referrals; /// @dev mapping to track the referral status of users
    mapping(address => uint256) public earnedReferralPoints; /// @dev mapping that tracks the ref pts earned per user
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public treasury = 0xBFc57B070b1EDA0FCb9c203EDc1085c626F3A36d; /// @notice multichain multisig address
    IERC20 public immutable WETH; /// @notice WETH address on the chain
    bool public paused; /// @notice whether mint/redeem functionality are paused

    uint256 public constant REF_BASE = 1e3; /// @notice refbase is hardcoded to 1000 (100%)
    uint256 public minReq = 0.001 ether; /// @notice the minimum amount of weth needed to request a redemption
    uint256 public refDivisor = 1e2; /// @notice 10% by default (100/1000)
    uint256 public lastProcessedID; /// @notice last processed ID regardless of height
    uint256 public highestProcessedID; /// @notice the last request (by highest index) that was processed
    uint256 public totalReferralPoints; /// @notice total referred UPI points given
    uint256 public totalPoints; /// @notice total UPI points overall

    uint256 internal _requestCounter; /// @dev internal counter to see what the next request ID would be

    address public odos;

    modifier WhileNotPaused() {
        if (paused) revert ErrorLib.Paused();
        _;
    }

    /// @dev layerzero endpoint address and weth address on the chain
    constructor(
        address _endpoint,
        address _weth,
        address _odos
    )
        OFT(
            "Insane Technology Restaked Ether Basket",
            "itETH",
            _endpoint,
            treasury
        )
        Ownable(treasury)
    {
        _requestCounter = 0; /// @dev iterative, start at 0
        paused = false; /// @dev unpaused by default
        WETH = IERC20(_weth); /// @dev initialize the WETH variable
        odos = _odos; /// @dev set odos router address
        totalReferralPoints = 0; ///@dev start at 0
        /// @dev grant the appropriate roles to the treasury
        _grantRole(DEFAULT_ADMIN_ROLE, treasury);
        _grantRole(OPERATOR_ROLE, treasury);
        _grantRole(MINTER_ROLE, treasury);
    }

    /// @notice "cook" itETH with your WETH
    /// @custom:description transfer the wrapped ether from your wallet and recieve minted itETH
    /// @custom:accesscontrol this function is not limited to anyone, only the paused boolean
    function cook(uint256 _amount, address _referral) public WhileNotPaused {
        if (!(_amount > 0)) revert ErrorLib.Zero();
        WETH.transferFrom(msg.sender, address(this), _amount);
        WETH.transfer(treasury, _amount);
        _mint(msg.sender, _amount);
        /// @dev if there is no bound referral
        if (cooked[msg.sender] == 0 && referrals[msg.sender] == address(0))
            referrals[msg.sender] = _referral;
        cooked[msg.sender] += _amount;
        totalPoints += _amount;
        /// @dev if it is above the min threshold
        if (_amount > minReq) {
            uint256 refPts = ((_amount * refDivisor) / REF_BASE); /// @dev refDivisor * amount of referral deposits are accounted to the referee
            earnedReferralPoints[referrals[msg.sender]] += refPts;
            totalPoints += refPts;
            totalReferralPoints += refPts;
            emit EventLib.ReferralDeposit(
                msg.sender,
                referrals[msg.sender],
                refPts
            );
        }
    }

    /// @notice request redemption from the treasury
    /// @dev non-atomic redemption queue system
    /// @custom:accesscontrol this function is not limited to anyone, only the paused boolean
    function requestRedemption(uint256 _amount) public WhileNotPaused {
        if (_amount < minReq) revert ErrorLib.BelowMinimum();
        _burn(msg.sender, _amount);
        ++_requestCounter;
        payloads[_requestCounter] = RequestPayload(msg.sender, _amount, false);
        if (cooked[msg.sender] < _amount) revert ErrorLib.Failed(); /// @dev if the user has 0 points, do not allow redemption request
        cooked[msg.sender] -= _amount; /// @dev remove from cooked mapping once redemption requested
        totalPoints -= _amount; /// @dev remove total points upon redemption
        emit EventLib.RequestRedemption(msg.sender, _amount);
    }

    /// @notice process a batch of redeem requests
    /// @custom:accesscontrol execution is limited to the OPERATOR_ROLE
    function processRedemptions(uint256[] calldata _redemptionIDs)
        public
        onlyRole(OPERATOR_ROLE)
    {
        for (uint256 i = 0; i < _redemptionIDs.length; ++i) {
            _process(_redemptionIDs[i]);
        }
    }

    /// @custom:accesscontrol execution is limited to the MINTER_ROLE
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @dev standard ERC-20 burn
    /// @custom:accesscontrol this function is not limited to anyone
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /// @custom:accesscontrol execution is limited to the DEFAULT_ADMIN_ROLE
    function setTreasury(address _treasury)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        treasury = _treasury;
    }

    /// @notice function to pause the printing of itETH
    /// @custom:accesscontrol execution is limited to the OPERATOR_ROLE
    function setPaused(bool _status) public onlyRole(OPERATOR_ROLE) {
        if (paused == _status) revert ErrorLib.NoChangeInBoolean();
        paused = _status;
    }

    /// @notice set the minimum eth amount for redemptions
    /// @custom:accesscontrol execution is limited to the OPERATOR_ROLE
    function setMinReq(uint256 _min) public onlyRole(OPERATOR_ROLE) {
        minReq = _min;
    }

    /// @notice set the referral divisor
    /// @custom:accesscontrol execution is limited to the OPERATOR_ROLE
    function setRefDivisor(uint256 _divisor) public onlyRole(OPERATOR_ROLE) {
        if (refDivisor < 1e1) revert ErrorLib.BelowMinimum();
        refDivisor = _divisor;
    }

    /// @notice convert weth and other tokens to desired LRT
    /// @custom:accesscontrol execution is limited to the OPERATOR_ROLE
    function performBasketSwap(
        address[] calldata _tokensOut,
        uint256[] calldata _minAmountsOut,
        bytes calldata _odosCalldata
    ) public onlyRole(OPERATOR_ROLE) {
        /// @dev define and map balances before the swap
        uint256[] memory balanceBefore = new uint256[](_tokensOut.length);
        for (uint256 i = 0; i < _tokensOut.length; ++i) {
            balanceBefore[i] = IERC20(_tokensOut[i]).balanceOf(treasury);
        }

        /// @dev ensure the swap succeeds
        (bool success, ) = odos.call(_odosCalldata);
        if (!success) revert ErrorLib.Failed();

        /// @dev check for improper output amounts
        for (uint256 i = 0; i < _tokensOut.length; ++i) {
            if (
                ((IERC20(_tokensOut[i]).balanceOf(treasury)) -
                    balanceBefore[i]) < _minAmountsOut[i]
            ) revert ErrorLib.Failed();
        }
    }

    /// @notice arbitrary call
    /// @custom:accesscontrol execution is limited to the DEFAULT_ADMIN_ROLE
    function execute(address _x, bytes calldata _data)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        (bool success, ) = _x.call(_data);
        if (!success) revert ErrorLib.Failed();
    }

    /// @notice function for processing batched sybils
    /// @custom:accesscontrol execution is limited to the DEFAULT_ADMIN_ROLE
    function processSybils(address[] calldata _sybils)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < _sybils.length; ++i) {
            _sybil(_sybils[i]);
        }
    }

    /// @notice function for accrual a batch of points for users
    /// @custom:accesscontrol execution is limited to the DEFAULT_ADMIN_ROLE
    function processAccruals(
        address[] calldata _users,
        uint256[] calldata _amounts
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _users.length; ++i)
            _accrue(_users[i], _amounts[i]);
    }

    /// @dev internal function for accruing points
    function _accrue(address _user, uint256 _amount) internal {
        cooked[_user] += _amount;
        emit EventLib.AccruePoints(_user, _amount);
    }

    /// @dev internal function for burning sybil points
    function _sybil(address _sybilWallet) internal {
        if (
            !(cooked[_sybilWallet] > 0) &&
            !(earnedReferralPoints[_sybilWallet] > 0)
        ) revert ErrorLib.Failed(); /// @dev if they have no points, revert as a failure
        uint256 sybilCooked = cooked[_sybilWallet];
        totalPoints -= sybilCooked; /// @dev remove points from total
        cooked[_sybilWallet] = 0; /// @dev set points to zero
        uint256 sybilRefPoints = earnedReferralPoints[_sybilWallet];
        totalReferralPoints -= sybilRefPoints; /// @dev remove ref points from the totalRefPoints accrued
        earnedReferralPoints[_sybilWallet] = 0; /// @dev set ref points to zero

        emit EventLib.SybilPurged(_sybilWallet, sybilCooked); /// @dev emit event for purging sybils
    }

    /// @notice standard decimal return
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /// @notice function for returning the total points and total referral points
    function totalPointsBreakdown()
        public
        view
        returns (uint256 totalPointsRegular, uint256 totalPointsReferred)
    {
        return (totalPoints, totalReferralPoints);
    }

    /// @dev internal function to process each request
    function _process(uint256 _reqID) internal {
        RequestPayload storage pl = payloads[_reqID];
        (uint256 amt, address sendTo, bool filled) = (
            pl.amount,
            pl.owner,
            pl.fulfilled
        );
        if (filled) revert ErrorLib.Fulfilled(); /// @dev if fulfilled, revert
        if (!(amt > 0)) revert ErrorLib.Zero(); /// @dev if the amount is not greater than 0, revert
        WETH.transferFrom(treasury, address(this), amt);
        WETH.transfer(sendTo, amt);
        /// @dev set the payload values to 0/true;
        pl.amount = 0;
        pl.fulfilled = true;

        lastProcessedID = _reqID; /// @dev stores the last processed ID regardless of height

        highestProcessedID < _reqID /// @dev ternary operator for updating the highest processed request ID
            ? highestProcessedID = _reqID
            : highestProcessedID = highestProcessedID;

        emit EventLib.ProcessRedemption(_reqID, amt); /// @dev emit event for processing the request
    }
}
