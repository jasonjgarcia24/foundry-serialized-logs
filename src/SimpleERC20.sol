// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

uint256 constant _INITIAL_SUPPLY_ = 2008;

contract SimpleERC20 is ERC20 {
    constructor() ERC20("Simple ERC20", "SERC20") {
        _mint(msg.sender, _INITIAL_SUPPLY_);
    }
}
