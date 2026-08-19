// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RiskManager} from "../../src/RiskManager.sol";
import {MockPriceOracle} from "../../src/oracles/MockPriceOracle.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../src/tokens/MockERC20.sol";
import {ReserveManager} from "../../src/ReserveManager.sol";
import {LendingPool} from "../../src/LendingPool.sol";

contract LendingPoolTest is Test {
    MockERC20 usdc;
    MockERC20 weth;
    ReserveManager reserveManager;
    LendingPool lendingPool;
    RiskManager riskManager;
    MockPriceOracle priceOracle;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant USDC = 1e6;

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "mUSDC", 6);
        weth = new MockERC20("Mock WETH", "mWETH", 18);

        priceOracle = new MockPriceOracle();
        reserveManager = new ReserveManager();

        reserveManager.configureReserve(address(usdc), 6, 8_000, 8_500, 500);
        reserveManager.configureReserve(address(weth), 18, 8_000, 8_500, 500);

        priceOracle.setPrice(address(usdc), 1e8, 8);
        priceOracle.setPrice(address(weth), 3_000e8, 8);

        lendingPool = new LendingPool(address(reserveManager));

        riskManager = new RiskManager(address(reserveManager), address(priceOracle), address(lendingPool));

        lendingPool.setRiskManager(address(riskManager));

        usdc.mint(alice, 10_000 * USDC);

        usdc.mint(bob, 10_000 * USDC);
    }

    function test_Supply() public {
        uint256 amount = 1_000 * USDC;

        vm.startPrank(alice);

        usdc.approve(address(lendingPool), amount);

        lendingPool.supply(address(usdc), amount);

        vm.stopPrank();

        assertEq(lendingPool.getUserCollateral(alice, address(usdc)), amount);

        assertEq(lendingPool.totalSupplied(address(usdc)), amount);

        assertEq(usdc.balanceOf(address(lendingPool)), amount);
    }

    function test_Withdraw() public {
        uint256 amount = 1_000 * USDC;

        vm.startPrank(alice);

        usdc.approve(address(lendingPool), amount);

        lendingPool.supply(address(usdc), amount);

        lendingPool.withdraw(address(usdc), 400 * USDC);

        vm.stopPrank();

        assertEq(lendingPool.getUserCollateral(alice, address(usdc)), 600 * USDC);

        assertEq(usdc.balanceOf(alice), 9_400 * USDC);
    }

    function test_MultipleUsers() public {
        uint256 aliceAmount = 1_000 * USDC;
        uint256 bobAmount = 2_000 * USDC;

        vm.startPrank(alice);

        usdc.approve(address(lendingPool), aliceAmount);

        lendingPool.supply(address(usdc), aliceAmount);

        vm.stopPrank();

        vm.startPrank(bob);

        usdc.approve(address(lendingPool), bobAmount);

        lendingPool.supply(address(usdc), bobAmount);

        vm.stopPrank();

        assertEq(lendingPool.getUserCollateral(alice, address(usdc)), aliceAmount);

        assertEq(lendingPool.getUserCollateral(bob, address(usdc)), bobAmount);

        assertEq(lendingPool.totalSupplied(address(usdc)), aliceAmount + bobAmount);
    }

    function test_RevertIfZeroSupply() public {
        vm.prank(alice);

        vm.expectRevert("LendingPool: zero amount");

        lendingPool.supply(address(usdc), 0);
    }

    function test_RevertIfZeroWithdraw() public {
        vm.prank(alice);

        vm.expectRevert("LendingPool: zero amount");

        lendingPool.withdraw(address(usdc), 0);
    }

    function test_RevertIfWithdrawTooMuch() public {
        vm.startPrank(alice);

        usdc.approve(address(lendingPool), 1_000 * USDC);

        lendingPool.supply(address(usdc), 1_000 * USDC);

        vm.expectRevert("LendingPool: insufficient balance");

        lendingPool.withdraw(address(usdc), 1_001 * USDC);

        vm.stopPrank();
    }

    function test_BorrowAgainstCollateral() public {
        uint256 collateral = 1_000 * USDC;
        uint256 borrowAmount = 500 * USDC;

        vm.startPrank(alice);

        usdc.approve(address(lendingPool), collateral);

        lendingPool.supply(address(usdc), collateral);

        lendingPool.borrow(address(usdc), borrowAmount);

        vm.stopPrank();

        assertEq(lendingPool.getUserCollateral(alice, address(usdc)), collateral);

        assertEq(lendingPool.getUserDebt(alice, address(usdc)), borrowAmount);

        assertEq(usdc.balanceOf(alice), 9_500 * USDC);
    }

    function test_RevertIfBorrowExceedsCollateralFactor() public {
        uint256 collateral = 1_000 * USDC;
        uint256 borrowAmount = 801 * USDC;

        vm.startPrank(alice);

        usdc.approve(address(lendingPool), collateral);

        lendingPool.supply(address(usdc), collateral);

        vm.expectRevert("LendingPool: borrow not allowed");

        lendingPool.borrow(address(usdc), borrowAmount);

        vm.stopPrank();
    }

    function test_RevertIfBorrowWithoutCollateral() public {
        vm.startPrank(alice);

        vm.expectRevert("LendingPool: borrow not allowed");

        lendingPool.borrow(address(usdc), 100 * USDC);

        vm.stopPrank();
    }

    function test_Repay() public {
        uint256 collateral = 1_000 * USDC;
        uint256 borrowAmount = 500 * USDC;
        uint256 repayAmount = 200 * USDC;

        vm.startPrank(alice);

        usdc.approve(address(lendingPool), collateral);

        lendingPool.supply(address(usdc), collateral);

        lendingPool.borrow(address(usdc), borrowAmount);

        usdc.approve(address(lendingPool), repayAmount);

        lendingPool.repay(address(usdc), repayAmount);

        vm.stopPrank();

        assertEq(lendingPool.getUserDebt(alice, address(usdc)), 300 * USDC);

        assertEq(lendingPool.totalBorrowed(address(usdc)), 300 * USDC);
    }

    function test_RepayMoreThanDebt() public {
        uint256 collateral = 1_000 * USDC;
        uint256 borrowAmount = 500 * USDC;

        vm.startPrank(alice);

        usdc.approve(address(lendingPool), collateral);

        lendingPool.supply(address(usdc), collateral);

        lendingPool.borrow(address(usdc), borrowAmount);

        usdc.approve(address(lendingPool), 1_000 * USDC);

        lendingPool.repay(address(usdc), 1_000 * USDC);

        vm.stopPrank();

        assertEq(lendingPool.getUserDebt(alice, address(usdc)), 0);

        assertEq(lendingPool.totalBorrowed(address(usdc)), 0);
    }
}
