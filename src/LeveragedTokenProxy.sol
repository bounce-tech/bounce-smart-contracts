// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Proxy} from "openzeppelin-contracts/contracts/proxy/Proxy.sol";

import {IGlobalStorage} from "./interfaces/IGlobalStorage.sol";

contract LeveragedTokenProxy is Proxy {
    IGlobalStorage internal immutable _GLOBAL_STORAGE;

    constructor(address globalStorage_) {
        _GLOBAL_STORAGE = IGlobalStorage(globalStorage_);
    }

    function _implementation() internal view virtual override returns (address) {
        return _GLOBAL_STORAGE.ltImplementation();
    }
}
