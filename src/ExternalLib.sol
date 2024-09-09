// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library ErrorLib {
    error Paused();
    error NoChangeInBoolean();
    error Zero();
    error Fulfilled();
    error BelowMinimum();
    error Failed();
    error FallbackFailed();
    error FailedOnSend();
    error AboveMinimum();
    error SwapFailed();
    error DivisorBelowMinimum();
    error DivisorAboveMinimum();
    error SelfReferProhibited();
}

library EventLib {
    event Minted(address indexed user, uint256 indexed amount);
    event Redemption(address indexed user, uint256 indexed amount);
    event PausedContract(bool indexed status);
}
