// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockPriceOracle} from "../../src/oracles/MockPriceOracle.sol";

contract MockPriceOracleTest is Test {
    MockPriceOracle oracle;

    address owner = address(this);
    address weth = makeAddr("weth");
    address usdc = makeAddr("usdc");

    function setUp() public {
        oracle = new MockPriceOracle();
    }

    function test_SetAndGetPrice() public {
        oracle.setPrice(weth, 3000e8, 8);

        assertEq(oracle.getPrice(weth), 3000e8);

        assertEq(oracle.getPriceDecimals(weth), 8);
    }

    function test_SetUSDCPrice() public {
        oracle.setPrice(usdc, 1e8, 8);

        assertEq(oracle.getPrice(usdc), 1e8);
    }

    function test_RevertIfZeroPrice() public {
        vm.expectRevert("MockOracle: invalid price");

        oracle.setPrice(weth, 0, 8);
    }

    function test_RevertIfZeroAsset() public {
        vm.expectRevert("MockOracle: zero asset");

        oracle.setPrice(address(0), 3000e8, 8);
    }

    function test_RevertIfPriceUnavailable() public {
        vm.expectRevert("MockOracle: price unavailable");

        oracle.getPrice(weth);
    }
}
