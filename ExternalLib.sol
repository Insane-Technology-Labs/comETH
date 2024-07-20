// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ErrorLib {
    error Paused();
    error NoChangeInBoolean();
    error Zero();
    error Fulfilled();
    error BelowMinimum();
    error Failed();
}

library EventLib{
    event Cooked(address indexed user, uint256 indexed amount);
    event RequestRedemption(address indexed user, uint256 indexed amount);
    event ProcessRedemption(uint256 indexed requestID, uint256 indexed amount);
    event ReferralDeposit(address indexed victim, address indexed referrer, uint256 indexed extraRefPoints);
    event SybilPurged(address indexed sybil, uint256 indexed burnedPoints);
    event AccruePoints(address indexed user, uint256 indexed accruedPoints);
}
