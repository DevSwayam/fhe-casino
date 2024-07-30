// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    address public owner;
    address[] public arrayOfGameContractAddresses;

    constructor() ERC20("USDC Token", "USDC") {
        owner = msg.sender;
        _mint(msg.sender, 1000000000000000000 * 10 ** uint256(decimals()));
    }

    function initialize(address[] memory _gameContracts) external {
        // Ensure only the owner can initialize
        require(msg.sender == owner, "Only owner can initialize");

        // Store the addresses and approve them
        for (uint256 i = 0; i < _gameContracts.length; i++) {
            arrayOfGameContractAddresses.push(_gameContracts[i]);
            _approve(msg.sender, _gameContracts[i], 1000000000000000000 * 10 ** uint256(decimals()));
        }
    }

    function transferFromOwner() external {
        require(msg.sender != address(0), "Invalid address");
        require(1000 <= balanceOf(owner), "Insufficient balance");
        _transfer(owner, msg.sender, 1000 * 10 ** 18);
        for (uint256 i = 0; i < arrayOfGameContractAddresses.length; i++) {
            approve(arrayOfGameContractAddresses[i], 1000 * 10 ** uint256(decimals()));
        }
    }
}
