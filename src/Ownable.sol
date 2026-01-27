// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IOwnable} from "./interfaces/IOwnable.sol";
import {IGlobalStorage} from "./interfaces/IGlobalStorage.sol";

contract Ownable is IOwnable {
    IGlobalStorage internal immutable _GLOBAL_STORAGE;

    constructor(address globalStorage_) {
        _GLOBAL_STORAGE = IGlobalStorage(globalStorage_);
    }

    modifier onlyOwner() {
        if (msg.sender != _GLOBAL_STORAGE.owner()) revert NotOwner();
        _;
    }
}
