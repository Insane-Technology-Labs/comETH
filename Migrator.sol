// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./ExternalLib.sol";
contract Migrator {
    IERC20 public oldToken;
    IERC20 public newToken;

    bool public paused;

    modifier whileNotPaused() {
        require(!paused, ErrorLib.Paused());
        _;
    }
}
