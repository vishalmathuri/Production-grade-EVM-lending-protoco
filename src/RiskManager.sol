// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRiskManager} from "./interfaces/IRiskManager.sol";
import {IPositionProvider} from "./interfaces/IPositionProvider.sol";
import {ReserveManager} from "./ReserveManager.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

contract RiskManager is IRiskManager {
    uint256 public constant BPS = 10_000;
    uint256 public constant WAD = 1e18;

    ReserveManager public immutable reserveManager;
    IPriceOracle public immutable priceOracle;
    IPositionProvider public immutable positionProvider;

    constructor(address reserveManager_, address priceOracle_, address positionProvider_) {
        require(reserveManager_ != address(0), "RiskManager: zero reserve manager");

        require(priceOracle_ != address(0), "RiskManager: zero oracle");

        require(positionProvider_ != address(0), "RiskManager: zero position provider");

        reserveManager = ReserveManager(reserveManager_);
        priceOracle = IPriceOracle(priceOracle_);
        positionProvider = IPositionProvider(positionProvider_);
    }

    function getCollateralFactor(address asset) external view returns (uint256) {
        return reserveManager.getCollateralFactor(asset);
    }

    function getLiquidationThreshold(address asset) external view returns (uint256) {
        return reserveManager.getLiquidationThreshold(asset);
    }

    function getLiquidationBonus(address asset) external view returns (uint256) {
        return reserveManager.getLiquidationBonus(asset);
    }

    function calculateHealthFactor(address user) external view returns (uint256) {
        (uint256 collateralValue, uint256 debtValue) = _getAccountValues(user);

        if (debtValue == 0) {
            return type(uint256).max;
        }

        return (collateralValue * WAD) / debtValue;
    }

    function canBorrow(address user, address asset, uint256 amount) external view returns (bool) {
        if (amount == 0) {
            return false;
        }

        if (!reserveManager.isActive(asset)) {
            return false;
        }

        address[] memory assets = positionProvider.getSupportedAssets();

        uint256 borrowingCapacity;
        uint256 debtValue;

        for (uint256 i = 0; i < assets.length; i++) {
            address collateralAsset = assets[i];

            uint256 collateral = positionProvider.getUserCollateral(user, collateralAsset);

            uint256 debt = positionProvider.getUserDebt(user, collateralAsset);

            if (collateral > 0) {
                uint256 collateralValue = _getAssetValue(collateralAsset, collateral);
                uint256 collateralFactor = reserveManager.getCollateralFactor(collateralAsset);
                borrowingCapacity += (collateralValue * collateralFactor) / BPS;
            }

            if (debt > 0) {
                debtValue += _getAssetValue(collateralAsset, debt);
            }
        }
        uint256 newBorrowValue = _getAssetValue(asset, amount);
        return debtValue + newBorrowValue <= borrowingCapacity;
    }

    function canLiquidate(address user) external view returns (bool) {
        uint256 healthFactor = this.calculateHealthFactor(user);

        return healthFactor < WAD;
    }

    function _getAccountValues(address user) internal view returns (uint256 collateralValue, uint256 debtValue) {
        address[] memory assets = positionProvider.getSupportedAssets();

        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];

            uint256 collateral = positionProvider.getUserCollateral(user, asset);

            uint256 debt = positionProvider.getUserDebt(user, asset);

            if (collateral > 0) {
                collateralValue += _getAssetValue(asset, collateral);
            }

            if (debt > 0) {
                debtValue += _getAssetValue(asset, debt);
            }
        }
    }

    function _getAssetValue(address asset, uint256 amount) internal view returns (uint256) {
        uint256 price = priceOracle.getPrice(asset);
        uint8 priceDecimals = priceOracle.getPriceDecimals(asset);
        uint8 tokenDecimals = reserveManager.getDecimals(asset);
        uint256 normalizedAmount;
        if (tokenDecimals < 18) {
            normalizedAmount = amount * 10 ** (18 - tokenDecimals);
        } else if (tokenDecimals > 18) {
            normalizedAmount = amount / 10 ** (tokenDecimals - 18);
        } else {
            normalizedAmount = amount;
        }

        if (priceDecimals < 18) {
            price *= 10 ** (18 - priceDecimals);
        } else if (priceDecimals > 18) {
            price /= 10 ** (priceDecimals - 18);
        }

        return (normalizedAmount * price) / 1e18;
    }
}
