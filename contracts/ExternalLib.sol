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
    event RequestRedemption(address indexed user, uint256 indexed amount);
    event ProcessRedemption(uint256 indexed requestID, uint256 indexed amount);
    event ReferralDeposit(
        address indexed victim,
        address indexed referrer,
        uint256 indexed amountRefExtra
    );
    event PausedContract(bool indexed status);
    event MinReqSet(uint256 indexed minReq);
}
