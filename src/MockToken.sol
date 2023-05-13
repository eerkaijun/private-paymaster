// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("USDC", "USDC") {}

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}