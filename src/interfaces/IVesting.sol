// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IVesting {
    error InvalidAmount();
    error InvalidAddress();
    error InvalidVestingDuration();
    error VestingAlreadyExists();
    error NothingToClaim();
    error NotAuthorised();
    error NoVesting();
    error VestingRevoked();
    error TransferNotPrepared();
    error TransferAlreadyPrepared();
    error TransferDelayNotElapsed();

    event CreateVesting(address indexed user, uint256 amount);
    event RevokeVesting(address indexed user, address indexed redirectAddress);
    event TransferVesting(address indexed from, address indexed to, uint256 amount);
    event ClaimVested(address indexed sender, address indexed from, address indexed to, uint256 amount);
    event SetVestingDelegate(address indexed sender, address indexed delegate, bool isDelegate);
    event PrepareTransfer(address indexed from, address indexed to, uint256 prepareTime);
    event CancelTransfer(address indexed from);

    struct Vesting {
        uint256 start;
        uint256 amount;
        uint256 revokedAt;
    }

    struct VestingData {
        uint256 start;
        uint256 end;
        uint256 amount;
        uint256 vested;
        uint256 claimed;
        uint256 claimable;
        uint256 revokedAt;
    }

    struct TransferRequest {
        address to;
        uint256 prepareTime;
    }

    function vestingDuration() external view returns (uint256);

    function data(address user_) external view returns (VestingData memory);

    function isDelegate(address for_, address delegate_) external view returns (bool);

    function prepareTransfer(address to_) external;

    function executeTransfer(address from_) external;

    function cancelTransfer() external;

    function revoke(address user_, address redirectAddress_) external;

    function create(address user_, uint256 amount_) external;

    function claim(address for_, address to_) external;

    function setDelegate(address delegate_, bool isDelegate_) external;
}
