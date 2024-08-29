// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {INT} from "./INT.sol";
contract Migrator {
    IERC20 public oldToken;
    INT public newToken;
    address public constant OPERATIONS =
        0xBFc57B070b1EDA0FCb9c203EDc1085c626F3A36d;

    /// @notice 10 million INT per 1 ITX
    uint256 public constant SPLIT = 10_000_000;

    /// @notice amount that each individual user migrated
    mapping(address => uint256) public amountMigrated;

    /// @notice amount of ITX tokens migrated (always <= 100)
    uint256 public totalItxMigrated;

    event Migrated(address user, uint256 amount, uint256 newAmount);

    constructor(address _oldToken, address _newToken) {
        oldToken = IERC20(_oldToken);
        newToken = INT(_newToken);
        totalItxMigrated = 0;
    }

    /// @notice migrate ITX --> INT at 1 per 10m
    function migrate(uint256 _amount) external {
        /// @dev 100 cap as that was ITX total supply
        require(totalItxMigrated + _amount <= 100, ErrorLib.Failed());
        oldToken.transferFrom(msg.sender, address(this), _amount);
        oldToken.burn(_amount);
        totalItxMigrated += _amount;
        amountMigrated[msg.sender] += _amount;
        uint256 newAmount = _amount * SPLIT;
        INT.mint(msg.sender, newAmount);
        emit Migrated(msg.sender, _amount, newAmount);
        if (totalItxMigrated == 100) {
            INT.renounceRole(bytes32(keccak256("MINTER_ROLE")), address(this));
        }
    }

    /// @notice in case of stuck funds, return to OPERATIONS msig to be redistributed
    function rescue(address _token) external {
        require(msg.sender == OPERATIONS, ErrorLib.Failed());
        IERC20(_token).transfer(
            OPERATIONS,
            IERC20(_token).balanceOf(address(this))
        );
    }
}
