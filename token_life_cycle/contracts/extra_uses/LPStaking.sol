// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LPStaking is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public poolAmount;
    uint public rewardPool;
    uint public stakeTimeLeft;
    uint public immutable stakeEndPoint;
    uint public constant CLAIM_LOCK_DURATION = 1 days;
    uint public constant MULTIPLIER_PER_QUARTER = 3;
    uint public constant DIV = 100;
    uint public constant QUARTER = 12 weeks;
    uint public constant BASE_MULTIPLIER = 90;
    
    address public lpTokenAddress; 

    mapping (address => UserInfo) public userInfo;

    event Deposit(address indexed _user, uint amount, uint _time);
    event Withdraw(address indexed _user, uint amount);
    event Claim(address indexed _user, uint amount);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        stakeEndPoint = block.timestamp + 208 weeks; 
        stakeTimeLeft = stakeEndPoint - block.timestamp;
    }

    struct UserInfo {
        uint amount;    
        uint depositTime; 
        uint lastClaim;
        uint lockDuration;
        uint multiplier;
    }

    function setLPTokenAddress(address _lpTokenAddress)external onlyRole(DEFAULT_ADMIN_ROLE){
        require(lpTokenAddress == address(0), "LPStaking: Address is already set");
        lpTokenAddress = _lpTokenAddress;
    } 

    function deposit(uint _amount, uint _time)external nonReentrant{
        address _user = msg.sender;
        UserInfo storage user = userInfo[_user];
        require(_amount != 0, "LPStaking: You can not stake 0 LP tokens");
        require(IERC20(lpTokenAddress).balanceOf(_user) >= _amount, "LPStaking: Not enough LP tokens");
        require(user.amount == 0, "LPStaking: You are user of LPStaking already");
        require(block.timestamp + _time <= stakeEndPoint, "LPStaking: Recheck your stake-ending time");
        poolAmount += _amount;
        user.amount += _amount;
        user.depositTime = block.timestamp;
        user.lastClaim = block.timestamp;
        user.lockDuration = _time;
        uint _multiplier = BASE_MULTIPLIER;
        if(_time >= QUARTER){
            _multiplier = DIV + (_time / QUARTER) * MULTIPLIER_PER_QUARTER;
        }    
        user.multiplier = _multiplier;
        IERC20(lpTokenAddress).safeTransferFrom(_user, address(this), _amount);   

        emit Deposit(_user, _amount, block.timestamp);   
    }

    function withdraw()external nonReentrant{
        address _user = msg.sender;
        UserInfo storage user = userInfo[_user];
        require(user.amount != 0, "LPStaking: You are not user of LPStaking");
        require(block.timestamp >= (user.depositTime + user.lockDuration), "LPStaking: You can not withdraw locked LP tokens");
        uint _elapsedTime = block.timestamp - user.lastClaim;
        uint _sum = user.amount;
        if(rewardPool != 0){
            if(_elapsedTime > stakeTimeLeft){
                _elapsedTime = stakeTimeLeft;
            }        
            uint _reward = (user.amount * _elapsedTime * rewardPool * user.multiplier) / (poolAmount * stakeTimeLeft * DIV);
            if(_reward > rewardPool){
                _reward = rewardPool;
            }
            if(block.timestamp >= stakeEndPoint){
                stakeTimeLeft = 1;
            } else {
                stakeTimeLeft = stakeEndPoint - block.timestamp;
            }
            _sum = user.amount + _reward;
            rewardPool -= _reward;  
        }        
        IERC20(lpTokenAddress).safeTransfer(_user, _sum);
        poolAmount -= user.amount;  
        user.amount = 0;     
        user.lastClaim = block.timestamp; 
        user.lockDuration = 0;
        user.multiplier = 0;

        emit Withdraw(_user, _sum);      
    }

    function claimRewards()external nonReentrant{
        address _user = msg.sender;
        UserInfo storage user = userInfo[_user];
        require(user.amount != 0, "LPStaking: You are not user of LPStaking");
        require(block.timestamp >= (user.lastClaim + CLAIM_LOCK_DURATION), "LPStaking: You can not claim rewards too soon");
        uint _elapsedTime = block.timestamp - user.lastClaim; 
        if(_elapsedTime > stakeTimeLeft){
            _elapsedTime = stakeTimeLeft;
        }       
        uint _reward = (user.amount * _elapsedTime * rewardPool * user.multiplier) / (poolAmount * stakeTimeLeft * DIV);
        if(_reward > rewardPool){
            _reward = rewardPool;
        }
        if(block.timestamp >= stakeEndPoint){
            stakeTimeLeft = 1;
        } else {
            stakeTimeLeft = stakeEndPoint - block.timestamp;
        }
        IERC20(lpTokenAddress).safeTransfer(_user, _reward);
        rewardPool -= _reward;             
        user.lastClaim = block.timestamp;     

        emit Claim(_user, _reward); 
    }
}
