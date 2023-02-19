//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JustToken is ERC20 {

    constructor(address _distributionAddress, uint _amountToMint) ERC20("JustToken", "JT"){
        _mint(_distributionAddress, _amountToMint);
    }
}
