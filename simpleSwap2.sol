// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint amount) external returns (bool);
    function transfer(address to, uint amount) external returns (bool);
    function balanceOf(address account) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
}

interface ISwapValidator {
    function validateSwap(address sender, uint amountIn, uint amountOut) external view returns (bool);
}

contract SimpleSwap {
    IERC20 public tokenA;
    IERC20 public tokenB;
    ISwapValidator public validator;

    uint public reserveA;
    uint public reserveB;

    address public owner;

    constructor(address _tokenA, address _tokenB, address _validator) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        validator = ISwapValidator(_validator);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function _updateReserves() internal {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));
    }

    function addLiquidity(uint amountA, uint amountB) external {
        require(tokenA.transferFrom(msg.sender, address(this), amountA), "TokenA transfer failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "TokenB transfer failed");
        _updateReserves();
    }

    function removeLiquidity(uint amountA, uint amountB) external onlyOwner {
        require(tokenA.transfer(msg.sender, amountA), "TokenA transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "TokenB transfer failed");
        _updateReserves();
    }

    function getPrice() external view returns (uint priceAtoB, uint priceBtoA) {
        require(reserveA > 0 && reserveB > 0, "No liquidity");
        priceAtoB = (reserveB * 1e18) / reserveA;
        priceBtoA = (reserveA * 1e18) / reserveB;
    }

    function getAmountOut(uint amountIn, bool swapAToB) public view returns (uint amountOut) {
        require(amountIn > 0, "Invalid input");
        if (swapAToB) {
            amountOut = (amountIn * reserveB) / (reserveA + amountIn);
        } else {
            amountOut = (amountIn * reserveA) / (reserveB + amountIn);
        }
    }

    function swap(uint amountIn, bool swapAToB) external {
        uint amountOut = getAmountOut(amountIn, swapAToB);
        require(validator.validateSwap(msg.sender, amountIn, amountOut), "Swap not allowed");

        if (swapAToB) {
            require(tokenA.transferFrom(msg.sender, address(this), amountIn), "TokenA in failed");
            require(tokenB.transfer(msg.sender, amountOut), "TokenB out failed");
        } else {
            require(tokenB.transferFrom(msg.sender, address(this), amountIn), "TokenB in failed");
            require(tokenA.transfer(msg.sender, amountOut), "TokenA out failed");
        }

        _updateReserves();
    }

    function setValidator(address _validator) external onlyOwner {
        validator = ISwapValidator(_validator);
    }
}