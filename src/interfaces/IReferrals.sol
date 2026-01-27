// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IReferrals {
    error NoRebate();
    error InvalidReferralCode();
    error InvalidReferrer();
    error UserAlreadyReferrer();
    error CodeAlreadyExists();
    error CodeDoesNotExist();
    error UserAlreadyJoined();

    event DonateRebate(
        address indexed sender, address indexed to, uint256 feeAmount, uint256 referrerRebate, uint256 refereeRebate
    );
    event ClaimRebate(address indexed sender, address indexed to, uint256 rebate);
    event AddReferrer(address indexed referrer, string referralCode);
    event RemoveReferrer(address indexed referrer, string referralCode);
    event JoinWithReferral(address indexed referee, address indexed referrer, string referralCode);

    function getReferrerFromCode(string calldata referralCode_) external view returns (address);

    function getCodeFromReferrer(address referrer_) external view returns (string memory);

    function getReferrerFromUser(address user_) external view returns (address);

    function getCodeFromUser(address user_) external view returns (string memory);

    function isReferrer(address referrer_) external view returns (bool);

    function isJoined(address user_) external view returns (bool);

    function isValidCode(string calldata referralCode_) external view returns (bool);

    function getRebate(address user_) external view returns (uint256);

    function donateRebates(address user_, uint256 feeAmount_) external returns (uint256);

    function joinWithReferral(string calldata referralCode_) external;

    function claimRebates(address user_) external;

    function addReferrer(string calldata referralCode_, address referrer_) external;

    function removeReferrer(string calldata referralCode_) external;
}
