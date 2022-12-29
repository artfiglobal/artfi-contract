// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20("USDC", "USDC") {
    function mint(address _to, uint _amount) external {
        _mint(_to, _amount);
    }
}