// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IInterestRateModel {
    function getBorrowRate(uint256 totalSupplied, uint256 totalBorrowed) external view returns (uint256);

    function getSupplyRate(uint256 totalSupplied, uint256 totalBorrowed) external view returns (uint256);
}
