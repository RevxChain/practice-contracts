// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract VPToken is ERC20, ERC20Burnable {

    address immutable stakingAddress;

    modifier checkCall(address _address){
        require(_address == stakingAddress, "VotingPowerToken: Caller must be a staking address");
        _;
    }

    constructor (address _stakingAddress) ERC20("VotingPowerToken", "VPT") {
        stakingAddress = _stakingAddress;
    }

    function mintPower(address _user, uint _amount)external checkCall(msg.sender){
        _mint(_user, _amount);
    }

    function burnPower(address _user, uint _amount)external checkCall(msg.sender){
        _burn(_user, _amount);
    }

    function _transfer(address from, address to, uint256 amount)internal override checkCall(msg.sender){

    }

    function _burn(address _user, uint256 amount)internal override checkCall(msg.sender){

    }

    function _approve(address owner, address spender, uint256 amount)internal override checkCall(msg.sender){

    }
}
