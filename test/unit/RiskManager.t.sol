// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../src/tokens/MockERC20.sol";
import {MockPriceOracle} from "../../src/oracles/MockPriceOracle.sol";
import {ReserveManager} from "../../src/ReserveManager.sol";
import {LendingPool} from "../../src/LendingPool.sol";
import {RiskManager} from "../../src/RiskManager.sol";

contract RiskManagerTest is Test {
    MockERC20 weth;
    MockERC20 usdc;

    MockPriceOracle priceOracle;
    ReserveManager reserveManager;
    LendingPool lendingPool;
    RiskManager riskManager;

    address alice = makeAddr("alice");

    uint256 constant USDC = 1e6;
    uint256 constant WETH = 1e18;

    function setUp() public {
        weth = new MockERC20("Mock WETH", "mWETH", 18);

        usdc = new MockERC20("Mock USDC", "mUSDC", 6);

        priceOracle = new MockPriceOracle();
        reserveManager = new ReserveManager();

        reserveManager.configureReserve(address(weth), 18, 8_000, 8_500, 500);

        reserveManager.configureReserve(address(usdc), 6, 8_000, 8_500, 500);

        lendingPool = new LendingPool(address(reserveManager));

        riskManager = new RiskManager(address(reserveManager), address(priceOracle), address(lendingPool));

        // WETH = $3,000
        priceOracle.setPrice(address(weth), 3000e8, 8);

        // USDC = $1
        priceOracle.setPrice(address(usdc), 1e8, 8);

        weth.mint(alice, 10 * WETH);

        usdc.mint(alice, 10_000 * USDC);
    }

    function test_HealthFactorWithNoDebt() public {
        uint256 healthFactor = riskManager.calculateHealthFactor(alice);

        assertEq(healthFactor, type(uint256).max);
    }

    function test_CalculateWETHCollateralValue() public {
        vm.startPrank(alice);

        weth.approve(address(lendingPool), 1 * WETH);

        lendingPool.supply(address(weth), 1 * WETH);

        vm.stopPrank();

        uint256 collateral = lendingPool.getUserCollateral(alice, address(weth));

        assertEq(collateral, 1 * WETH);
    }

    function test_CalculateUSDCPosition() public {
        vm.startPrank(alice);

        usdc.approve(address(lendingPool), 1_000 * USDC);

        lendingPool.supply(address(usdc), 1_000 * USDC);

        vm.stopPrank();

        assertEq(lendingPool.getUserCollateral(alice, address(usdc)), 1_000 * USDC);
    }

    function test_SupportedAssetsRegistered() public {
        vm.startPrank(alice);

        weth.approve(address(lendingPool), 1 * WETH);

        lendingPool.supply(address(weth), 1 * WETH);

        usdc.approve(address(lendingPool), 1_000 * USDC);

        lendingPool.supply(address(usdc), 1_000 * USDC);

        vm.stopPrank();

        address[] memory assets = lendingPool.getSupportedAssets();

        assertEq(assets.length, 2);

        assertEq(assets[0], address(weth));

        assertEq(assets[1], address(usdc));
    }

    function test_CanLiquidateWhenHealthFactorBelowOne() public {
        // This test will be completed after borrow
        // functionality is implemented.
        assertFalse(riskManager.canLiquidate(alice));
    }
}
