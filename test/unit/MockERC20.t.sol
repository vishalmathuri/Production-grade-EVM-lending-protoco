// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../src/tokens/MockERC20.sol";

contract MockERC20Test is Test {
    MockERC20 token;

    address alice = makeAddr("alice");

    function setUp() public {
        token = new MockERC20("Mock USDC", "mUSDC", 6);
    }

    function test_Decimals() public {
        assertEq(token.decimals(), 6);
    }

    function test_Mint() public {
        token.mint(alice, 1_000_000);

        assertEq(token.balanceOf(alice), 1_000_000);
    }

    function test_NameAndSymbol() public {
        assertEq(token.name(), "Mock USDC");
        assertEq(token.symbol(), "mUSDC");
    }
}
