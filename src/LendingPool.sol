// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRiskManager} from "./interfaces/IRiskManager.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPositionProvider} from "./interfaces/IPositionProvider.sol";
import {UserTypes} from "./libraries/UserTypes.sol";
import {ReserveManager} from "./ReserveManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LendingPool is ILendingPool, IPositionProvider {
    using UserTypes for UserTypes.Position;
    using SafeERC20 for IERC20;

    IRiskManager public riskManager;

    ReserveManager public immutable reserveManager;

    mapping(address => mapping(address => UserTypes.Position)) private positions;

    mapping(address => uint256) public totalSupplied;

    mapping(address => uint256) public totalBorrowed;

    address[] private supportedAssets;

    mapping(address => bool) private assetRegistered;

    event Supplied(address indexed user, address indexed asset, uint256 amount);

    event Withdrawn(address indexed user, address indexed asset, uint256 amount);

    //constructor(address reserveManager_, address riskManager_) {
    constructor(address reserveManager_) {
        require(reserveManager_ != address(0), "LendingPool: zero reserve manager");
        //require(riskManager_ != address(0), "LendingPool: zero risk manager");
        reserveManager = ReserveManager(reserveManager_);
        //riskManager = IRiskManager(riskManager_);
    }

    function supply(address asset, uint256 amount) external override {
        require(amount > 0, "LendingPool: zero amount");

        require(reserveManager.isActive(asset), "LendingPool: inactive reserve");

        _registerAsset(asset);

        IERC20 token = IERC20(asset);

        bool success = token.transferFrom(msg.sender, address(this), amount);

        require(success, "LendingPool: transfer failed");

        positions[msg.sender][asset].supplied += amount;

        totalSupplied[asset] += amount;

        emit Supplied(msg.sender, asset, amount);
    }

    function withdraw(address asset, uint256 amount) external override {
        require(amount > 0, "LendingPool: zero amount");

        require(reserveManager.isActive(asset), "LendingPool: inactive reserve");

        UserTypes.Position storage position = positions[msg.sender][asset];

        require(position.supplied >= amount, "LendingPool: insufficient balance");

        require(IERC20(asset).balanceOf(address(this)) >= amount, "LendingPool: insufficient liquidity");

        position.supplied -= amount;

        totalSupplied[asset] -= amount;

        bool success = IERC20(asset).transfer(msg.sender, amount);

        require(success, "LendingPool: transfer failed");

        emit Withdrawn(msg.sender, asset, amount);
    }

    function getUserCollateral(address user, address asset)
        external
        view
        override(ILendingPool, IPositionProvider)
        returns (uint256)
    {
        return positions[user][asset].supplied;
    }

    function getUserDebt(address user, address asset)
        external
        view
        override(ILendingPool, IPositionProvider)
        returns (uint256)
    {
        return positions[user][asset].borrowed;
    }

    function getHealthFactor(address) external pure override returns (uint256) {
        // RiskManager will be connected later.
        return type(uint256).max;
    }

    function borrow(address asset, uint256 amount) external override {
        require(amount > 0, "LendingPool: zero borrow");
        require(reserveManager.isActive(asset), "LendingPool: inactive reserve");
        require(address(riskManager) != address(0), "LendingPool: risk manager not set");
        require(riskManager.canBorrow(msg.sender, asset, amount), "LendingPool: borrow not allowed");
        require(IERC20(asset).balanceOf(address(this)) >= amount, "LendingPool: insufficient liquidity");
        positions[msg.sender][asset].borrowed += amount;
        totalBorrowed[asset] += amount;
        IERC20(asset).safeTransfer(msg.sender, amount);
    }

    function repay(address asset, uint256 amount) external override {
        require(amount > 0, "LendingPool: zero repay");
        uint256 borrowed = positions[msg.sender][asset].borrowed;
        require(borrowed > 0, "LendingPool: no debt");
        uint256 repayAmount = amount > borrowed ? borrowed : amount;
        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);
        positions[msg.sender][asset].borrowed -= repayAmount;
        totalBorrowed[asset] -= repayAmount;
    }

    function _registerAsset(address asset) internal {
        if (!assetRegistered[asset]) {
            assetRegistered[asset] = true;
            supportedAssets.push(asset);
        }
    }

    function getSupportedAssets() external view override returns (address[] memory) {
        return supportedAssets;
    }

    function setRiskManager(address _riskManager) external {
        require(_riskManager != address(0), "LendingPool: zero risk manager");
        require(address(riskManager) == address(0), "LendingPool: risk manager already set");
        riskManager = IRiskManager(_riskManager);
    }

    function liquidate(address user, address debtAsset, address collateralAsset, uint256 debtAmount) external override {
        require(user != address(0), "LendingPool: zero user");
        require(debtAmount > 0, "LendingPool: zero debt amount");

        require(reserveManager.isActive(debtAsset), "LendingPool: inactive debt reserve");

        require(reserveManager.isActive(collateralAsset), "LendingPool: inactive collateral reserve");

        require(address(riskManager) != address(0), "LendingPool: risk manager not set");

        require(riskManager.canLiquidate(user), "LendingPool: position is healthy");

        UserTypes.Position storage userPosition = positions[user][collateralAsset];

        require(userPosition.supplied > 0, "LendingPool: no collateral");

        uint256 userDebt = positions[user][debtAsset].borrowed;

        require(userDebt > 0, "LendingPool: no debt");

        uint256 actualDebt = debtAmount > userDebt ? userDebt : debtAmount;

        uint256 liquidationBonus = reserveManager.getLiquidationBonus(collateralAsset);

        uint256 collateralAmount = actualDebt + (actualDebt * liquidationBonus) / 10_000;

        require(userPosition.supplied >= collateralAmount, "LendingPool: insufficient collateral");

        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), actualDebt);

        positions[user][debtAsset].borrowed -= actualDebt;
        totalBorrowed[debtAsset] -= actualDebt;

        userPosition.supplied -= collateralAmount;
        totalSupplied[collateralAsset] -= collateralAmount;

        IERC20(collateralAsset).safeTransfer(msg.sender, collateralAmount);
    }
}
