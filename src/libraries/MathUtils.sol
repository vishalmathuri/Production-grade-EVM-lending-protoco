// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library MathUtils {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant BPS = 10_000;

    function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / WAD;
    }

    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "MathUtils: division by zero");

        return (a * WAD) / b;
    }

    function bpsMul(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
        return (amount * basisPoints) / BPS;
    }
}
