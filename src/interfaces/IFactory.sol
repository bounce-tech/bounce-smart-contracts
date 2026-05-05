// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFactory {
    error AlreadyCreated();
    error NotLeveragedToken();
    error InvalidLeverage();
    error StillHasMargin();
    error InvalidAddress();
    error InvalidImplementation();
    error InvalidMarketId();

    event CreateLeveragedToken(
        address indexed creator, address indexed token, uint32 indexed marketId, uint256 targetLeverage, bool isLong
    );

    event ImportLeveragedToken(
        address indexed importer, address indexed token, uint32 indexed marketId, uint256 targetLeverage, bool isLong
    );

    event DeleteLeveragedToken(
        address indexed deleter, address indexed token, uint32 indexed marketId, uint256 targetLeverage, bool isLong
    );

    function createLt(uint32 marketId_, uint256 targetLeverage_, bool isLong_) external returns (address);

    function importFromFactory(address oldFactory_) external;

    function redeployLt(address ltAddress_) external;

    function deleteLt(address ltAddress_) external;

    function lt(uint32 marketId_, uint256 targetLeverage_, bool isLong_) external view returns (address);

    function lts() external view returns (address[] memory);

    function ltExists(address ltAddress_) external view returns (bool);

    function globalStorage() external view returns (address);
}
