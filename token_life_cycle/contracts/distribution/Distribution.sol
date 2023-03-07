// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IFactory{
    function pair(address _tokenA, address _tokenB)external returns(address);
}

contract Distribution is AccessControl {
    using SafeERC20 for IERC20;
    
    uint private immutable etherValueForLiquidityPool;
    uint private constant DEADLINE_DURATION = 600; 

    address public tokenAddress;
    
    uint[5] public amounts; 

    address[8] public addresses;

    event Distributed(uint time);

    constructor(address[8] memory _addresses, uint[5] memory _amounts)payable {
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        for(uint i; i < addresses.length; i++){
            addresses[i] = _addresses[i];
        }
        for(uint i; i < _amounts.length; i++){
            amounts[i] = _amounts[i];
        }
        etherValueForLiquidityPool = msg.value;  
    }

    function setTokenAddress(address _tokenAddress)external onlyRole(DEFAULT_ADMIN_ROLE){
        require(tokenAddress == address(0), "Distribution: Address is already set");
        tokenAddress = _tokenAddress;
    }

    function distribute()external onlyRole(DEFAULT_ADMIN_ROLE){
        for(uint i; i < amounts.length; i++){
            if(i == 4){
                IERC20(tokenAddress).approve(addresses[i], amounts[i]);
                (bool success, ) = addresses[i].call{value: etherValueForLiquidityPool}(
                abi.encodeWithSignature("addLiquidityETH(address,uint256,uint256)", 
                tokenAddress, amounts[i], block.timestamp + DEADLINE_DURATION)
                );
                require(success == true, "Distribution: Add liquidity error");
                address _pair = IFactory(addresses[6]).pair(tokenAddress, addresses[7]);
                IERC20(_pair).safeTransfer(addresses[5], IERC20(_pair).balanceOf(address(this)));
            } else {
                IERC20(tokenAddress).safeTransfer(addresses[i], amounts[i]);
            }                      
        }

        emit Distributed(block.timestamp);
    }
}
