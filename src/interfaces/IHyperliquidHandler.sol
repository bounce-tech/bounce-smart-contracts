// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IHyperliquidHandler {
    function hyperliquidUsdc(address user_) external view returns (uint256);

    function spotUsdc(address user_) external view returns (uint256);

    function perpUsdc(address user_) external view returns (uint256);

    function marginUsedUsdc(address user_) external view returns (uint256);

    function notionalUsdc(address user_) external view returns (uint256);

    function coreUserExists(address user_) external view returns (bool);
}
