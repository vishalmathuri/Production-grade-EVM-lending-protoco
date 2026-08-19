// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReserveManager} from "../../src/ReserveManager.sol";

contract ReserveManagerTest is Test {
    ReserveManager manager;

    address weth = makeAddr("weth");
    address usdc = makeAddr("usdc");

    address alice = makeAddr("alice");

    function setUp() public {
        manager = new ReserveManager();
    }

    function test_ConfigureWETH() public {
        manager.configureReserve(weth, 18, 8_000, 8_500, 500);

        assertTrue(manager.isActive(weth));
        assertTrue(manager.isBorrowEnabled(weth));

        assertEq(manager.getDecimals(weth), 18);

        assertEq(manager.getCollateralFactor(weth), 8_000);

        assertEq(manager.getLiquidationThreshold(weth), 8_500);

        assertEq(manager.getLiquidationBonus(weth), 500);
    }

    function test_ConfigureUSDC() public {
        manager.configureReserve(usdc, 6, 8_000, 8_500, 500);

        assertTrue(manager.isActive(usdc));

        assertEq(manager.getDecimals(usdc), 6);
    }

    function test_SetReserveStatus() public {
        manager.configureReserve(weth, 18, 8_000, 8_500, 500);

        manager.setReserveStatus(weth, true, false);

        assertTrue(manager.isActive(weth));
        assertFalse(manager.isBorrowEnabled(weth));
    }

    function test_RevertIfCollateralFactorTooHigh() public {
        vm.expectRevert("Reserve: invalid collateral factor");

        manager.configureReserve(weth, 18, 10_001, 8_500, 500);
    }

    function test_RevertIfThresholdBelowCollateral() public {
        vm.expectRevert("Reserve: threshold below collateral");

        manager.configureReserve(weth, 18, 8_500, 8_000, 500);
    }

    function test_RevertIfNotConfigured() public {
        vm.expectRevert("Reserve: not configured");

        manager.setReserveStatus(weth, false, false);
    }

    function test_RevertIfNotOwner() public {
        vm.prank(alice);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));

        manager.configureReserve(weth, 18, 8_000, 8_500, 500);
    }
}
