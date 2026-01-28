// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IHypeBalanceHelper {
    struct UserBalance {
        address user;
        uint256 balance;
    }

    function getHypeBalances(address[] calldata users_) external view returns (UserBalance[] memory);
}

contract HypeBalanceHelper is IHypeBalanceHelper {
    function getHypeBalances(address[] calldata users_) external view override returns (UserBalance[] memory) {
        uint256 userCount_ = users_.length;
        UserBalance[] memory userBalances_ = new UserBalance[](userCount_);
        for (uint256 i = 0; i < userCount_; i++) {
            address user_ = users_[i];
            userBalances_[i] = UserBalance(user_, user_.balance);
        }
        return userBalances_;
    }
}
