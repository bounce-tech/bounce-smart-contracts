// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IGlobalStorage} from "../interfaces/IGlobalStorage.sol";

interface IGlobalStorageHelper {
    struct GlobalStorageData {
        address owner;
        address ltImplementation;
        address baseAsset;
        address treasury;
        address factory;
        address hyperliquidHandler;
        address feeHandler;
        address bounce;
        bool allMintsPaused;
        address vesting;
        address airdrop;
        address referrals;
        uint256 minTransactionSize;
        uint256 minLockAmount;
        uint256 redemptionFee;
        uint256 streamingFee;
        uint256 executeRedemptionFee;
        uint256 treasuryFeeShare;
        uint256 referrerRebate;
        uint256 refereeRebate;
    }

    function getGlobalStorageData() external view returns (GlobalStorageData memory);
}

contract GlobalStorageHelper is IGlobalStorageHelper {
    IGlobalStorage internal immutable _GLOBAL_STORAGE;

    constructor(address globalStorage_) {
        _GLOBAL_STORAGE = IGlobalStorage(globalStorage_);
    }

    function getGlobalStorageData() external view override returns (GlobalStorageData memory) {
        return GlobalStorageData({
            owner: _GLOBAL_STORAGE.owner(),
            ltImplementation: _GLOBAL_STORAGE.ltImplementation(),
            baseAsset: _GLOBAL_STORAGE.baseAsset(),
            treasury: _GLOBAL_STORAGE.treasury(),
            factory: address(_GLOBAL_STORAGE.factory()),
            hyperliquidHandler: address(_GLOBAL_STORAGE.hyperliquidHandler()),
            feeHandler: address(_GLOBAL_STORAGE.feeHandler()),
            bounce: address(_GLOBAL_STORAGE.bounce()),
            allMintsPaused: _GLOBAL_STORAGE.allMintsPaused(),
            vesting: address(_GLOBAL_STORAGE.vesting()),
            airdrop: address(_GLOBAL_STORAGE.airdrop()),
            referrals: address(_GLOBAL_STORAGE.referrals()),
            minTransactionSize: _GLOBAL_STORAGE.minTransactionSize(),
            minLockAmount: _GLOBAL_STORAGE.minLockAmount(),
            redemptionFee: _GLOBAL_STORAGE.redemptionFee(),
            streamingFee: _GLOBAL_STORAGE.streamingFee(),
            executeRedemptionFee: _GLOBAL_STORAGE.executeRedemptionFee(),
            treasuryFeeShare: _GLOBAL_STORAGE.treasuryFeeShare(),
            referrerRebate: _GLOBAL_STORAGE.referrerRebate(),
            refereeRebate: _GLOBAL_STORAGE.refereeRebate()
        });
    }
}
