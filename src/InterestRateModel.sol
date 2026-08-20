// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";

contract InterestRateModel is IInterestRateModel {
    uint256 public constant BASE_BORROW_RATE = 200;
    uint256 public constant MAX_BORROW_RATE = 1200;
    uint256 public constant MAX_SUPPLY_RATE = 1200;

    function getBorrowRate(uint256 totalSupplied, uint256 totalBorrowed) external pure override returns (uint256) {
        if (totalSupplied == 0) {
            return BASE_BORROW_RATE;
        }

        uint256 utilization = (totalBorrowed * 10_000) / totalSupplied;

        if (utilization >= 10_000) {
            return MAX_BORROW_RATE;
        }

        uint256 variableRate = ((MAX_BORROW_RATE - BASE_BORROW_RATE) * utilization) / 10_000;

        return BASE_BORROW_RATE + variableRate;
    }

    function getSupplyRate(uint256 totalSupplied, uint256 totalBorrowed) external pure override returns (uint256) {
        if (totalSupplied == 0) {
            return 0;
        }

        uint256 utilization = (totalBorrowed * 10_000) / totalSupplied;

        if (utilization >= 10_000) {
            return MAX_SUPPLY_RATE;
        }

        if (utilization <= 5_000) {
            return (350 * utilization) / 5_000;
        }

        return 350 + ((MAX_SUPPLY_RATE - 350) * (utilization - 5_000)) / 5_000;
    }
}
