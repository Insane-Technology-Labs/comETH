// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWrappedTokenGatewayV3} from "./IWrappedTokenGatewayV3.sol";
import {IRewarder} from "./IRewarder.sol";

contract Bribable {
    /// @notice multichain multisig address
    address public constant OPERATIONS =
        0xBFc57B070b1EDA0FCb9c203EDc1085c626F3A36d;
    address public underlying;
    IRewarder public incentivesRecipient;
    IWrappedTokenGatewayV3 public wtg;
    IERC20 public aToken;
    uint256 public constant DENOM = 10_000;
    uint256 public shareU = 5000;
    uint256 public shareT = 5000;

    uint8 internal initialized = 1;

    bool public feeSwitch;

    modifier onlyOperator() {
        require(msg.sender == OPERATIONS, "unauthorized");
        _;
    }

    function init(
        address _underlying,
        address _aToken,
        address _incentivesRecipient,
        address _gateway
    ) external onlyOperator {
        require(initialized == 1, "initialized");
        aToken = IERC20(_aToken);
        wtg = IWrappedTokenGatewayV3(_gateway);
        incentivesRecipient = IRewarder(_incentivesRecipient);
        underlying = _underlying;
        ++initialized;
        feeSwitch = false;
    }

    function toggle() external onlyOperator {
        feeSwitch = !feeSwitch;
    }

    function changeRecipient(address _ir) external onlyOperator {
        incentivesRecipient = IRewarder(_ir);
    }

    function changeShares(
        uint256 _shareU,
        uint256 _shareT
    ) external onlyOperator {
        require((_shareU + _shareU) == DENOM, "!denom");
        (shareU, shareT) = (_shareU, _shareT);
    }

    function _hypothecate() internal {
        /// @dev poke logic
        uint256 before = aToken.balanceOf(address(this));
        aToken.transfer(OPERATIONS, 1 wei);
        uint256 dif = aToken.balanceOf(address(this)) - before;
        if (feeSwitch) {
            uint256 difU = ((dif * shareU) / DENOM);
            uint256 difT = dif - difU;
            aToken.transfer(OPERATIONS, difT);
            IERC20(underlying).approve(address(incentivesRecipient), difU);
            incentivesRecipient.notifyRewardAmountNext(underlying, difU);
        } else {
            aToken.transfer(OPERATIONS, dif);
        }
    }
}
