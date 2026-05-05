// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {CoreWriterLib} from "@hyper-evm-lib/src/CoreWriterLib.sol";

import {ILeveragedToken} from "./interfaces/ILeveragedToken.sol";
import {ScaledNumber} from "./utils/ScaledNumber.sol";
import {IGlobalStorage} from "./interfaces/IGlobalStorage.sol";
import {IReferrals} from "./interfaces/IReferrals.sol";
import {IFeeHandler} from "./interfaces/IFeeHandler.sol";
import {IHyperliquidHandler} from "./interfaces/IHyperliquidHandler.sol";

contract LeveragedToken is ILeveragedToken, ERC20Upgradeable {
    using ScaledNumber for uint256;
    using SafeERC20 for IERC20Metadata;

    string internal constant _VERSION = "v1.1.0";

    // keccak256(abi.encode(uint256(keccak256("leveraged.token.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant _LEVERAGED_TOKEN_STORAGE_LOCATION =
        0x308983bdf75389e7a3bc73dfa9e8cc5174cc0148cdb570998150a02ae8083000;
    uint8 internal constant _AGENT_SLOTS = 3;
    uint256 internal constant _CANCEL_REDEMPTION_DELAY = 1 hours;
    uint32 internal constant _HIP_3_BASE = 100_000;
    uint32 internal constant _HIP_3_DEX_STRIDE = 10_000;

    /// @custom:storage-location erc7201:leveraged.token.storage
    struct LeveragedTokenStorage {
        IGlobalStorage globalStorage;
        uint256 lastCheckpoint;
        uint32 marketId;
        string targetAsset;
        uint256 targetLeverage;
        bool isLong;
        bool mintPaused;
        address[] pendingRedemptions;
        mapping(address => uint256) pendingRedemptionIndex;
        mapping(address => uint256) pendingRedemptionTimestamp;
        mapping(address => uint256) userCredit;
        uint256 credit;
        mapping(uint256 => uint256) blockBridging;
        address[_AGENT_SLOTS] agents;
        mapping(address => uint256) agentCreatedAt;
        mapping(address => bool) isAgent;
        uint32 perpDexIndex;
    }

    function _getLeveragedTokenStorage() internal pure returns (LeveragedTokenStorage storage $) {
        assembly {
            $.slot := _LEVERAGED_TOKEN_STORAGE_LOCATION
        }
    }

    modifier onlyOwner() {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        if (msg.sender != $.globalStorage.owner()) revert NotOwner();
        _;
    }

    modifier onlyAgents() {
        if (!isAgent(msg.sender)) revert NotAgent();
        _;
    }

    modifier onlyExecutors() {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        if (!$.globalStorage.isExecutor(msg.sender)) revert NotExecutor();
        _;
    }

    modifier whenNotMintPaused() {
        if (mintPaused()) revert MintPaused();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address globalStorage_,
        uint32 marketId_,
        string memory targetAsset_,
        uint256 targetLeverage_,
        bool isLong_,
        string memory name_,
        string memory symbol_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        $.globalStorage = IGlobalStorage(globalStorage_);
        $.marketId = marketId_;
        $.targetAsset = targetAsset_;
        $.targetLeverage = targetLeverage_;
        $.isLong = isLong_;
        $.perpDexIndex = _getPerpDexIndex(marketId_);
    }

    function version() external pure override returns (string memory) {
        return _VERSION;
    }

    function marketId() public view override returns (uint32) {
        return _getLeveragedTokenStorage().marketId;
    }

    function targetAsset() public view override returns (string memory) {
        return _getLeveragedTokenStorage().targetAsset;
    }

    function targetLeverage() public view override returns (uint256) {
        return _getLeveragedTokenStorage().targetLeverage;
    }

    function isLong() public view override returns (bool) {
        return _getLeveragedTokenStorage().isLong;
    }

    function perpDexIndex() public view override returns (uint32) {
        return _getLeveragedTokenStorage().perpDexIndex;
    }

    function lastCheckpoint() public view override returns (uint256) {
        return _getLeveragedTokenStorage().lastCheckpoint;
    }

    function userCredit(address user_) public view override returns (uint256) {
        return _getLeveragedTokenStorage().userCredit[user_];
    }

    function credit() public view override returns (uint256) {
        return _getLeveragedTokenStorage().credit;
    }

    function agents() public view override returns (address[_AGENT_SLOTS] memory) {
        return _getLeveragedTokenStorage().agents;
    }

    function getAgentSlot(address agent_) public view override returns (uint8) {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        for (uint8 i = 0; i < _AGENT_SLOTS; i++) {
            if ($.agents[i] == agent_) return i;
        }
        revert NotAgent();
    }

    function isAgent(address agent_) public view override returns (bool) {
        return _getLeveragedTokenStorage().isAgent[agent_];
    }

    function agentCreatedAt(address agent_) public view override returns (uint256) {
        return _getLeveragedTokenStorage().agentCreatedAt[agent_];
    }

    function mintPaused() public view override returns (bool) {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        return $.mintPaused || $.globalStorage.allMintsPaused();
    }

    function pendingRedemptions() external view override returns (address[] memory) {
        return _getLeveragedTokenStorage().pendingRedemptions;
    }

    function mint(address to_, uint256 baseAmount_, uint256 minOut_)
        external
        override
        whenNotMintPaused
        returns (uint256)
    {
        if (to_ == address(0)) revert InvalidAddress();
        if (baseAmount_ == 0) revert InvalidAmount();
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        if (baseAmount_ < $.globalStorage.minTransactionSize()) revert BelowMinTransactionSize();
        _checkpoint();
        uint256 ltAmount_ = baseToLtAmount(baseAmount_);
        if (ltAmount_ < minOut_) revert SlippageExceeded();
        _baseAsset().safeTransferFrom(msg.sender, address(this), baseAmount_);
        _mint(to_, ltAmount_);
        emit Mint(msg.sender, to_, baseAmount_, ltAmount_);
        return ltAmount_;
    }

    function redeem(address to_, uint256 ltAmount_, uint256 minBaseAmount_) external override returns (uint256) {
        if (to_ == address(0)) revert InvalidAddress();
        if (ltAmount_ == 0) revert InvalidAmount();
        _checkpoint();
        uint256 baseAmount_ = ltToBaseAmount(ltAmount_);
        if (baseAmount_ > baseAssetBalance()) revert InsufficientBalance();
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        if (baseAmount_ < $.globalStorage.minTransactionSize()) revert BelowMinTransactionSize();
        uint256 redemptionFee_ = _redemptionFee(baseAmount_, false);
        _payRedemptionFee(redemptionFee_, msg.sender);
        uint256 afterFees_ = baseAmount_ - redemptionFee_;
        if (afterFees_ < minBaseAmount_) revert SlippageExceeded();
        _burn(msg.sender, ltAmount_);
        _baseAsset().safeTransfer(to_, afterFees_);
        emit Redeem(msg.sender, to_, ltAmount_, afterFees_);
        return afterFees_;
    }

    function prepareRedeem(uint256 ltAmount_) external override {
        if (ltAmount_ == 0) revert InvalidAmount();
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        if ($.userCredit[msg.sender] != 0) revert AlreadyRedeeming();
        _checkpoint();
        uint256 baseAmount_ = ltToBaseAmount(ltAmount_);
        if (baseAmount_ < $.globalStorage.minTransactionSize()) revert BelowMinTransactionSize();
        _transfer(msg.sender, address(this), ltAmount_);
        _addCredit(msg.sender, ltAmount_);
        emit PrepareRedeem(msg.sender, ltAmount_);
    }

    function executeRedemptions(address[] memory users_)
        external
        override
        onlyExecutors
        returns (ExecuteRedemptionData[] memory executeRedemptionData_)
    {
        _checkpoint();
        executeRedemptionData_ = new ExecuteRedemptionData[](users_.length);
        for (uint256 i = 0; i < users_.length; i++) {
            address user_ = users_[i];
            bool wasExecuted_ = _executeRedemption(user_);
            executeRedemptionData_[i] = ExecuteRedemptionData({user: user_, wasExecuted: wasExecuted_});
        }
    }

    function _executeRedemption(address user_) internal returns (bool) {
        if (user_ == address(0)) return false;
        uint256 ltAmount_ = userCredit(user_);
        if (ltAmount_ == 0) return false;
        if (balanceOf(address(this)) < ltAmount_) return false;
        uint256 baseAmount_ = ltToBaseAmount(ltAmount_);
        if (baseAssetBalance() < baseAmount_) return false;
        uint256 redemptionFee_ = _redemptionFee(baseAmount_, true);
        if (baseAmount_ < redemptionFee_) return false;
        uint256 afterFees_ = baseAmount_ - redemptionFee_;
        _removeCredit(user_, ltAmount_);
        _payRedemptionFee(redemptionFee_, user_);
        _burn(address(this), ltAmount_);
        _baseAsset().safeTransfer(user_, afterFees_);
        emit ExecuteRedeem(user_, ltAmount_, afterFees_);
        return true;
    }

    function cancelRedeem() external override {
        _checkpoint();
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        address user_ = msg.sender;
        uint256 credit_ = $.userCredit[user_];
        if (credit_ == 0) revert NotRedeeming();
        uint256 pendingRedemptionTimestamp_ = $.pendingRedemptionTimestamp[user_];
        uint256 timeElapsed_ = block.timestamp - pendingRedemptionTimestamp_;
        if (timeElapsed_ < _CANCEL_REDEMPTION_DELAY) revert CancelDelayNotElapsed();
        _removeCredit(user_, credit_);
        _transfer(address(this), user_, credit_);
        emit CancelRedeem(user_, credit_);
    }

    function setMintPaused(bool mintPaused_) external override onlyOwner {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        if (mintPaused_ == $.mintPaused) revert SameAsCurrent();
        $.mintPaused = mintPaused_;
        emit SetMintPaused(mintPaused_);
    }

    function bridgeToCore(uint256 amount_) external override onlyAgents {
        if (amount_ == 0) revert InvalidAmount();
        if (amount_ > baseAssetBalance()) revert InsufficientBalance();
        CoreWriterLib.bridgeToCore(address(_baseAsset()), amount_);
        _increaseBlockBridging(amount_);
        emit BridgeToCore(msg.sender, amount_);
    }

    function bridgeToEvm(uint256 amount_) external override onlyAgents {
        if (amount_ == 0) revert InvalidAmount();
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        uint256 spotUsdc_ = $.globalStorage.hyperliquidHandler().spotUsdc(address(this));
        if (amount_ > spotUsdc_) revert InsufficientBalance();
        CoreWriterLib.bridgeToEvm(address(_baseAsset()), amount_);
        emit BridgeToEvm(msg.sender, amount_);
    }

    function checkpoint(uint256 to_) external override onlyAgents {
        _checkpoint(to_);
    }

    function checkpoint() external override onlyAgents {
        _checkpoint();
    }

    function addAgent(address agent_) external override onlyOwner {
        if (agent_ == address(0)) revert InvalidAddress();
        uint8 slot_ = _getAvailableSlot();
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        IHyperliquidHandler hyperliquidHandler_ = $.globalStorage.hyperliquidHandler();
        if (!hyperliquidHandler_.coreUserExists(address(this))) revert LeveragedTokenNotActivated();
        if ($.agentCreatedAt[agent_] != 0) revert AlreadyCreated();
        $.agents[slot_] = agent_;
        $.isAgent[agent_] = true;
        $.agentCreatedAt[agent_] = block.timestamp;
        string memory agentName_ = _getAgentName(slot_);
        CoreWriterLib.addApiWallet(agent_, agentName_);
        emit AddAgent(slot_, agent_);
    }

    function removeAgent(address agent_) external override onlyOwner {
        if (agent_ == address(0)) revert InvalidAddress();
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        uint8 slot_ = getAgentSlot(agent_);
        delete $.agents[slot_];
        delete $.isAgent[agent_];
        string memory agentName_ = _getAgentName(slot_);
        CoreWriterLib.addApiWallet(address(0), agentName_);
        emit RemoveAgent(slot_, agent_);
    }

    function _getAvailableSlot() internal view returns (uint8) {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        for (uint8 i = 0; i < _AGENT_SLOTS; i++) {
            if ($.agents[i] == address(0)) return i;
        }
        revert NoAvailableSlot();
    }

    function _getAgentName(uint8 slot_) internal pure returns (string memory) {
        return string(abi.encodePacked("AGENT_", Strings.toString(slot_)));
    }

    function baseToLtAmount(uint256 baseAmount_) public view override returns (uint256) {
        uint256 scaled_ = baseAmount_.scaleFrom(_baseAsset().decimals());
        return scaled_.div(exchangeRate());
    }

    function ltToBaseAmount(uint256 ltAmount_) public view override returns (uint256) {
        uint256 converted_ = ltAmount_.mul(exchangeRate());
        return converted_.scaleTo(_baseAsset().decimals());
    }

    function exchangeRate() public view override returns (uint256) {
        if (totalSupply() == 0) return 1e18;
        return totalAssets().scaleFrom(_baseAsset().decimals()).div(totalSupply());
    }

    function totalAssets() public view override returns (uint256) {
        uint256 baseAssetBalance_ = baseAssetBalance() + _blockBridging();
        uint256 hyperliquidAssets_ = _hyperliquidUsdc();
        return baseAssetBalance_ + hyperliquidAssets_;
    }

    function hyperliquidNotional() public view override returns (uint256) {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        return $.globalStorage.hyperliquidHandler().notionalUsdc(address(this), $.perpDexIndex);
    }

    function baseAssetBalance() public view override returns (uint256) {
        return _baseAsset().balanceOf(address(this));
    }

    function _baseAsset() internal view returns (IERC20Metadata) {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        return IERC20Metadata($.globalStorage.baseAsset());
    }

    function _checkpoint() internal {
        _checkpoint(block.timestamp);
    }

    function _checkpoint(uint256 to_) internal {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        if ($.lastCheckpoint == 0) {
            $.lastCheckpoint = block.timestamp;
            return;
        }
        if (to_ > block.timestamp) to_ = block.timestamp;
        if ($.lastCheckpoint >= to_) return;
        uint256 timeElapsed_ = to_ - $.lastCheckpoint;
        uint256 percentOfYear_ = (timeElapsed_ * 1e18) / 365 days;
        uint256 streamingFee_ = $.globalStorage.streamingFee();
        uint256 totalAssets_ = totalAssets();
        uint256 annualFee_ = totalAssets_.mul(streamingFee_).mul($.targetLeverage);
        uint256 periodFee_ = annualFee_.mul(percentOfYear_);
        _payStreamingFee(periodFee_);
        if (periodFee_ == 0 && totalAssets_ > 0 && streamingFee_ > 0) return;
        $.lastCheckpoint = to_;
    }

    function _redemptionFee(uint256 baseAmount_, bool hasFlatFee_) internal view returns (uint256) {
        if (baseAmount_ == 0) return 0;
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        IGlobalStorage globalStorage_ = $.globalStorage;
        uint256 percentFee_ = baseAmount_.mul(globalStorage_.redemptionFee()).mul($.targetLeverage);
        if (!hasFlatFee_) return percentFee_;
        return percentFee_ + globalStorage_.executeRedemptionFee();
    }

    function _payStreamingFee(uint256 feeAmount_) internal {
        _payFees(feeAmount_);
    }

    function _payRedemptionFee(uint256 feeAmount_, address beneficiary_) internal {
        if (feeAmount_ == 0) return;
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        IReferrals referrals_ = $.globalStorage.referrals();
        _baseAsset().safeIncreaseAllowance(address(referrals_), feeAmount_);
        feeAmount_ -= referrals_.donateRebates(beneficiary_, feeAmount_);
        _baseAsset().forceApprove(address(referrals_), 0);
        _payFees(feeAmount_);
    }

    function _payFees(uint256 feeAmount_) internal {
        if (feeAmount_ == 0) return;
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        IGlobalStorage globalStorage_ = $.globalStorage;
        address treasury_ = globalStorage_.treasury();
        if (treasury_ == address(0)) revert InvalidAddress();
        uint256 treasuryFeeShare_ = globalStorage_.treasuryFeeShare();
        IFeeHandler feeHandler_ = globalStorage_.feeHandler();
        if (address(feeHandler_) == address(0) || !feeHandler_.enabled()) treasuryFeeShare_ = 1e18;
        uint256 treasuryAmount_ = feeAmount_.mul(treasuryFeeShare_);
        if (treasuryAmount_ > 0) {
            _baseAsset().safeTransfer(treasury_, treasuryAmount_);
            emit SendFeesToTreasury(treasuryAmount_);
        }
        uint256 feeHandlerAmount_ = feeAmount_ - treasuryAmount_;
        if (feeHandlerAmount_ == 0) return;
        _baseAsset().safeIncreaseAllowance(address(feeHandler_), feeHandlerAmount_);
        feeHandler_.handleFees(feeHandlerAmount_);
    }

    function _addCredit(address user_, uint256 amount_) internal {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        $.userCredit[user_] += amount_;
        $.credit += amount_;
        $.pendingRedemptions.push(user_);
        $.pendingRedemptionIndex[user_] = $.pendingRedemptions.length - 1;
        $.pendingRedemptionTimestamp[user_] = block.timestamp;
    }

    function _removeCredit(address user_, uint256 amount_) internal {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        $.userCredit[user_] -= amount_;
        $.credit -= amount_;
        uint256 pendingRedemptionIndex_ = $.pendingRedemptionIndex[user_];
        address lastUser_ = $.pendingRedemptions[$.pendingRedemptions.length - 1];
        $.pendingRedemptions[pendingRedemptionIndex_] = lastUser_;
        $.pendingRedemptionIndex[lastUser_] = pendingRedemptionIndex_;
        $.pendingRedemptions.pop();
        delete $.pendingRedemptionIndex[user_];
        delete $.pendingRedemptionTimestamp[user_];
    }

    function _hyperliquidUsdc() internal view returns (uint256) {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        IHyperliquidHandler hyperliquidHandler_ = $.globalStorage.hyperliquidHandler();
        uint256 spotUsdc_ = hyperliquidHandler_.spotUsdc(address(this));
        uint256 perpUsdc_ = hyperliquidHandler_.perpUsdc(address(this), $.perpDexIndex);
        return spotUsdc_ + perpUsdc_;
    }

    function _blockBridging() internal view returns (uint256) {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        return $.blockBridging[block.number];
    }

    function _increaseBlockBridging(uint256 amount_) internal {
        LeveragedTokenStorage storage $ = _getLeveragedTokenStorage();
        $.blockBridging[block.number] += amount_;
    }

    function _getPerpDexIndex(uint32 marketId_) internal pure returns (uint32) {
        if (marketId_ < _HIP_3_DEX_STRIDE) return 0;
        if (marketId_ < _HIP_3_BASE) revert InvalidMarketId();
        uint32 perpDexIndex_ = (marketId_ - _HIP_3_BASE) / _HIP_3_DEX_STRIDE;
        if (perpDexIndex_ == 0) revert InvalidMarketId();
        return perpDexIndex_;
    }
}
