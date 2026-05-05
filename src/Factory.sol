// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {PrecompileLib} from "@hyper-evm-lib/src/PrecompileLib.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ScaledNumber} from "./utils/ScaledNumber.sol";

import {IFactory} from "./interfaces/IFactory.sol";
import {Ownable} from "./Ownable.sol";
import {LeveragedTokenProxy} from "./LeveragedTokenProxy.sol";
import {LeveragedToken} from "./LeveragedToken.sol";
import {ILeveragedToken} from "./interfaces/ILeveragedToken.sol";

contract Factory is IFactory, Ownable, Initializable, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    using ScaledNumber for uint256;

    // keccak256(abi.encode(uint256(keccak256("factory.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant _FACTORY_STORAGE_LOCATION =
        0x45836df2c0305fc6ecac2759b292f84680adc1be9cc08ea3d5728270813bfc00;

    uint32 internal constant _HIP_3_BASE = 100_000;
    uint32 internal constant _HIP_3_DEX_STRIDE = 10_000;

    /// @custom:storage-location erc7201:factory.storage
    struct FactoryStorage {
        address[] lts;
        mapping(address => uint256) ltIndex;
        mapping(address => bool) ltExists;
        mapping(uint32 => mapping(uint256 => mapping(bool => address))) lt;
    }

    function _getFactoryStorage() internal pure returns (FactoryStorage storage $) {
        assembly {
            $.slot := _FACTORY_STORAGE_LOCATION
        }
    }

    constructor(address globalStorage_) Ownable(globalStorage_) {
        _disableInitializers();
    }

    function initialize() external initializer {
        __UUPSUpgradeable_init();
    }

    function createLt(uint32 marketId_, uint256 targetLeverage_, bool isLong_)
        external
        override
        onlyOwner
        returns (address)
    {
        if (marketId_ >= _HIP_3_BASE && marketId_ < _HIP_3_BASE + _HIP_3_DEX_STRIDE) revert InvalidMarketId();
        FactoryStorage storage $ = _getFactoryStorage();
        if ($.lt[marketId_][targetLeverage_][isLong_] != address(0)) revert AlreadyCreated();
        PrecompileLib.PerpAssetInfo memory perpAssetInfo_ = PrecompileLib.perpAssetInfo(_perpIndex(marketId_));
        _validateMaxLeverage(perpAssetInfo_, targetLeverage_);
        return _createLt(marketId_, targetLeverage_, isLong_, perpAssetInfo_.coin);
    }

    // NOTE: This function is temporary and will be removed once the migration
    // from the previous `Factory` deployment is complete. Benchmarks show that
    // a single call can migrate roughly 200 leveraged tokens while staying
    // under the HyperEVM big block gas limit. Our current catalog is well
    // below that threshold, so there are no gas concerns at this time.
    function importFromFactory(address oldFactory_) external override onlyOwner {
        if (oldFactory_ == address(0)) revert InvalidAddress();
        address[] memory oldLts_ = IFactory(oldFactory_).lts();
        for (uint256 i; i < oldLts_.length; i++) {
            _importLt(oldLts_[i]);
        }
    }

    function redeployLt(address ltAddress_) external override onlyOwner {
        ILeveragedToken lt_ = ILeveragedToken(ltAddress_);
        uint32 marketId_ = lt_.marketId();
        uint256 targetLeverage_ = lt_.targetLeverage();
        bool isLong_ = lt_.isLong();
        string memory targetAsset_ = lt_.targetAsset();
        _removeLt(ltAddress_);
        _validateMaxLeverage(PrecompileLib.perpAssetInfo(_perpIndex(marketId_)), targetLeverage_);
        _createLt(marketId_, targetLeverage_, isLong_, targetAsset_);
    }

    function deleteLt(address ltAddress_) external override onlyOwner {
        _removeLt(ltAddress_);
    }

    function lts() external view override returns (address[] memory) {
        return _getFactoryStorage().lts;
    }

    function ltExists(address ltAddress_) external view override returns (bool) {
        return _getFactoryStorage().ltExists[ltAddress_];
    }

    function lt(uint32 marketId_, uint256 targetLeverage_, bool isLong_) external view override returns (address) {
        return _getFactoryStorage().lt[marketId_][targetLeverage_][isLong_];
    }

    function globalStorage() external view override returns (address) {
        return address(_GLOBAL_STORAGE);
    }

    function _authorizeUpgrade(address newImplementation_) internal view override onlyOwner {
        if (IFactory(newImplementation_).globalStorage() != address(_GLOBAL_STORAGE)) {
            revert InvalidImplementation();
        }
    }

    function _removeLt(address ltAddress_) internal {
        FactoryStorage storage $ = _getFactoryStorage();
        if (!$.ltExists[ltAddress_]) revert NotLeveragedToken();
        ILeveragedToken lt_ = ILeveragedToken(ltAddress_);
        uint256 perpUsdc_ = _GLOBAL_STORAGE.hyperliquidHandler().perpUsdc(ltAddress_, lt_.perpDexIndex());
        if (perpUsdc_ > 0) revert StillHasMargin();
        uint32 marketId_ = lt_.marketId();
        uint256 targetLeverage_ = lt_.targetLeverage();
        bool isLong_ = lt_.isLong();
        uint256 ltIndex_ = $.ltIndex[ltAddress_];
        address lastLt_ = $.lts[$.lts.length - 1];
        $.lts[ltIndex_] = lastLt_;
        $.lts.pop();
        $.ltIndex[lastLt_] = ltIndex_;
        delete $.ltIndex[ltAddress_];
        delete $.ltExists[ltAddress_];
        delete $.lt[marketId_][targetLeverage_][isLong_];
        emit DeleteLeveragedToken(msg.sender, ltAddress_, marketId_, targetLeverage_, isLong_);
    }

    function _importLt(address ltAddress_) internal {
        if (ltAddress_ == address(0)) revert InvalidAddress();
        FactoryStorage storage $ = _getFactoryStorage();
        if ($.ltExists[ltAddress_]) revert AlreadyCreated();
        ILeveragedToken lt_ = ILeveragedToken(ltAddress_);
        uint32 marketId_ = lt_.marketId();
        uint256 targetLeverage_ = lt_.targetLeverage();
        bool isLong_ = lt_.isLong();
        if (targetLeverage_ == 0) revert NotLeveragedToken();
        if ($.lt[marketId_][targetLeverage_][isLong_] != address(0)) revert AlreadyCreated();
        $.lt[marketId_][targetLeverage_][isLong_] = ltAddress_;
        $.lts.push(ltAddress_);
        $.ltIndex[ltAddress_] = $.lts.length - 1;
        $.ltExists[ltAddress_] = true;
        emit ImportLeveragedToken(msg.sender, ltAddress_, marketId_, targetLeverage_, isLong_);
    }

    function _createLt(uint32 marketId_, uint256 targetLeverage_, bool isLong_, string memory targetAsset_)
        internal
        returns (address)
    {
        _validateLeverage(targetLeverage_);
        FactoryStorage storage $ = _getFactoryStorage();
        address ltAddress_ = address(new LeveragedTokenProxy(address(_GLOBAL_STORAGE)));
        LeveragedToken(ltAddress_)
            .initialize(
                address(_GLOBAL_STORAGE),
                marketId_,
                targetAsset_,
                targetLeverage_,
                isLong_,
                _name(targetAsset_, targetLeverage_, isLong_),
                _symbol(targetAsset_, targetLeverage_, isLong_)
            );
        uint256 initialMintAmount_ = _GLOBAL_STORAGE.minTransactionSize();
        IERC20 baseAsset_ = IERC20(_GLOBAL_STORAGE.baseAsset());
        baseAsset_.safeTransferFrom(msg.sender, address(this), initialMintAmount_);
        baseAsset_.approve(ltAddress_, initialMintAmount_);
        uint256 ltAmount_ = LeveragedToken(ltAddress_).mint(address(this), initialMintAmount_, 0);
        IERC20(ltAddress_).safeTransfer(address(0xdead), ltAmount_);
        $.lt[marketId_][targetLeverage_][isLong_] = ltAddress_;
        $.lts.push(ltAddress_);
        $.ltIndex[ltAddress_] = $.lts.length - 1;
        $.ltExists[ltAddress_] = true;
        emit CreateLeveragedToken(msg.sender, ltAddress_, marketId_, targetLeverage_, isLong_);
        return ltAddress_;
    }

    function _name(string memory targetAsset_, uint256 targetLeverage_, bool isLong_)
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                targetAsset_, " ", Strings.toString(targetLeverage_ / 1e18), "x ", isLong_ ? "Long" : "Short"
            )
        );
    }

    function _symbol(string memory targetAsset_, uint256 targetLeverage_, bool isLong_)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(targetAsset_, Strings.toString(targetLeverage_ / 1e18), isLong_ ? "L" : "S"));
    }

    function _validateLeverage(uint256 targetLeverage_) internal pure {
        if (targetLeverage_ < 1e18) revert InvalidLeverage();
        if (targetLeverage_ % 1e18 != 0) revert InvalidLeverage();
    }

    function _validateMaxLeverage(PrecompileLib.PerpAssetInfo memory perpAssetInfo_, uint256 targetLeverage_)
        internal
        pure
    {
        uint256 maxLeverage_ = uint256(perpAssetInfo_.maxLeverage).scaleFrom(0);
        if (targetLeverage_ > maxLeverage_) revert InvalidLeverage();
    }

    function _perpIndex(uint32 marketId_) internal pure returns (uint32) {
        return marketId_ >= _HIP_3_BASE ? marketId_ - _HIP_3_BASE : marketId_;
    }
}
