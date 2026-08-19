// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library ReserveTypes {
    struct Reserve {
        bool active;
        bool borrowEnabled;

        uint8 decimals;

        uint256 totalSupplied;
        uint256 totalBorrowed;

        uint256 collateralFactor;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;

        uint256 lastUpdateTimestamp;
    }
}
