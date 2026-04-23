// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IGlobalStorage} from "../interfaces/IGlobalStorage.sol";
import {ILeveragedToken} from "../interfaces/ILeveragedToken.sol";
import {IHyperliquidHandler} from "../interfaces/IHyperliquidHandler.sol";
import {ScaledNumber} from "../utils/ScaledNumber.sol";

import {PrecompileLib} from "@hyper-evm-lib/src/PrecompileLib.sol";

interface ILeveragedTokenHelper {
    struct AgentData {
        uint8 slot;
        address agent;
        uint256 createdAt;
    }

    struct LeveragedTokenCoreData {
        address leveragedToken;
        uint32 marketId;
        string targetAsset;
        uint256 targetLeverage;
        bool isLong;
        uint256 baseAssetBalance;
        uint256 credit;
        AgentData[3] agentData;
        bool mintPaused;
    }

    struct LeveragedTokenData {
        address leveragedToken;
        uint32 marketId;
        string targetAsset;
        uint256 targetLeverage;
        bool isLong;
        uint256 exchangeRate;
        uint256 baseAssetBalance;
        uint256 totalAssets;
        uint256 userCredit;
        uint256 credit;
        AgentData[3] agentData;
        uint256 balanceOf;
        bool mintPaused;
        bool isStandbyMode;
    }

    struct LeveragedTokenPositionData {
        address leveragedToken;
        uint256 baseAssetContractBalance;
        uint256 leveragedTokenCredit;
        uint256 usdcSpotBalance;
        uint256 usdcPerpBalance;
        uint256 usdcMargin;
        uint256 notionalValue;
        uint256 effectiveLeverage;
        uint256 targetLeverage;
    }

    struct LeveragedTokenSnapshotData {
        address leveragedToken;
        uint256 exchangeRate;
        uint256 baseAssetContractBalance;
        uint256 leveragedTokenCredit;
        uint256 usdcSpotBalance;
        uint256 usdcPerpBalance;
        uint256 usdcMargin;
        uint256 totalAssets;
        uint256 notionalValue;
    }

    struct LeveragedTokensSnapshot {
        uint256 blockNumber;
        uint256 blockTimestamp;
        uint256 l1BlockNumber;
        LeveragedTokenSnapshotData[] tokens;
    }

    struct TotalAssets {
        address leveragedTokenAddress;
        uint256 totalAssets;
    }

    struct ExchangeRates {
        address leveragedTokenAddress;
        uint256 exchangeRate;
    }

    function getLeveragedTokens() external view returns (LeveragedTokenData[] memory);

    function getLeveragedTokens(address user_, bool onlyHeld_) external view returns (LeveragedTokenData[] memory);

    function getLeveragedTokensCoreData() external view returns (LeveragedTokenCoreData[] memory);

    function getLeveragedTokenPositionData(address leveragedTokenAddress_)
        external
        view
        returns (LeveragedTokenPositionData memory);

    function getLeveragedTokenPositionData() external view returns (LeveragedTokenPositionData[] memory);

    function getLeveragedTokensSnapshot() external view returns (LeveragedTokensSnapshot memory);

    function getLeveragedTokenBufferAssetValue(address leveragedTokenAddress_) external view returns (int256);

    function getTotalAssets() external view returns (TotalAssets[] memory);

    function getExchangeRates() external view returns (ExchangeRates[] memory);
}

contract LeveragedTokenHelper is ILeveragedTokenHelper {
    using ScaledNumber for uint256;

    uint256 internal constant _MIN_ASSET_VALUE_THRESHOLD = 1e18;
    uint256 internal constant _STANDBY_THRESHOLD = 0.97e18;
    IGlobalStorage internal immutable _GLOBAL_STORAGE;

    constructor(address globalStorage_) {
        _GLOBAL_STORAGE = IGlobalStorage(globalStorage_);
    }

    function getLeveragedTokens() external view override returns (LeveragedTokenData[] memory) {
        return getLeveragedTokens(address(0), false);
    }

    function getLeveragedTokens(address user_, bool onlyHeld_)
        public
        view
        override
        returns (LeveragedTokenData[] memory)
    {
        address[] memory lts_ = _GLOBAL_STORAGE.factory().lts();
        uint256 heldTokensCount = 0;
        LeveragedTokenData[] memory leveragedTokenData = new LeveragedTokenData[](lts_.length);

        for (uint256 i = 0; i < lts_.length; i++) {
            LeveragedTokenData memory leveragedTokenData_ = _getLeveragedTokenData(lts_[i], user_);
            uint256 assetValue_ = leveragedTokenData_.balanceOf.mul(leveragedTokenData_.exchangeRate);
            bool isHeld_ = assetValue_ >= _MIN_ASSET_VALUE_THRESHOLD;
            if (onlyHeld_ && !isHeld_) continue;
            leveragedTokenData[heldTokensCount] = leveragedTokenData_;
            heldTokensCount++;
        }

        if (onlyHeld_ && heldTokensCount < lts_.length) {
            assembly {
                mstore(leveragedTokenData, heldTokensCount)
            }
        }

        return leveragedTokenData;
    }

    function _getLeveragedTokenData(address leveragedTokenAddress_, address user_)
        internal
        view
        returns (LeveragedTokenData memory)
    {
        ILeveragedToken lt_ = ILeveragedToken(leveragedTokenAddress_);
        return LeveragedTokenData({
            leveragedToken: leveragedTokenAddress_,
            marketId: lt_.marketId(),
            targetAsset: lt_.targetAsset(),
            targetLeverage: lt_.targetLeverage(),
            isLong: lt_.isLong(),
            exchangeRate: lt_.exchangeRate(),
            baseAssetBalance: lt_.baseAssetBalance(),
            totalAssets: lt_.totalAssets(),
            userCredit: lt_.userCredit(user_),
            credit: lt_.credit(),
            agentData: _getAgentData(lt_),
            balanceOf: lt_.balanceOf(user_),
            mintPaused: lt_.mintPaused(),
            isStandbyMode: _isStandbyMode(lt_)
        });
    }

    function getLeveragedTokensCoreData() external view override returns (LeveragedTokenCoreData[] memory) {
        address[] memory lts_ = _GLOBAL_STORAGE.factory().lts();
        LeveragedTokenCoreData[] memory leveragedTokenCoreData = new LeveragedTokenCoreData[](lts_.length);
        for (uint256 i = 0; i < lts_.length; i++) {
            ILeveragedToken lt_ = ILeveragedToken(lts_[i]);
            leveragedTokenCoreData[i] = LeveragedTokenCoreData({
                leveragedToken: lts_[i],
                marketId: lt_.marketId(),
                targetAsset: lt_.targetAsset(),
                targetLeverage: lt_.targetLeverage(),
                isLong: lt_.isLong(),
                baseAssetBalance: lt_.baseAssetBalance(),
                credit: lt_.credit(),
                agentData: _getAgentData(lt_),
                mintPaused: lt_.mintPaused()
            });
        }
        return leveragedTokenCoreData;
    }

    function _getAgentData(ILeveragedToken lt_) internal view returns (AgentData[3] memory) {
        address[3] memory agentAddrs_ = lt_.agents();
        AgentData[3] memory agentData_;
        for (uint256 j = 0; j < 3; j++) {
            address agent_ = agentAddrs_[j];
            agentData_[j] = AgentData({slot: uint8(j), agent: agent_, createdAt: lt_.agentCreatedAt(agent_)});
        }
        return agentData_;
    }

    function getLeveragedTokenPositionData() external view override returns (LeveragedTokenPositionData[] memory) {
        address[] memory lts_ = _GLOBAL_STORAGE.factory().lts();
        LeveragedTokenPositionData[] memory positionData = new LeveragedTokenPositionData[](lts_.length);

        IHyperliquidHandler hh_ = IHyperliquidHandler(_GLOBAL_STORAGE.hyperliquidHandler());
        IERC20Metadata baseAsset_ = IERC20Metadata(_GLOBAL_STORAGE.baseAsset());
        uint8 baseAssetDecimals_ = baseAsset_.decimals();

        for (uint256 i = 0; i < lts_.length; i++) {
            address leveragedTokenAddress_ = lts_[i];
            ILeveragedToken lt_ = ILeveragedToken(leveragedTokenAddress_);
            uint256 notionalValue_ = hh_.notionalUsdc(address(lt_));
            uint256 credit_ = lt_.credit();
            uint256 netValue_ = lt_.totalAssets().scaleFrom(baseAssetDecimals_) - credit_.mul(lt_.exchangeRate());
            uint256 notionalValueScaled_ = notionalValue_.scaleFrom(baseAssetDecimals_);
            uint256 effectiveLeverage_ = netValue_ == 0 ? 0 : notionalValueScaled_.div(netValue_);

            positionData[i] = LeveragedTokenPositionData({
                leveragedToken: leveragedTokenAddress_,
                baseAssetContractBalance: lt_.baseAssetBalance(),
                leveragedTokenCredit: credit_,
                usdcSpotBalance: hh_.spotUsdc(leveragedTokenAddress_),
                usdcPerpBalance: hh_.perpUsdc(leveragedTokenAddress_),
                usdcMargin: hh_.marginUsedUsdc(leveragedTokenAddress_),
                notionalValue: notionalValue_,
                effectiveLeverage: effectiveLeverage_,
                targetLeverage: lt_.targetLeverage()
            });
        }

        return positionData;
    }

    function getLeveragedTokenPositionData(address leveragedTokenAddress_)
        external
        view
        override
        returns (LeveragedTokenPositionData memory)
    {
        ILeveragedToken lt_ = ILeveragedToken(leveragedTokenAddress_);
        IHyperliquidHandler hh_ = IHyperliquidHandler(_GLOBAL_STORAGE.hyperliquidHandler());
        IERC20Metadata baseAsset_ = IERC20Metadata(_GLOBAL_STORAGE.baseAsset());
        uint8 baseAssetDecimals_ = baseAsset_.decimals();
        uint256 notionalValue_ = hh_.notionalUsdc(address(lt_));
        uint256 credit_ = lt_.credit();
        uint256 netValue_ = lt_.totalAssets().scaleFrom(baseAssetDecimals_) - credit_.mul(lt_.exchangeRate());
        uint256 notionalValueScaled_ = notionalValue_.scaleFrom(baseAssetDecimals_);
        uint256 effectiveLeverage_ = netValue_ == 0 ? 0 : notionalValueScaled_.div(netValue_);

        return LeveragedTokenPositionData({
            leveragedToken: leveragedTokenAddress_,
            baseAssetContractBalance: lt_.baseAssetBalance(),
            leveragedTokenCredit: credit_,
            usdcSpotBalance: hh_.spotUsdc(leveragedTokenAddress_),
            usdcPerpBalance: hh_.perpUsdc(leveragedTokenAddress_),
            usdcMargin: hh_.marginUsedUsdc(leveragedTokenAddress_),
            notionalValue: notionalValue_,
            effectiveLeverage: effectiveLeverage_,
            targetLeverage: lt_.targetLeverage()
        });
    }

    function getLeveragedTokensSnapshot() external view override returns (LeveragedTokensSnapshot memory) {
        address[] memory lts_ = _GLOBAL_STORAGE.factory().lts();
        LeveragedTokenSnapshotData[] memory snapshotData = new LeveragedTokenSnapshotData[](lts_.length);

        for (uint256 i = 0; i < lts_.length; i++) {
            snapshotData[i] = _getLeveragedTokenSnapshotData(lts_[i]);
        }

        return LeveragedTokensSnapshot({
            blockNumber: block.number,
            blockTimestamp: block.timestamp,
            l1BlockNumber: PrecompileLib.l1BlockNumber(),
            tokens: snapshotData
        });
    }

    function getLeveragedTokenBufferAssetValue(address leveragedTokenAddress_) external view override returns (int256) {
        ILeveragedToken lt_ = ILeveragedToken(leveragedTokenAddress_);
        uint8 baseAssetDecimals_ = IERC20Metadata(_GLOBAL_STORAGE.baseAsset()).decimals();
        uint256 baseAssetValue_ = lt_.baseAssetBalance().scaleFrom(baseAssetDecimals_);
        uint256 creditValue_ = lt_.credit().mul(lt_.exchangeRate());
        return int256(baseAssetValue_) - int256(creditValue_);
    }

    function getTotalAssets() external view override returns (TotalAssets[] memory) {
        address[] memory lts_ = _GLOBAL_STORAGE.factory().lts();
        TotalAssets[] memory totalAssets = new TotalAssets[](lts_.length);
        for (uint256 i = 0; i < lts_.length; i++) {
            ILeveragedToken lt_ = ILeveragedToken(lts_[i]);
            totalAssets[i] = TotalAssets({leveragedTokenAddress: address(lt_), totalAssets: lt_.totalAssets()});
        }
        return totalAssets;
    }

    function getExchangeRates() external view override returns (ExchangeRates[] memory) {
        address[] memory lts_ = _GLOBAL_STORAGE.factory().lts();
        ExchangeRates[] memory exchangeRates = new ExchangeRates[](lts_.length);
        for (uint256 i = 0; i < lts_.length; i++) {
            ILeveragedToken lt_ = ILeveragedToken(lts_[i]);
            exchangeRates[i] = ExchangeRates({leveragedTokenAddress: address(lt_), exchangeRate: lt_.exchangeRate()});
        }
        return exchangeRates;
    }

    function _getLeveragedTokenSnapshotData(address leveragedTokenAddress_)
        internal
        view
        returns (LeveragedTokenSnapshotData memory)
    {
        ILeveragedToken lt_ = ILeveragedToken(leveragedTokenAddress_);
        IHyperliquidHandler hh_ = IHyperliquidHandler(_GLOBAL_STORAGE.hyperliquidHandler());
        uint256 notionalValue_ = hh_.notionalUsdc(address(lt_));

        return LeveragedTokenSnapshotData({
            leveragedToken: leveragedTokenAddress_,
            exchangeRate: lt_.exchangeRate(),
            baseAssetContractBalance: lt_.baseAssetBalance(),
            leveragedTokenCredit: lt_.credit(),
            usdcSpotBalance: hh_.spotUsdc(leveragedTokenAddress_),
            usdcPerpBalance: hh_.perpUsdc(leveragedTokenAddress_),
            usdcMargin: hh_.marginUsedUsdc(leveragedTokenAddress_),
            totalAssets: lt_.totalAssets(),
            notionalValue: notionalValue_
        });
    }

    function _isStandbyMode(ILeveragedToken lt_) internal view returns (bool) {
        uint256 totalAssets_ = lt_.totalAssets();
        if (totalAssets_ == 0) return true;

        uint256 ratio_ = lt_.baseAssetBalance().div(totalAssets_);

        return ratio_ >= _STANDBY_THRESHOLD;
    }
}
