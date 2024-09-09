// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWETH} from "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @dev import external libraries for error and event handling
/// @dev implements ErrorLib & EventLib
import {ErrorLib, EventLib} from "./ExternalLib.sol";
import {Bribable} from "./Bribable.sol";

contract itETH is OFT, AccessControl, ReentrancyGuard, Bribable {
    /// @title Insane Technology Ether (itETH)
    /// @author Insane Technology
    /// @custom:description ether wrapper which deposits into various strategies and passes yield through

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

    uint256 public redeemShareEth = 995;
    /// @notice total deposits ever
    uint256 public totalDepositedEther;

    modifier WhileNotPaused() {
        require(!paused, ErrorLib.Paused());
        _;
    }

    /// @dev layerzero endpoint address and weth address on the chain
    constructor(
        address _endpoint,
        address _weth
    ) OFT("Insane Ether", "itETH", _endpoint, OPERATIONS) Ownable(OPERATIONS) {
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

    /// @notice mint itETH with your WETH
    function mint(uint256 _amount) public WhileNotPaused {
        require(_amount > 0, ErrorLib.Zero());

        ercWETH.transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
        totalDepositedEther += _amount;
        /// @dev emit the amount of eth deposited and by whom
        emit EventLib.Minted(msg.sender, _amount);
    }

    /// @notice mint itETH with ETH
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
        wtg.depositETH(address(aavePool), address(this), 0);
        /// @dev mint the reciept token
        _mint(msg.sender, amt);

        /// @dev emit the amount of eth deposited and by whom
        emit EventLib.Minted(msg.sender, amt);
    }

    /// @notice request redemption from the treasury
    function redeemTokens(
        uint256 _amount
    ) external WhileNotPaused nonReentrant {
        require(_amount > 0, ErrorLib.BelowMinimum());
        _burn(msg.sender, _amount);
        aavePool.withdraw(address(WETH), _amount, msg.sender);
        emit EventLib.Redemption(msg.sender, _amount);
    }

    /// @notice function to pause the minting of itETH
    function setPaused(bool _status) external onlyRole(OPERATOR_ROLE) {
        require(paused != _status, ErrorLib.NoChangeInBoolean());
        paused = _status;
        emit EventLib.PausedContract(_status);
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
