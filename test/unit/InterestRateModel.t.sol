// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {InterestRateModel} from "../../src/InterestRateModel.sol";

contract InterestRateModelTest is Test {
    InterestRateModel interestRateModel;

    uint256 constant WAD = 1e18;
    uint256 constant BPS = 10_000;

    function setUp() public {
        interestRateModel = new InterestRateModel();
    }

    function test_BorrowRateAtZeroUtilization() public view {
        uint256 supplied = 1_000 * WAD;
        uint256 borrowed = 0;

        uint256 rate = interestRateModel.getBorrowRate(supplied, borrowed);

        assertEq(rate, 200);
    }

    function test_BorrowRateAt50PercentUtilization() public view {
        uint256 supplied = 1_000 * WAD;
        uint256 borrowed = 500 * WAD;

        uint256 rate = interestRateModel.getBorrowRate(supplied, borrowed);

        // Base 2% + (50% * 10%) = 7%
        assertEq(rate, 700);
    }

    function test_BorrowRateAt100PercentUtilization() public view {
        uint256 supplied = 1_000 * WAD;
        uint256 borrowed = 1_000 * WAD;

        uint256 rate = interestRateModel.getBorrowRate(supplied, borrowed);

        // Base 2% + 10% = 12%
        assertEq(rate, 1_200);
    }

    function test_SupplyRateAtZeroUtilization() public view {
        uint256 supplied = 1_000 * WAD;
        uint256 borrowed = 0;

        uint256 rate = interestRateModel.getSupplyRate(supplied, borrowed);

        assertEq(rate, 0);
    }

    function test_SupplyRateAt50PercentUtilization() public view {
        uint256 supplied = 1_000 * WAD;
        uint256 borrowed = 500 * WAD;

        uint256 rate = interestRateModel.getSupplyRate(supplied, borrowed);

        // 7% borrow rate * 50% utilization = 3.5%
        assertEq(rate, 350);
    }

    function test_SupplyRateAt100PercentUtilization() public view {
        uint256 supplied = 1_000 * WAD;
        uint256 borrowed = 1_000 * WAD;

        uint256 rate = interestRateModel.getSupplyRate(supplied, borrowed);

        // 12% borrow rate * 100% utilization = 12%
        assertEq(rate, 1_200);
    }

    function test_BorrowRateWhenNoLiquidity() public view {
        uint256 supplied = 0;
        uint256 borrowed = 0;

        uint256 rate = interestRateModel.getBorrowRate(supplied, borrowed);

        assertEq(rate, 200);
    }

    function test_SupplyRateWhenNoLiquidity() public view {
        uint256 supplied = 0;
        uint256 borrowed = 0;

        uint256 rate = interestRateModel.getSupplyRate(supplied, borrowed);

        assertEq(rate, 0);
    }
}
