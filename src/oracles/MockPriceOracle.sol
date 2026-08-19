// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

contract MockPriceOracle is IPriceOracle {
    struct PriceData {
        uint256 price;
        uint8 decimals;
        bool active;
    }

    mapping(address => PriceData) private prices;

    address public owner;

    event PriceUpdated(address indexed asset, uint256 price, uint8 decimals);

    modifier onlyOwner() {
        require(msg.sender == owner, "MockOracle: not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setPrice(address asset, uint256 price, uint8 decimals) external onlyOwner {
        require(asset != address(0), "MockOracle: zero asset");
        require(price > 0, "MockOracle: invalid price");

        prices[asset] = PriceData({price: price, decimals: decimals, active: true});

        emit PriceUpdated(asset, price, decimals);
    }

    function getPrice(address asset) external view returns (uint256) {
        PriceData memory data = prices[asset];

        require(data.active, "MockOracle: price unavailable");

        return data.price;
    }

    function getPriceDecimals(address asset) external view returns (uint8) {
        PriceData memory data = prices[asset];

        require(data.active, "MockOracle: price unavailable");

        return data.decimals;
    }
}
