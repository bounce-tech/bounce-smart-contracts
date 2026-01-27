// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library ScaledNumber {
    error DivisionByZero();

    function scale(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
        if (fromDecimals > toDecimals) {
            return amount / (10 ** (fromDecimals - toDecimals));
        } else if (fromDecimals < toDecimals) {
            return amount * (10 ** (toDecimals - fromDecimals));
        } else {
            return amount;
        }
    }

    function scaleFrom(uint256 amount, uint8 fromDecimals) internal pure returns (uint256) {
        return scale(amount, fromDecimals, 18);
    }

    function scaleTo(uint256 amount, uint8 toDecimals) internal pure returns (uint256) {
        return scale(amount, 18, toDecimals);
    }

    function div(uint256 amount, uint256 divisor) internal pure returns (uint256) {
        if (divisor == 0) revert DivisionByZero();
        return (amount * 1e18) / divisor;
    }

    function mul(uint256 amount, uint256 multiplier) internal pure returns (uint256) {
        return (amount * multiplier) / 1e18;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? b : a;
    }
}
