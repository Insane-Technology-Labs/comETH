// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./ExternalLib.sol";
contract Migrator {
    IERC20 public oldToken;
    IERC20 public newToken;

    bool public paused;

    address public constant OPERATIONS =
        0xBFc57B070b1EDA0FCb9c203EDc1085c626F3A36d;

    modifier whileNotPaused() {
        require(!paused, ErrorLib.Paused());
        _;
    }

    constructor(address _oldToken, address _newToken) {
        oldToken = IERC20(_oldToken);
        newToken = IERC20(_newToken);
    }
}
