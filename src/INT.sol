// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/// @dev import external libraries for error and event handling
/// @dev implements ErrorLib & EventLib
import {ErrorLib, EventLib} from "./libraries/ExternalLib.sol";

contract INT is OFT, AccessControl {
    /// @notice Minter access control role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public constant OPERATIONS =
        0xBFc57B070b1EDA0FCb9c203EDc1085c626F3A36d;

    /// @dev layerzero endpoint address
    constructor(
        address _endpoint
    ) OFT("INT", "INT", _endpoint, OPERATIONS) Ownable(OPERATIONS) {
        /// @dev grant the appropriate roles to the treasury
        _grantRole(DEFAULT_ADMIN_ROLE, OPERATIONS);
        /// @dev grant roles to deployer for initial testing
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /// @notice mint function used by the migrator
    function mint(address _dst, uint256 _amt) external onlyRole(MINTER_ROLE) {
        _mint(_dst, _amt);
    }

    /// @notice standard decimal return
    /// @return uint8 decimals
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /// @dev revert on msg.value being delivered to the address w/o data
    receive() external payable {
        revert ErrorLib.FailedOnSend();
    }

    /// @dev revert on non-existent function calls or payload eth sends
    fallback() external payable {
        revert ErrorLib.FallbackFailed();
    }
}
