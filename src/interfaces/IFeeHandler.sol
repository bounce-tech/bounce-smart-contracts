// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFeeHandler {
    error NotEnabled();

    event HandleFees(address indexed sender, uint256 amount);

    function enabled() external view returns (bool);

    function handleFees(uint256 amount_) external;
}
