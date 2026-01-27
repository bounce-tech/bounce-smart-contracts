// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFactory {
    error AlreadyCreated();
    error NotLeveragedToken();
    error InvalidLeverage();
    error StillHasMargin();

    event CreateLeveragedToken(
        address indexed creator, address indexed token, uint32 indexed marketId, uint256 targetLeverage, bool isLong
    );

    function createLt(uint32 marketId_, uint256 targetLeverage_, bool isLong_) external returns (address);

    function lt(uint32 marketId_, uint256 targetLeverage_, bool isLong_) external view returns (address);

    function lts() external view returns (address[] memory);

    function ltExists(address ltAddress_) external view returns (bool);
}
