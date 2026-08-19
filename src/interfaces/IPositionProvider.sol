// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPositionProvider {
    function getUserCollateral(address user, address asset) external view returns (uint256);

    function getUserDebt(address user, address asset) external view returns (uint256);

    function getSupportedAssets() external view returns (address[] memory);
}
