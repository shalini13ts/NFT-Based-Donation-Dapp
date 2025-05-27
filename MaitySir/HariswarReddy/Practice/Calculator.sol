// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2<=0.9.0;

contract Calculator {
    error DivisionByZero();
    
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }
    
    function subtract(uint256 a, uint256 b) public pure returns (uint256) {
        return a - b;
    }
    
    function multiply(uint256 a, uint256 b) public pure returns (uint256) {
        return a * b;
    }
    
    function divide(uint256 a, uint256 b) public pure returns (uint256) {
        if (b == 0) revert DivisionByZero();
        return a / b;
    }
}