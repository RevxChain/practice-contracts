// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IVPToken{
    function mintPower(address user, uint amount)external;
    function burnPower(address user, uint amount)external;
}

contract Staking is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public poolAmount;
    uint public rewardAmount; 
    uint public stakeTimeLeft;
    uint public immutable stakeEndPoint;
    uint public constant WITHDRAW_LOCK_DURATION = 21 days;
    uint public constant STAKING_DURATION = 104 weeks;

    address public VPTokenAddress; 
    address public immutable tokenAddress;

    mapping (address => UserInfo) public userInfo;

    event Deposit(address indexed _user, uint amount);
    event Withdraw(address indexed _user, uint amount);
    event Claim(address indexed _user, uint amount);

    struct UserInfo {
        uint amount;     
        uint lastClaim;
        uint lastDeposit; 
    }

    constructor(address _tokenAddress, uint _rewardAmount){
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        tokenAddress = _tokenAddress;
        stakeEndPoint = block.timestamp + STAKING_DURATION; 
        stakeTimeLeft = STAKING_DURATION; 
        rewardAmount = _rewardAmount;
    }

    function setVPTokenAddress(address _VPTokenAddress)external onlyRole(DEFAULT_ADMIN_ROLE){
        require(VPTokenAddress == address(0), "Staking: VPTokenAddress is set already");
        VPTokenAddress = _VPTokenAddress;
    }

    function deposit(uint _amount)external nonReentrant{
        address _user = msg.sender;
        UserInfo storage user = userInfo[_user];
        require(_amount > 1 ether, "Staking: You can not stake one token");
        if(user.amount > 0) {
            uint _lastClaim = block.timestamp - user.lastClaim; 
            if(_lastClaim > stakeTimeLeft){
                _lastClaim = stakeTimeLeft;
            } 
            uint _reward = (user.amount * _lastClaim * rewardAmount) / (poolAmount * stakeTimeLeft);
            if(block.timestamp >= stakeEndPoint){
                stakeTimeLeft = 1;
            } else {
                stakeTimeLeft = stakeEndPoint - block.timestamp;
            }
            IERC20(tokenAddress).safeTransfer(_user, _reward);
            rewardAmount -= _reward;
        }     
        user.amount += _amount;
        poolAmount += _amount;
        user.lastClaim = block.timestamp;
        user.lastDeposit = block.timestamp;
        IERC20(tokenAddress).safeTransferFrom(_user, address(this), _amount);  
        IVPToken(VPTokenAddress).mintPower(_user, _amount);

        emit Deposit(_user, _amount);   
    }

    function withdraw()external nonReentrant{
        address _user = msg.sender;
        UserInfo storage user = userInfo[_user];
        require(user.amount != 0, "Staking: You are not user of staking");
        require(block.timestamp >= (user.lastDeposit + WITHDRAW_LOCK_DURATION), "Staking: You can not withdraw locked tokens");
        require(IERC20(VPTokenAddress).balanceOf(_user) >= user.amount, "Staking: Not enough of Voting power tokens");
        uint _lastClaim = block.timestamp - user.lastClaim;
        uint _sum = user.amount;
        if(rewardAmount != 0){
            if(_lastClaim > stakeTimeLeft){
                _lastClaim = stakeTimeLeft;
            }        
            uint _reward = (user.amount * _lastClaim * rewardAmount) / (poolAmount * stakeTimeLeft);
            if(_reward > rewardAmount){
                _reward = rewardAmount;
            }
            if(block.timestamp >= stakeEndPoint){
                stakeTimeLeft = 1;
            } else {
                stakeTimeLeft = stakeEndPoint - block.timestamp;
            }
            _sum = user.amount + _reward;
            rewardAmount -= _reward;  
        }   
        IERC20(tokenAddress).safeTransfer(_user, _sum);
        IVPToken(VPTokenAddress).burnPower(_user, user.amount);  
        poolAmount -= user.amount;  
        user.amount = 0;     
        user.lastClaim = block.timestamp; 

        emit Withdraw(_user, _sum);      
    }

    function claimRewards()external nonReentrant{
        address _user = msg.sender;
        UserInfo storage user = userInfo[_user];
        require(user.amount != 0, "Staking: You are not user of staking");
        require(rewardAmount > 0, "Staking: Reward pool is empty");
        uint _lastClaim = block.timestamp - user.lastClaim; 
        if(_lastClaim > stakeTimeLeft){
            _lastClaim = stakeTimeLeft;
        }       
        uint _reward = (user.amount * _lastClaim * rewardAmount) / (poolAmount * stakeTimeLeft);
        if(_reward > rewardAmount){
            _reward = rewardAmount;
        }
        require(_reward > 1 ether, "Staking: Too soon");
        if(block.timestamp >= stakeEndPoint){
            stakeTimeLeft = 1;
        } else {
            stakeTimeLeft = stakeEndPoint - block.timestamp;
        }
        IERC20(tokenAddress).safeTransfer(_user, _reward);
        rewardAmount -= _reward;             
        user.lastClaim = block.timestamp;     

        emit Claim(_user, _reward); 
    }
}
