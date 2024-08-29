// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/// @dev import external libraries for error and event handling
/// @dev implements ErrorLib & EventLib
import "./ExternalLib.sol";

contract itETH is OFT, AccessControl {
    /// @title Insane Technology Ether (itETH)
    /// @author Insane Technology
    /// @custom:description ether wrapper which deposits into various strategies and passes yield through

    /// @dev struct that holds the request payloads
    struct RequestPayload {
        /// @dev owner of the request
        address owner;
        /// @dev the amount of itETH requested for withdrawal
        uint256 amount;
        /// @dev whether the request has been filled already or not
        bool fulfilled;
    }
    /// @dev mapping for tracking requests
    mapping(uint256 => RequestPayload) public payloads;

    /// @notice Operator access control role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    /// @notice Minter access control role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice multichain multisig address
    address public constant OPERATIONS =
        0xBFc57B070b1EDA0FCb9c203EDc1085c626F3A36d;
    /// @notice WETH address on the chain
    IERC20 public immutable WETH;
    /// @notice whether mint/redeem functionality are paused
    bool public paused;

    /// @notice the minimum amount of weth needed to request a redemption
    uint256 public minReq = 0.001 ether;

    uint256 public redeemShareEth = 990;
    /// @notice last processed ID regardless of height
    uint256 public lastProcessedID;
    /// @notice the last request (by highest index) that was processed
    uint256 public highestProcessedID;
    /// @notice total deposits ever
    uint256 public totalDepositedEther;
    /// @dev internal counter to see what the next request ID would be
    uint256 internal _requestCounter;

    /// @dev reentrancy lock
    uint256 internal _lock = 1;

    modifier locked() {
        ++_lock;
        uint256 _localLock = _lock;
        _;
        /// @dev check for reentrancy at the end
        require(_localLock == _lock, "Reentrancy lock failed");
    }

    modifier WhileNotPaused() {
        require(!paused, ErrorLib.Paused());
        _;
    }

    /// @dev layerzero endpoint address and weth address on the chain
    constructor(
        address _endpoint,
        address _weth
    )
        OFT("Insane Technology Ether", "itETH", _endpoint, OPERATIONS)
        Ownable(OPERATIONS)
    {
        /// @dev iterative, start at 0
        _requestCounter = 0;
        /// @dev paused by default
        paused = true;
        /// @dev initialize the WETH variable
        WETH = IERC20(_weth);
        /// @dev grant the appropriate roles to the treasury
        _grantRole(DEFAULT_ADMIN_ROLE, OPERATIONS);
        _grantRole(OPERATOR_ROLE, OPERATIONS);
        _grantRole(MINTER_ROLE, OPERATIONS);
        /// @dev grant roles to deployer for initial testing
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /// @notice mint itETH with your WETH
    function mint(uint256 _amount) public WhileNotPaused {
        require(_amount > 0, ErrorLib.Zero());

        WETH.transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
        totalDepositedEther += _amount;
        /// @dev emit the amount of eth deposited and by whom
        emit EventLib.EtherDeposited(msg.sender, _amount);
    }

    /// @notice mint itETH with ETH
    function nativeMint() public payable WhileNotPaused locked {
        uint256 amt = msg.value;
        require(amt > 0, ErrorLib.Zero());
        uint256 _balBefore = WETH.balanceOf(address(this));
        WETH.deposit(amt);
        require(
            amt + _balBefore == WETH.balanceOf(address(this), ErrorLib.Failed())
        );
        totalDepositedEther += amt;
        WETH.transfer(OPERATIONS, WETH.balanceOf(address(this)));
        _mint(msg.sender, amt);

        /// @dev emit the amount of eth deposited and by whom
        emit EventLib.EtherDeposited(msg.sender, amt);
    }

    /// @notice request redemption from the treasury
    function requestRedemption(uint256 _amount) external WhileNotPaused {
        require(_amount >= minReq, ErrorLib.BelowMinimum());
        _burn(msg.sender, _amount);
        ++_requestCounter;
        payloads[_requestCounter] = RequestPayload(msg.sender, _amount, false);
        emit EventLib.RequestRedemption(msg.sender, _amount);
    }

    /// @notice process a batch of redeem requests
    function processRedemptions(
        uint256[] calldata _redemptionIDs
    ) external onlyRole(OPERATOR_ROLE) {
        uint256 _highestProcessedID = highestProcessedID;
        for (uint256 i = 0; i < _redemptionIDs.length; ++i) {
            _process(_redemptionIDs[i]);
            if (_highestProcessedID < _redemptionIDs[i]) {
                highestProcessedID = _redemptionIDs[i];
            }
        }
        /// @dev stores the last processed ID regardless of height
        lastProcessedID = _redemptionIDs[_redemptionIDs.length - 1];
    }

    /// @notice function to pause the printing of itETH
    function setPaused(bool _status) external onlyRole(OPERATOR_ROLE) {
        require(paused != _status, ErrorLib.NoChangeInBoolean());
        paused = _status;
        emit EventLib.PausedContract(_status);
    }

    /// @notice set the minimum eth amount for redemptions
    function setMinReq(uint256 _min) external onlyRole(OPERATOR_ROLE) {
        minReq = _min;
        emit EventLib.MinReqSet(minReq);
    }

    /// @notice arbitrary call
    function execute(
        address _x,
        bytes calldata _data
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success, ) = _x.call(_data);
        require(success, ErrorLib.Failed());
    }

    /// @notice standard decimal return
    /// @return uint8 decimals
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /// @dev internal function to process each request
    function _process(uint256 _reqID) internal {
        RequestPayload storage pl = payloads[_reqID];
        (uint256 amt, address sendTo, bool filled) = (
            pl.amount,
            pl.owner,
            pl.fulfilled
        );
        /// @dev if fulfilled, revert
        require(!filled, ErrorLib.Fulfilled());
        /// @dev if the amount is not greater than 0, revert
        require(amt > 0, ErrorLib.Zero());
        WETH.transferFrom(OPERATIONS, sendTo, amt);
        /// @dev set the payload values to 0/true;
        pl.amount = 0;
        pl.fulfilled = true;
        /// @dev emit event for processing the request
        emit EventLib.ProcessRedemption(_reqID, amt);
    }

    /// @dev to receive eth
    receive() external payable {}
}
