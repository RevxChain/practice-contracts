//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Faucet {
    using SafeERC20 for IERC20;

    uint public immutable faucetCooldown;
    uint public immutable faucetAmount;
    uint public immutable capAmount;
    address public immutable tokenAddress;

    mapping(address => uint) public lastClaim;

    event Claim(address indexed user, uint time);

    constructor(address _tokenAddress, uint _faucetCooldown, uint _faucetAmount, uint _capAmount){
        tokenAddress = _tokenAddress;
        faucetCooldown = _faucetCooldown;
        faucetAmount =  _faucetAmount;
        capAmount = _capAmount;
    }

    function faucet()external {
        address _user = msg.sender;
        require(_user == tx.origin, "Faucet: You have to use your EOA address");
        require(IERC20(tokenAddress).balanceOf(_user) < capAmount, "Faucet: You have enough tokens");
        require(block.timestamp >= (lastClaim[_user] + faucetCooldown), "Faucet: The faucet has a cooldown");
        require(IERC20(tokenAddress).balanceOf(address(this)) >= faucetAmount, "Faucet: The faucet is ran out");
        IERC20(tokenAddress).safeTransfer(_user, faucetAmount);
        lastClaim[_user] = block.timestamp;
        
        emit Claim(_user, block.timestamp);
    }
}
