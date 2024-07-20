// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
}

library EventLib {
    event Cooked(address indexed user, uint256 indexed amount);
    event RequestRedemption(address indexed user, uint256 indexed amount);
    event ProcessRedemption(uint256 indexed requestID, uint256 indexed amount);
    event ReferralDeposit(
        address indexed victim,
        address indexed referrer,
        uint256 indexed amountRefExtra
    );
    event PausedContract(bool indexed status);
    event TreasurySet(address indexed treasury);
    event MinReqSet(uint256 indexed minReq);
    event RefDivisorSet(uint256 indexed refDivisor);
    event EtherDeposited(address indexed depositor, uint256 indexed amount);
}
