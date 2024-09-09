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
    uint256 public shareU = 5000;
    uint256 public shareT = 5000;

    bool public autoRewarder;

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
        autoRewarder = false;
        incentivesRecipient = IRewarder(_incentivesRecipient);
        underlying = IERC20(aToken.UNDERLYING_ASSET_ADDRESS());
        ++initialized;
    }

    /// @notice change the gauge where LP incentives are submitted
    function changeRecipient(address _ir) external onlyOperator {
        incentivesRecipient = IRewarder(_ir);
    }

    /// @notice function to change the share %s
    function changeShares(
        uint256 _shareU,
        uint256 _shareT
    ) external onlyOperator {
        require((_shareU + _shareU) == DENOM, "!denom");
        (shareU, shareT) = (_shareU, _shareT);
    }

    /// @notice changes the auto rewarder status
    function toggleAutoRewarder() external onlyOperator {
        autoRewarder = !autoRewarder;
    }

    /// @dev function which takes earned profit and distributes it
    function _hypothecate() internal {
        /// @dev poke logic
        uint256 before = aToken.balanceOf(address(this));
        aToken.transfer(OPERATIONS, 1 wei);
        uint256 dif = aToken.balanceOf(address(this)) - before;

        /// @dev fee logic
        uint256 difU = ((dif * shareU) / DENOM);
        uint256 difT = dif - difU;
        aavePool.withdraw(address(underlying), difT, OPERATIONS);

        /// @dev if the automatic rewarder system is enabled
        if (autoRewarder) {
            /// @dev lp bribe next epoch
            underlying.approve(address(incentivesRecipient), difU);
            incentivesRecipient.notifyRewardAmountNext(
                address(underlying),
                difU
            );
        } else {
            /// @dev send difU to operations for processing
            IERC20(address(aToken)).transfer(OPERATIONS, difU);
        }
    }
}
