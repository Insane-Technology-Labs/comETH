// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRewarder {
    function notifyRewardAmount(address _token, uint256 _amount) external;

    function notifyRewardAmountNext(address _token, uint256 _amount) external;
}
