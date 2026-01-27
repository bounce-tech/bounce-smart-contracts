// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {PrecompileLib} from "@hyper-evm-lib/src/PrecompileLib.sol";
import {ScaledNumber} from "./utils/ScaledNumber.sol";

import {IFactory} from "./interfaces/IFactory.sol";
import {Ownable} from "./Ownable.sol";
import {LeveragedTokenProxy} from "./LeveragedTokenProxy.sol";
import {LeveragedToken} from "./LeveragedToken.sol";
import {ILeveragedToken} from "./interfaces/ILeveragedToken.sol";

contract Factory is IFactory, Ownable {
    using SafeERC20 for IERC20;
    using ScaledNumber for uint256;

    address[] internal _lts;
    mapping(address => uint256) internal _ltIndex;

    mapping(address => bool) public override ltExists;
    mapping(uint32 => mapping(uint256 => mapping(bool => address))) public override lt;

    constructor(address globalStorage_) Ownable(globalStorage_) {}

    function createLt(uint32 marketId_, uint256 targetLeverage_, bool isLong_) external onlyOwner returns (address) {
        if (lt[marketId_][targetLeverage_][isLong_] != address(0)) revert AlreadyCreated();
        return _createLt(marketId_, targetLeverage_, isLong_);
    }

    function redeployLt(address ltAddress_) external onlyOwner {
        ILeveragedToken lt_ = ILeveragedToken(ltAddress_);
        uint32 marketId_ = lt_.marketId();
        uint256 targetLeverage_ = lt_.targetLeverage();
        bool isLong_ = lt_.isLong();
        if (!ltExists[ltAddress_]) revert NotLeveragedToken();
        uint256 marginUsed_ = _GLOBAL_STORAGE.hyperliquidHandler().marginUsedUsdc(ltAddress_);
        if (marginUsed_ > 0) revert StillHasMargin();
        uint256 ltIndex_ = _ltIndex[ltAddress_];
        address lastLt_ = _lts[_lts.length - 1];
        _lts[ltIndex_] = lastLt_;
        _lts.pop();
        _ltIndex[lastLt_] = ltIndex_;
        delete _ltIndex[ltAddress_];
        delete ltExists[ltAddress_];
        _createLt(marketId_, targetLeverage_, isLong_);
    }

    function lts() external view override returns (address[] memory) {
        return _lts;
    }

    function _createLt(uint32 marketId_, uint256 targetLeverage_, bool isLong_) internal returns (address) {
        _validateLeverage(marketId_, targetLeverage_);
        address lt_ = address(new LeveragedTokenProxy(address(_GLOBAL_STORAGE)));
        string memory targetAsset_ = _targetAsset(marketId_);
        LeveragedToken(lt_).initialize(
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
        baseAsset_.approve(lt_, initialMintAmount_);
        uint256 ltAmount_ = LeveragedToken(lt_).mint(address(this), initialMintAmount_, 0);
        IERC20(lt_).safeTransfer(address(0xdead), ltAmount_);
        lt[marketId_][targetLeverage_][isLong_] = lt_;
        _lts.push(lt_);
        _ltIndex[lt_] = _lts.length - 1;
        ltExists[lt_] = true;
        emit CreateLeveragedToken(msg.sender, lt_, marketId_, targetLeverage_, isLong_);
        return lt_;
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

    function _targetAsset(uint32 marketId_) internal view returns (string memory) {
        return PrecompileLib.perpAssetInfo(marketId_).coin;
    }

    function _validateLeverage(uint32 marketId_, uint256 targetLeverage_) internal view {
        PrecompileLib.PerpAssetInfo memory perpAssetInfo_ = PrecompileLib.perpAssetInfo(marketId_);
        uint256 maxLeverage_ = uint256(perpAssetInfo_.maxLeverage).scaleFrom(0);
        if (targetLeverage_ > maxLeverage_) revert InvalidLeverage();
        if (targetLeverage_ < 1e18) revert InvalidLeverage();
        if (targetLeverage_ % 1e18 != 0) revert InvalidLeverage();
    }
}
