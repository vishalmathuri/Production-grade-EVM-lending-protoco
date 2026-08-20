// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IRiskManager} from "./interfaces/IRiskManager.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPositionProvider} from "./interfaces/IPositionProvider.sol";
import {UserTypes} from "./libraries/UserTypes.sol";
import {ReserveManager} from "./ReserveManager.sol";

contract LendingPool is ILendingPool, IPositionProvider, Ownable {
    using SafeERC20 for IERC20;
    using UserTypes for UserTypes.Position;

    IRiskManager public riskManager;

    ReserveManager public immutable reserveManager;

    mapping(address => mapping(address => UserTypes.Position)) private positions;

    mapping(address => uint256) public totalSupplied;

    mapping(address => uint256) public totalBorrowed;

    address[] private supportedAssets;

    mapping(address => bool) private assetRegistered;

    event Supplied(address indexed user, address indexed asset, uint256 amount);

    event Withdrawn(address indexed user, address indexed asset, uint256 amount);

    event Borrowed(address indexed user, address indexed asset, uint256 amount);

    event Repaid(address indexed user, address indexed asset, uint256 amount);

    event Liquidated(
        address indexed liquidator,
        address indexed user,
        address indexed debtAsset,
        address collateralAsset,
        uint256 debtAmount,
        uint256 collateralAmount
    );

    constructor(address reserveManager_) Ownable(msg.sender) {
        require(reserveManager_ != address(0), "LendingPool: zero reserve manager");

        reserveManager = ReserveManager(reserveManager_);
    }

    function supply(address asset, uint256 amount) external override {
        require(amount > 0, "LendingPool: zero amount");
        require(reserveManager.isActive(asset), "LendingPool: inactive reserve");

        _registerAsset(asset);

        IERC20 token = IERC20(asset);

        token.safeTransferFrom(msg.sender, address(this), amount);

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

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, asset, amount);
    }

    function borrow(address asset, uint256 amount) external override {
        require(amount > 0, "LendingPool: zero borrow");

        require(reserveManager.isActive(asset), "LendingPool: inactive reserve");

        require(address(riskManager) != address(0), "LendingPool: risk manager not set");

        require(riskManager.canBorrow(msg.sender, asset, amount), "LendingPool: borrow not allowed");

        require(IERC20(asset).balanceOf(address(this)) >= amount, "LendingPool: insufficient liquidity");

        _registerAsset(asset);

        positions[msg.sender][asset].borrowed += amount;

        totalBorrowed[asset] += amount;

        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, asset, amount);
    }

    function repay(address asset, uint256 amount) external override {
        require(amount > 0, "LendingPool: zero repay");

        uint256 debt = positions[msg.sender][asset].borrowed;

        require(debt > 0, "LendingPool: no debt");

        uint256 repayAmount = amount > debt ? debt : amount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);

        positions[msg.sender][asset].borrowed -= repayAmount;

        totalBorrowed[asset] -= repayAmount;

        emit Repaid(msg.sender, asset, repayAmount);
    }

    function liquidate(address user, address debtAsset, address collateralAsset, uint256 debtAmount) external override {
        require(user != address(0), "LendingPool: zero user");

        require(debtAmount > 0, "LendingPool: zero liquidation amount");

        require(address(riskManager) != address(0), "LendingPool: risk manager not set");

        require(riskManager.canLiquidate(user), "LendingPool: position healthy");

        UserTypes.Position storage position = positions[user][debtAsset];

        require(position.borrowed > 0, "LendingPool: no debt");

        require(debtAmount <= position.borrowed, "LendingPool: liquidation exceeds debt");

        uint256 collateralAmount = riskManager.calculateLiquidationCollateral(debtAsset, collateralAsset, debtAmount);

        require(collateralAmount > 0, "LendingPool: zero collateral");

        require(positions[user][collateralAsset].supplied >= collateralAmount, "LendingPool: insufficient collateral");

        require(
            IERC20(collateralAsset).balanceOf(address(this)) >= collateralAmount, "LendingPool: insufficient liquidity"
        );

        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), debtAmount);

        position.borrowed -= debtAmount;

        totalBorrowed[debtAsset] -= debtAmount;

        positions[user][collateralAsset].supplied -= collateralAmount;

        totalSupplied[collateralAsset] -= collateralAmount;

        IERC20(collateralAsset).safeTransfer(msg.sender, collateralAmount);

        emit Liquidated(msg.sender, user, debtAsset, collateralAsset, debtAmount, collateralAmount);
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

    function getHealthFactor(address user) external view override returns (uint256) {
        require(address(riskManager) != address(0), "LendingPool: risk manager not set");

        return riskManager.calculateHealthFactor(user);
    }

    function setRiskManager(address riskManager_) external onlyOwner {
        require(riskManager_ != address(0), "LendingPool: zero risk manager");

        riskManager = IRiskManager(riskManager_);
    }

    function getSupportedAssets() external view override returns (address[] memory) {
        return supportedAssets;
    }

    function _registerAsset(address asset) internal {
        if (!assetRegistered[asset]) {
            assetRegistered[asset] = true;
            supportedAssets.push(asset);
        }
    }
}
