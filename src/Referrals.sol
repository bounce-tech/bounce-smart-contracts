// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {Ownable} from "./Ownable.sol";

import {ScaledNumber} from "./utils/ScaledNumber.sol";

import {IReferrals} from "./interfaces/IReferrals.sol";
import {IGlobalStorage} from "./interfaces/IGlobalStorage.sol";

contract Referrals is IReferrals, Ownable {
    using ScaledNumber for uint256;
    using SafeERC20 for IERC20;

    IERC20 internal immutable _BASE_ASSET;

    mapping(address => string) internal _referrerCodes;
    mapping(string => address) internal _codeReferrers;
    mapping(address => address) internal _refereeReferrers;
    mapping(address => uint256) internal _rebates;

    constructor(address globalStorate_) Ownable(globalStorate_) {
        _BASE_ASSET = IERC20(_GLOBAL_STORAGE.baseAsset());
    }

    function getReferrerFromCode(string calldata referralCode_) external view override returns (address) {
        return _codeReferrers[referralCode_];
    }

    function getReferrerFromUser(address user_) external view override returns (address) {
        return _refereeReferrers[user_];
    }

    function getCodeFromUser(address user_) external view override returns (string memory) {
        return _referrerCodes[_refereeReferrers[user_]];
    }

    function getCodeFromReferrer(address referrer_) external view override returns (string memory) {
        return _referrerCodes[referrer_];
    }

    function isReferrer(address referrer_) public view override returns (bool) {
        return bytes(_referrerCodes[referrer_]).length > 0;
    }

    function isJoined(address user_) external view override returns (bool) {
        return _refereeReferrers[user_] != address(0);
    }

    function isValidCode(string calldata referralCode_) public view returns (bool) {
        return _codeReferrers[referralCode_] != address(0);
    }

    function getRebate(address user_) external view override returns (uint256) {
        return _rebates[user_];
    }

    function donateRebates(address user_, uint256 feeAmount_) external override returns (uint256) {
        address referrer_ = _refereeReferrers[user_];
        if (referrer_ == address(0)) return 0;
        if (!isReferrer(referrer_)) return 0;
        IGlobalStorage gs_ = _GLOBAL_STORAGE;
        uint256 referrerRebate_ = feeAmount_.mul(gs_.referrerRebate());
        uint256 refereeRebate_ = feeAmount_.mul(gs_.refereeRebate());
        uint256 totalRebate_ = referrerRebate_ + refereeRebate_;
        _BASE_ASSET.safeTransferFrom(msg.sender, address(this), totalRebate_);
        _rebates[referrer_] += referrerRebate_;
        _rebates[user_] += refereeRebate_;
        emit DonateRebate(msg.sender, user_, feeAmount_, referrerRebate_, refereeRebate_);
        return totalRebate_;
    }

    function claimRebates(address user_) external override {
        uint256 rebate_ = _rebates[user_];
        if (rebate_ == 0) revert NoRebate();
        delete _rebates[user_];
        _BASE_ASSET.safeTransfer(user_, rebate_);
        emit ClaimRebate(msg.sender, user_, rebate_);
    }

    function addReferrer(string calldata referralCode_, address referrer_) external override onlyOwner {
        if (referrer_ == address(0)) revert InvalidReferrer();
        if (bytes(referralCode_).length == 0) revert InvalidReferralCode();
        if (isReferrer(referrer_)) revert UserAlreadyReferrer();
        if (isValidCode(referralCode_)) revert CodeAlreadyExists();
        _referrerCodes[referrer_] = referralCode_;
        _codeReferrers[referralCode_] = referrer_;
        emit AddReferrer(referrer_, referralCode_);
    }

    function removeReferrer(string calldata referralCode_) external override onlyOwner {
        if (bytes(referralCode_).length == 0) revert InvalidReferralCode();
        address referrer_ = _codeReferrers[referralCode_];
        if (referrer_ == address(0)) revert CodeDoesNotExist();
        delete _referrerCodes[referrer_];
        delete _codeReferrers[referralCode_];
        emit RemoveReferrer(referrer_, referralCode_);
    }

    function joinWithReferral(string calldata referralCode_) external override {
        if (bytes(referralCode_).length == 0) revert InvalidReferralCode();
        bool hasJoined_ = _refereeReferrers[msg.sender] != address(0);
        if (hasJoined_ && isReferrer(_refereeReferrers[msg.sender])) revert UserAlreadyJoined();
        if (!isValidCode(referralCode_)) revert InvalidReferralCode();
        _refereeReferrers[msg.sender] = _codeReferrers[referralCode_];
        emit JoinWithReferral(msg.sender, _codeReferrers[referralCode_], referralCode_);
    }
}
