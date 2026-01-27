// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IFactory} from "./IFactory.sol";
import {IHyperliquidHandler} from "./IHyperliquidHandler.sol";
import {IFeeHandler} from "./IFeeHandler.sol";
import {IVesting} from "./IVesting.sol";
import {IAirdrop} from "./IAirdrop.sol";
import {IReferrals} from "./IReferrals.sol";

interface IGlobalStorage {
    error SameAsCurrent();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidValue();
    error TotalRebateExceeds100();
    error AlreadySet();

    event SetLtImplementation(address indexed previousImplementation, address indexed newImplementation);
    event SetBaseAsset(address indexed previousAsset, address indexed newAsset);
    event SetTreasury(address indexed previousTreasury, address indexed newTreasury);
    event SetFactory(address indexed previousFactory, address indexed newFactory);
    event SetHyperliquidHandler(address indexed previousHyperliquidHandler, address indexed newHyperliquidHandler);
    event SetFeeHandler(address indexed previousFeeHandler, address indexed newFeeHandler);
    event SetBounce(address indexed previousBounce, address indexed newBounce);
    event SetVesting(address indexed previousVesting, address indexed newVesting);
    event SetAirdrop(address indexed previousAirdrop, address indexed newAirdrop);
    event SetAllMintsPaused(bool indexed previousPaused, bool indexed newPaused);
    event SetReferrals(address indexed previousReferrals, address indexed newReferrals);
    event SetMinTransactionSize(uint256 indexed previousMinTransactionSize, uint256 indexed newMinTransactionSize);
    event SetMinLockAmount(uint256 indexed previousMinLockAmount, uint256 indexed newMinLockAmount);
    event SetRedemptionFee(uint256 indexed previousFee, uint256 indexed newFee);
    event SetExecuteRedemptionFee(uint256 indexed previousFee, uint256 indexed newFee);
    event SetStreamingFee(uint256 indexed previousFee, uint256 indexed newFee);
    event SetTreasuryFeeShare(uint256 indexed previousFeeShare, uint256 indexed newFeeShare);
    event SetReferrerRebate(uint256 indexed previousRebate, uint256 indexed newRebate);
    event SetRefereeRebate(uint256 indexed previousRebate, uint256 indexed newRebate);
    event SetAdditionalAddress(bytes32 indexed key, address indexed previousValue, address indexed newValue);
    event SetAdditionalValue(bytes32 indexed key, uint256 indexed previousValue, uint256 indexed newValue);
    event SetExecutor(address indexed executor, bool indexed isExecutor);

    function owner() external view returns (address);

    function ltImplementation() external view returns (address);

    function setLtImplementation(address ltImplementation_) external;

    function baseAsset() external view returns (address);

    function setBaseAsset(address baseAsset_) external;

    function treasury() external view returns (address);

    function setTreasury(address treasury_) external;

    function factory() external view returns (IFactory);

    function setFactory(address factory_) external;

    function hyperliquidHandler() external view returns (IHyperliquidHandler);

    function setHyperliquidHandler(address hyperliquidHandler_) external;

    function feeHandler() external view returns (IFeeHandler);

    function setFeeHandler(address feeHandler_) external;

    function bounce() external view returns (IERC20Metadata);

    function allMintsPaused() external view returns (bool);

    function setAllMintsPaused(bool allMintsPaused_) external;

    function setBounce(address bounce_) external;

    function vesting() external view returns (IVesting);

    function setVesting(address vesting_) external;

    function airdrop() external view returns (IAirdrop);

    function setAirdrop(address airdrop_) external;

    function referrals() external view returns (IReferrals);

    function setReferrals(address referrals_) external;

    function minTransactionSize() external view returns (uint256);

    function setMinTransactionSize(uint256 minTransactionSize_) external;

    function minLockAmount() external view returns (uint256);

    function setMinLockAmount(uint256 minLockAmount_) external;

    function redemptionFee() external view returns (uint256);

    function setRedemptionFee(uint256 redemptionFee_) external;

    function executeRedemptionFee() external view returns (uint256);

    function setExecuteRedemptionFee(uint256 executeRedemptionFee_) external;

    function streamingFee() external view returns (uint256);

    function setStreamingFee(uint256 streamingFee_) external;

    function treasuryFeeShare() external view returns (uint256);

    function setTreasuryFeeShare(uint256 treasuryFeeShare_) external;

    function referrerRebate() external view returns (uint256);

    function setReferrerRebate(uint256 referrerRebate_) external;

    function refereeRebate() external view returns (uint256);

    function setRefereeRebate(uint256 refereeRebate_) external;

    function additionalAddresses(bytes32 key_) external view returns (address);

    function setAdditionalAddress(bytes32 key_, address value_) external;

    function additionalValues(bytes32 key_) external view returns (uint256);

    function setAdditionalValue(bytes32 key_, uint256 value_) external;

    function isExecutor(address executor_) external view returns (bool);

    function setExecutor(address executor_, bool isExecutor_) external;
}
