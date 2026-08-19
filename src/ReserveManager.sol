// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReserveTypes} from "./libraries/ReserveTypes.sol";

contract ReserveManager is Ownable {
    using ReserveTypes for ReserveTypes.Reserve;

    mapping(address => ReserveTypes.Reserve) private reserves;

    event ReserveConfigured(
        address indexed asset, uint256 collateralFactor, uint256 liquidationThreshold, uint256 liquidationBonus
    );

    event ReserveStatusUpdated(address indexed asset, bool active, bool borrowEnabled);

    constructor() Ownable(msg.sender) {}

    function configureReserve(
        address asset,
        uint8 decimals,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) external onlyOwner {
        require(asset != address(0), "Reserve: zero asset");
        require(collateralFactor <= 10_000, "Reserve: invalid collateral factor");
        require(liquidationThreshold <= 10_000, "Reserve: invalid liquidation threshold");
        require(liquidationThreshold >= collateralFactor, "Reserve: threshold below collateral");
        require(liquidationBonus <= 10_000, "Reserve: invalid liquidation bonus");

        ReserveTypes.Reserve storage reserve = reserves[asset];

        reserve.active = true;
        reserve.borrowEnabled = true;
        reserve.decimals = decimals;
        reserve.collateralFactor = collateralFactor;
        reserve.liquidationThreshold = liquidationThreshold;
        reserve.liquidationBonus = liquidationBonus;
        reserve.lastUpdateTimestamp = block.timestamp;

        emit ReserveConfigured(asset, collateralFactor, liquidationThreshold, liquidationBonus);
    }

    function setReserveStatus(address asset, bool active, bool borrowEnabled) external onlyOwner {
        ReserveTypes.Reserve storage reserve = reserves[asset];

        require(reserve.lastUpdateTimestamp != 0, "Reserve: not configured");

        reserve.active = active;
        reserve.borrowEnabled = borrowEnabled;

        emit ReserveStatusUpdated(asset, active, borrowEnabled);
    }

    function getDecimals(address asset) external view returns (uint8) {
        return reserves[asset].decimals;
    }

    function getReserve(address asset) external view returns (ReserveTypes.Reserve memory) {
        return reserves[asset];
    }

    function isActive(address asset) external view returns (bool) {
        return reserves[asset].active;
    }

    function isBorrowEnabled(address asset) external view returns (bool) {
        return reserves[asset].borrowEnabled;
    }

    function getCollateralFactor(address asset) external view returns (uint256) {
        return reserves[asset].collateralFactor;
    }

    function getLiquidationThreshold(address asset) external view returns (uint256) {
        return reserves[asset].liquidationThreshold;
    }

    function getLiquidationBonus(address asset) external view returns (uint256) {
        return reserves[asset].liquidationBonus;
    }
}
