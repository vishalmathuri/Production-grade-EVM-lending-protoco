// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILendingPool {
    function supply(address asset, uint256 amount) external;

    function withdraw(address asset, uint256 amount) external;

    function borrow(address asset, uint256 amount) external;

    function repay(address asset, uint256 amount) external;

    function getUserCollateral(address user, address asset) external view returns (uint256);

    function getUserDebt(address user, address asset) external view returns (uint256);

    function getHealthFactor(address user) external view returns (uint256);
}
