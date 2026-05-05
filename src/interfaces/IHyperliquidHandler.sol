// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IHyperliquidHandler {
    /// @custom:deprecated Hardcodes the validator-operated perp dex (index 0) and so returns
    /// the wrong value for users with positions on a HIP-3 dex. Prefer composing {spotUsdc}
    /// with {perpUsdc(address,uint32)} using the caller's own `perpDexIndex_`.
    function hyperliquidUsdc(address user_) external view returns (uint256);

    function spotUsdc(address user_) external view returns (uint256);

    /// @custom:deprecated Use {perpUsdc(address,uint32)} with an explicit `perpDexIndex_` instead.
    function perpUsdc(address user_) external view returns (uint256);

    function perpUsdc(address user_, uint32 perpDexIndex_) external view returns (uint256);

    /// @custom:deprecated Hardcoded to the validator-operated perp dex (index 0) and not
    /// exposed in a HIP-3 aware overload. Also redundant under Unified Account mode, where
    /// `marginUsed` and `accountValue` on the margin summary return the same value. Prefer
    /// {perpUsdc(address,uint32)} with an explicit `perpDexIndex_` instead.
    function marginUsedUsdc(address user_) external view returns (uint256);

    /// @custom:deprecated Use {notionalUsdc(address,uint32)} with an explicit `perpDexIndex_` instead.
    function notionalUsdc(address user_) external view returns (uint256);

    function notionalUsdc(address user_, uint32 perpDexIndex_) external view returns (uint256);

    function coreUserExists(address user_) external view returns (bool);
}
