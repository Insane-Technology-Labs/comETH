// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWETH} from "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ErrorLib, EventLib} from "./ExternalLib.sol";
import {Bribable} from "./Bribable.sol";

contract comETH is OFT, AccessControl, ReentrancyGuard, Bribable {
    /// @title Astro Ether (comETH)
    /// @author Astro
    /// @custom:description ether wrapper which passes down yield

    /// @notice Operator access control role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    /// @notice Minter access control role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice WETH address on the chain
    IWETH public immutable WETH;
    /// @notice erc20 form of weth
    IERC20 public ercWETH;
    /// @notice whether mint/redeem functionality are paused
    bool public paused;
    /// @notice ratio of ETH redeemed per 1 comETH (1000 = 100%)
    uint256 public redeemShareEth = 995;

    modifier WhileNotPaused() {
        require(!paused, ErrorLib.Paused());
        _;
    }

    /// @dev layerzero endpoint address and weth address on the chain
    constructor(
        address _endpoint,
        address _weth
    ) OFT("Astro Ether", "comETH", _endpoint, OPERATIONS) Ownable(OPERATIONS) {
        /// @dev paused by default
        paused = true;
        /// @dev initialize the WETH variables
        (WETH, ercWETH) = (IWETH(_weth), IERC20(_weth));
        /// @dev grant the appropriate roles to the treasury
        _grantRole(DEFAULT_ADMIN_ROLE, OPERATIONS);
        _grantRole(OPERATOR_ROLE, OPERATIONS);
        /// @dev grant role to deployer for initial testing
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /// @notice mint comETH with your WETH
    /// @param _amount the amount of WETH to deposit
    function mint(uint256 _amount) public WhileNotPaused nonReentrant {
        require(_amount > 0, ErrorLib.Zero());

        ercWETH.transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);

        /// @dev emit the amount of eth deposited and by whom
        emit EventLib.Minted(msg.sender, _amount);
    }

    /// @notice mint comETH with ETH
    /// @dev accepts msg.value
    function nativeMint() public payable WhileNotPaused nonReentrant {
        uint256 amt = msg.value;
        require(amt > 0, ErrorLib.Zero());
        uint256 _balBefore = ercWETH.balanceOf(address(this));
        WETH.deposit{value: amt};
        require(
            (amt + _balBefore) == ercWETH.balanceOf(address(this)),
            ErrorLib.Failed()
        );
        /// @dev take the ETH and deposit to the aave pool
        wtg.depositETH(address(aavePool), address(this), 0 /* Zero ref code */);
        /// @dev mint the reciept token
        _mint(msg.sender, amt);

        /// @dev emit the amount of eth deposited and by whom
        emit EventLib.Minted(msg.sender, amt);
    }

    /// @notice redeem the underlying tokens
    /// @param _amount the amount of tokens to redeem
    function redeemTokens(
        uint256 _amount
    ) external WhileNotPaused nonReentrant {
        require(_amount > 0, ErrorLib.BelowMinimum());
        _burn(msg.sender, _amount);
        uint256 received = ((_amount * redeemShareEth) / 1000);
        /// @dev send underlying to user
        aavePool.withdraw(address(WETH), received, msg.sender);
        /// @dev send fee to operations
        aavePool.withdraw(address(WETH), (_amount - received), OPERATIONS);
        emit EventLib.Redemption(msg.sender, _amount);
    }

    /// @notice function to pause the minting of comETH
    /// @param _status t/f
    function setPaused(bool _status) external onlyRole(OPERATOR_ROLE) {
        require(paused != _status, ErrorLib.NoChangeInBoolean());
        paused = _status;
        emit EventLib.PausedContract(_status);
    }

    /// @notice adjust the redeem values, between 0% and 1%
    /// @param _newValue the new redemption value
    function setRedeemValues(
        uint256 _newValue
    ) external onlyRole(OPERATOR_ROLE) {
        /// @dev fee cannot be greater than 1% or less than 0%
        require(_newValue >= 990 && _newValue <= 1000, ErrorLib.DivisorError());
        redeemShareEth = _newValue;
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

    /// @dev to receive eth
    receive() external payable {}
}
