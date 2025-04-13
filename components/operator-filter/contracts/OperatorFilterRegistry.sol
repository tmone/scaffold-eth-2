// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract OperatorFilterRegistry {
    mapping(address => bool) private _filteredOperators;
    
    function registerOperator(address operator) external {
        _filteredOperators[operator] = true;
    }
    
    function unregisterOperator(address operator) external {
        _filteredOperators[operator] = false;
    }
    
    function isOperatorFiltered(address operator) external view returns (bool) {
        return _filteredOperators[operator];
    }
}
