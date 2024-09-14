// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWrappedTokenGatewayV3} from "./IWrappedTokenGatewayV3.sol";
import {IAToken} from "./IAToken.sol";
import {IRewarder} from "./IRewarder.sol";
import {IPool} from "./IPool.sol";

contract Bribable {
    /// @notice multichain multisig address
    address public constant OPERATIONS =
        0xBFc57B070b1EDA0FCb9c203EDc1085c626F3A36d;
    IERC20 public underlying;
    IRewarder public incentivesRecipient;
    IWrappedTokenGatewayV3 public wtg;
    IAToken public aToken;
    IPool public aavePool;
    uint256 public constant DENOM = 10_000;
    uint256 public shareYield = 5000;
    uint256 public shareOpex = 5000;

    bool public autoBriber;

    uint8 internal initialized = 1;

    modifier onlyOperator() {
        require(msg.sender == OPERATIONS, "unauthorized");
        _;
    }

    function init(
        address _aToken,
        address _incentivesRecipient,
        address _gateway,
        address _aavePool
    ) external onlyOperator {
        require(initialized == 1, "initialized");
        aToken = IAToken(_aToken);
        wtg = IWrappedTokenGatewayV3(_gateway);
        aavePool = IPool(_aavePool);
        autoBriber = false;
        incentivesRecipient = IRewarder(_incentivesRecipient);
        underlying = IERC20(aToken.UNDERLYING_ASSET_ADDRESS());
        ++initialized;
    }

    /// @notice change the gauge where LP incentives are submitted
    function changeRecipient(address _ir) external onlyOperator {
        incentivesRecipient = IRewarder(_ir);
    }

    /// @notice function to change the share %s
    /// @param _yieldFee share of incentives to users
    /// @param _opexFee share of incentives to operations/token holders
    function changeShares(
        uint256 _yieldFee,
        uint256 _opexFee
    ) external onlyOperator {
        require((_yieldFee + _opexFee) == DENOM, "!denom");
        (shareYield, shareOpex) = (_yieldFee, _opexFee);
    }

    /// @notice changes the auto rewarder status
    function toggleAutoBribe() external onlyOperator {
        autoBriber = !autoBriber;
    }

    /// @dev should be called on most interactions with comETH, accrues interest and distributes
    function _hypothecate() internal {
        /// @dev poke logic
        uint256 before = aToken.balanceOf(address(this));
        aToken.transfer(OPERATIONS, 1 wei);
        uint256 dif = aToken.balanceOf(address(this)) - before;

        /// @dev fee logic
        uint256 yieldFee = ((dif * shareU) / DENOM);
        uint256 opexFee = dif - yieldFee;
        aavePool.withdraw(address(underlying), opexFee, OPERATIONS);

        /// @dev if the automatic rewarder system is enabled
        if (autoBriber) {
            /// @dev lp bribe next epoch
            underlying.approve(address(incentivesRecipient), yieldFee);
            /// @dev LP bribe next epoch
            incentivesRecipient.notifyRewardAmountNextPeriod(
                address(underlying),
                yieldFee
            );
        } else {
            /// @dev send difU to operations for processing
            aToken.transfer(OPERATIONS, yieldFee);
        }
    }
}
