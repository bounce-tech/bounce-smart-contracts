// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PrecompileLib} from "@hyper-evm-lib/src/PrecompileLib.sol";

import {ScaledNumber} from "./utils/ScaledNumber.sol";
import {IHyperliquidHandler} from "./interfaces/IHyperliquidHandler.sol";

contract HyperliquidHandler is IHyperliquidHandler {
    using ScaledNumber for uint256;

    uint64 internal constant _USDC_TOKEN_INDEX = 0;
    uint32 internal constant _USDC_PERP_DEX_INDEX = 0;
    uint8 internal constant _SPOT_DECIMALS = 8;
    uint8 internal constant _USDC_DECIMALS = 6;

    function hyperliquidUsdc(address user_) external view override returns (uint256) {
        return spotUsdc(user_) + perpUsdc(user_);
    }

    function spotUsdc(address user_) public view override returns (uint256) {
        PrecompileLib.SpotBalance memory spotBalance_ = PrecompileLib.spotBalance(user_, _USDC_TOKEN_INDEX);
        return uint256(spotBalance_.total).scale(_SPOT_DECIMALS, _USDC_DECIMALS);
    }

    function perpUsdc(address user_) public view override returns (uint256) {
        PrecompileLib.AccountMarginSummary memory accountMarginSummary_ =
            PrecompileLib.accountMarginSummary(_USDC_PERP_DEX_INDEX, user_);
        if (accountMarginSummary_.accountValue < 0) return 0;
        return uint256(int256(accountMarginSummary_.accountValue));
    }

    function marginUsedUsdc(address user_) public view override returns (uint256) {
        PrecompileLib.AccountMarginSummary memory accountMarginSummary_ =
            PrecompileLib.accountMarginSummary(_USDC_PERP_DEX_INDEX, user_);
        return uint256(accountMarginSummary_.marginUsed);
    }

    function notionalUsdc(address user_) public view override returns (uint256) {
        PrecompileLib.AccountMarginSummary memory accountMarginSummary_ =
            PrecompileLib.accountMarginSummary(_USDC_PERP_DEX_INDEX, user_);
        return uint256(accountMarginSummary_.ntlPos);
    }

    function coreUserExists(address user_) external view override returns (bool) {
        return PrecompileLib.coreUserExists(user_);
    }
}
