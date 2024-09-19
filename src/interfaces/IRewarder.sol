// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRewarder {
    function notifyRewardAmountNextPeriod(
        address _token,
        uint256 _amount
    ) external;
}
