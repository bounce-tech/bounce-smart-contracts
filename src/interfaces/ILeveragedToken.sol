// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ILeveragedToken is IERC20Metadata {
    error InvalidAddress();
    error InvalidAmount();
    error SlippageExceeded();
    error InsufficientBalance();
    error NotAgent();
    error BelowMinTransactionSize();
    error NotOwner();
    error SameAsCurrent();
    error AlreadyCreated();
    error MintPaused();
    error AlreadyRedeeming();
    error NotRedeeming();
    error CancelDelayNotElapsed();
    error NotExecutor();
    error LeveragedTokenNotActivated();
    error NoAvailableSlot();

    event Mint(address indexed minter, address indexed to, uint256 baseAmount, uint256 ltAmount);
    event Redeem(address indexed sender, address indexed to, uint256 ltAmount, uint256 baseAmount);
    event PrepareRedeem(address indexed sender, uint256 ltAmount);
    event ExecuteRedeem(address indexed user, uint256 ltAmount, uint256 baseAmount);
    event CancelRedeem(address indexed user, uint256 credit);
    event AddAgent(uint8 indexed slot, address indexed agent);
    event RemoveAgent(uint8 indexed slot, address indexed agent);
    event SetMintPaused(bool mintPaused);
    event SendFeesToTreasury(uint256 amount);
    event BridgeToCore(address indexed sender, uint256 amount);
    event BridgeToEvm(address indexed sender, uint256 amount);

    struct ExecuteRedemptionData {
        address user;
        bool wasExecuted;
    }

    function version() external view returns (string memory);

    function marketId() external view returns (uint32);

    function targetAsset() external view returns (string memory);

    function targetLeverage() external view returns (uint256);

    function isLong() external view returns (bool);

    function lastCheckpoint() external view returns (uint256);

    function baseToLtAmount(uint256 baseAmount_) external view returns (uint256);

    function ltToBaseAmount(uint256 ltAmount_) external view returns (uint256);

    function exchangeRate() external view returns (uint256);

    function baseAssetBalance() external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function userCredit(address user_) external view returns (uint256);

    function credit() external view returns (uint256);

    function agents() external view returns (address[3] memory);

    function isAgent(address agent_) external view returns (bool);

    function agentCreatedAt(address agent_) external view returns (uint256);

    function getAgentSlot(address agent_) external view returns (uint8);

    function mintPaused() external view returns (bool);

    function pendingRedemptions() external view returns (address[] memory);

    function setMintPaused(bool mintPaused_) external;

    function mint(address to_, uint256 baseAmount_, uint256 minOut_) external returns (uint256);

    function redeem(address to_, uint256 ltAmount_, uint256 minBaseAmount_) external returns (uint256);

    function prepareRedeem(uint256 ltAmount_) external;

    function executeRedemptions(address[] memory users_) external returns (ExecuteRedemptionData[] memory);

    function cancelRedeem() external;

    function bridgeToCore(uint256 amount_) external;

    function bridgeToEvm(uint256 amount_) external;

    function checkpoint(uint256 to_) external;

    function checkpoint() external;

    function addAgent(address agent_) external;

    function removeAgent(address agent_) external;
}
