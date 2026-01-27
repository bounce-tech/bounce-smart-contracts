// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {ScaledNumber} from "./utils/ScaledNumber.sol";

import {IGlobalStorage} from "./interfaces/IGlobalStorage.sol";
import {IHyperliquidHandler} from "./interfaces/IHyperliquidHandler.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IFeeHandler} from "./interfaces/IFeeHandler.sol";
import {IVesting} from "./interfaces/IVesting.sol";
import {IAirdrop} from "./interfaces/IAirdrop.sol";
import {IReferrals} from "./interfaces/IReferrals.sol";

contract GlobalStorage is IGlobalStorage, Ownable2Step {
    using ScaledNumber for uint256;
    using SafeERC20 for IERC20Metadata;

    uint256 internal constant _MAX_REDEMPTION_FEE = 0.02e18;
    uint256 internal constant _MAX_STREAMING_FEE = 0.1e18;
    uint256 internal constant _MAX_EXECUTE_REDEMPTION_FEE_RATIO = 0.5e18;
    uint256 internal constant _MAX_MIN_TRANSACTION_SIZE_UNSCALED = 100;

    address public override ltImplementation;
    address public override baseAsset;
    address public override treasury;
    IFactory public override factory;
    IHyperliquidHandler public override hyperliquidHandler;
    IFeeHandler public override feeHandler;
    IVesting public override vesting;
    IAirdrop public override airdrop;
    IReferrals public override referrals;
    IERC20Metadata public override bounce;
    bool public override allMintsPaused;
    uint256 public override minTransactionSize;
    uint256 public override minLockAmount;
    uint256 public override redemptionFee;
    uint256 public override executeRedemptionFee;
    uint256 public override streamingFee;
    uint256 public override treasuryFeeShare;
    uint256 public override referrerRebate;
    uint256 public override refereeRebate;
    mapping(bytes32 => address) public additionalAddresses;
    mapping(bytes32 => uint256) public additionalValues;
    mapping(address => bool) public override isExecutor;

    constructor() Ownable(msg.sender) {}

    function owner() public view override(IGlobalStorage, Ownable) returns (address) {
        return super.owner();
    }

    function setLtImplementation(address ltImplementation_) external override onlyOwner {
        if (ltImplementation_ == ltImplementation) revert SameAsCurrent();
        if (ltImplementation_ == address(0)) revert InvalidAddress();
        emit SetLtImplementation(ltImplementation, ltImplementation_);
        ltImplementation = ltImplementation_;
    }

    function setBaseAsset(address baseAsset_) external override onlyOwner {
        if (baseAsset_ == baseAsset) revert SameAsCurrent();
        if (baseAsset_ == address(0)) revert InvalidAddress();
        if (baseAsset != address(0)) revert AlreadySet();
        emit SetBaseAsset(baseAsset, baseAsset_);
        baseAsset = baseAsset_;
    }

    function setTreasury(address treasury_) external override onlyOwner {
        if (treasury_ == treasury) revert SameAsCurrent();
        if (treasury_ == address(0)) revert InvalidAddress();
        emit SetTreasury(treasury, treasury_);
        treasury = treasury_;
    }

    function setFactory(address factory_) external onlyOwner {
        if (factory_ == address(0)) revert InvalidAddress();
        if (factory_ == address(factory)) revert SameAsCurrent();
        emit SetFactory(address(factory), factory_);
        factory = IFactory(factory_);
    }

    function setHyperliquidHandler(address hyperliquidHandler_) external onlyOwner {
        if (hyperliquidHandler_ == address(0)) revert InvalidAddress();
        if (hyperliquidHandler_ == address(hyperliquidHandler)) revert SameAsCurrent();
        emit SetHyperliquidHandler(address(hyperliquidHandler), hyperliquidHandler_);
        hyperliquidHandler = IHyperliquidHandler(hyperliquidHandler_);
    }

    function setFeeHandler(address feeHandler_) external onlyOwner {
        if (feeHandler_ == address(0)) revert InvalidAddress();
        if (feeHandler_ == address(feeHandler)) revert SameAsCurrent();
        emit SetFeeHandler(address(feeHandler), feeHandler_);
        feeHandler = IFeeHandler(feeHandler_);
    }

    function setBounce(address bounce_) external override onlyOwner {
        if (bounce_ == address(0)) revert InvalidAddress();
        if (address(bounce) != address(0)) revert AlreadySet();
        emit SetBounce(address(bounce), bounce_);
        bounce = IERC20Metadata(bounce_);
    }

    function setVesting(address vesting_) external override onlyOwner {
        if (vesting_ == address(0)) revert InvalidAddress();
        if (vesting_ == address(vesting)) revert SameAsCurrent();
        emit SetVesting(address(vesting), vesting_);
        vesting = IVesting(vesting_);
    }

    function setAirdrop(address airdrop_) external override onlyOwner {
        if (airdrop_ == address(0)) revert InvalidAddress();
        if (airdrop_ == address(airdrop)) revert SameAsCurrent();
        emit SetAirdrop(address(airdrop), airdrop_);
        airdrop = IAirdrop(airdrop_);
    }

    function setReferrals(address referrals_) external override onlyOwner {
        if (referrals_ == address(0)) revert InvalidAddress();
        if (referrals_ == address(referrals)) revert SameAsCurrent();
        emit SetReferrals(address(referrals), referrals_);
        referrals = IReferrals(referrals_);
    }

    function setAllMintsPaused(bool allMintsPaused_) external override onlyOwner {
        if (allMintsPaused_ == allMintsPaused) revert SameAsCurrent();
        emit SetAllMintsPaused(allMintsPaused, allMintsPaused_);
        allMintsPaused = allMintsPaused_;
    }

    function setMinTransactionSize(uint256 minTransactionSize_) external override onlyOwner {
        if (minTransactionSize_ == minTransactionSize) revert SameAsCurrent();
        if (minTransactionSize_ == 0) revert InvalidAmount();
        uint8 baseAssetDecimals_ = IERC20Metadata(baseAsset).decimals();
        uint256 maxMinTransactionSize_ = _MAX_MIN_TRANSACTION_SIZE_UNSCALED * 10 ** baseAssetDecimals_;
        if (minTransactionSize_ > maxMinTransactionSize_) revert InvalidAmount();
        emit SetMinTransactionSize(minTransactionSize, minTransactionSize_);
        minTransactionSize = minTransactionSize_;
    }

    function setMinLockAmount(uint256 minLockAmount_) external override onlyOwner {
        if (minLockAmount_ == minLockAmount) revert SameAsCurrent();
        if (minLockAmount_ == 0) revert InvalidAmount();
        emit SetMinLockAmount(minLockAmount, minLockAmount_);
        minLockAmount = minLockAmount_;
    }

    function setRedemptionFee(uint256 redemptionFee_) external override onlyOwner {
        if (redemptionFee_ == redemptionFee) revert SameAsCurrent();
        if (redemptionFee_ > _MAX_REDEMPTION_FEE) revert InvalidValue();
        emit SetRedemptionFee(redemptionFee, redemptionFee_);
        redemptionFee = redemptionFee_;
    }

    function setExecuteRedemptionFee(uint256 executeRedemptionFee_) external override onlyOwner {
        if (executeRedemptionFee_ == executeRedemptionFee) revert SameAsCurrent();
        uint256 maxExecuteRedemptionFee_ = minTransactionSize.mul(_MAX_EXECUTE_REDEMPTION_FEE_RATIO);
        if (executeRedemptionFee_ > maxExecuteRedemptionFee_) revert InvalidAmount();
        emit SetExecuteRedemptionFee(executeRedemptionFee, executeRedemptionFee_);
        executeRedemptionFee = executeRedemptionFee_;
    }

    function setStreamingFee(uint256 streamingFee_) external override onlyOwner {
        if (streamingFee_ == streamingFee) revert SameAsCurrent();
        if (streamingFee_ > _MAX_STREAMING_FEE) revert InvalidAmount();
        emit SetStreamingFee(streamingFee, streamingFee_);
        streamingFee = streamingFee_;
    }

    function setTreasuryFeeShare(uint256 treasuryFeeShare_) external override onlyOwner {
        if (treasuryFeeShare_ == treasuryFeeShare) revert SameAsCurrent();
        if (treasuryFeeShare_ > 1e18) revert InvalidAmount();
        emit SetTreasuryFeeShare(treasuryFeeShare, treasuryFeeShare_);
        treasuryFeeShare = treasuryFeeShare_;
    }

    function setReferrerRebate(uint256 referrerRebate_) external override onlyOwner {
        if (referrerRebate_ == referrerRebate) revert SameAsCurrent();
        if (referrerRebate_ > 1e18) revert InvalidAmount();
        uint256 totalRebate_ = referrerRebate_ + refereeRebate;
        if (totalRebate_ > 1e18) revert TotalRebateExceeds100();
        emit SetReferrerRebate(referrerRebate, referrerRebate_);
        referrerRebate = referrerRebate_;
    }

    function setRefereeRebate(uint256 refereeRebate_) external override onlyOwner {
        if (refereeRebate_ == refereeRebate) revert SameAsCurrent();
        if (refereeRebate_ > 1e18) revert InvalidAmount();
        uint256 totalRebate_ = referrerRebate + refereeRebate_;
        if (totalRebate_ > 1e18) revert TotalRebateExceeds100();
        emit SetRefereeRebate(refereeRebate, refereeRebate_);
        refereeRebate = refereeRebate_;
    }

    function setAdditionalAddress(bytes32 key_, address value_) external override onlyOwner {
        emit SetAdditionalAddress(key_, additionalAddresses[key_], value_);
        additionalAddresses[key_] = value_;
    }

    function setAdditionalValue(bytes32 key_, uint256 value_) external override onlyOwner {
        emit SetAdditionalValue(key_, additionalValues[key_], value_);
        additionalValues[key_] = value_;
    }

    function setExecutor(address executor_, bool isExecutor_) external override onlyOwner {
        if (isExecutor[executor_] == isExecutor_) revert SameAsCurrent();
        emit SetExecutor(executor_, isExecutor_);
        isExecutor[executor_] = isExecutor_;
    }
}
