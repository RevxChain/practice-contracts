// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ITokenSale {
    function purchased(address)external returns(uint);
    function vestingStart()external returns(uint);
}

contract Vesting is AccessControl{
    using SafeERC20 for IERC20;

    uint public teamPool;
    uint public constant VESTING_LENGTH = 26 weeks;
    uint public constant TEAM_CLIFF_LENGTH = 104 weeks;

    address public immutable tokenSaleAddress;
    address public immutable tokenAddress;
    address public immutable multiSigSafe;

    mapping(address => uint) public unlocked;
    mapping(address => uint) public claimed;

    event UnlockedByUser(address indexed user, uint newUnlocked);
    event ClaimedByUser(address indexed user, uint newClaimed);
        
    constructor(address _tokenSaleAddress, address _tokenAddress, address _multiSigSafe)  {
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        tokenSaleAddress = _tokenSaleAddress;
        tokenAddress = _tokenAddress;
        multiSigSafe = _multiSigSafe;
    }

    function locked(address _user)external returns(uint){
        uint _purchased = ITokenSale(tokenSaleAddress).purchased(_user);
        return _purchased - unlocked[_user];
    }

    function unlock(address _user)public {
        uint _purchased = ITokenSale(tokenSaleAddress).purchased(_user);
        require (_purchased > 0, "Vesting: You are not a participant of the Token Sale");
        uint elapsedTime = block.timestamp - ITokenSale(tokenSaleAddress).vestingStart();
        if (elapsedTime > VESTING_LENGTH) {
            elapsedTime = VESTING_LENGTH;
        }
        unlocked[_user] = _purchased * elapsedTime / VESTING_LENGTH;

        emit UnlockedByUser(_user, unlocked[_user]);
    }

    function claim()external {
        address _user = msg.sender;
        unlock(_user);
        require (claimed[_user] < ITokenSale(tokenSaleAddress).purchased(_user), "Vesting: You are claimed all tokens already");
        uint nowClaimed = unlocked[_user] - claimed[_user];
        claimed[_user] += nowClaimed;   
        IERC20(tokenAddress).safeTransfer(_user, nowClaimed);

        emit ClaimedByUser(_user, claimed[_user]);
    }

    function teamClaim()external onlyRole(DEFAULT_ADMIN_ROLE) {    
        require(block.timestamp > ITokenSale(tokenSaleAddress).vestingStart() + TEAM_CLIFF_LENGTH, "Vesting: Cliff is not finished yet");
        require(teamPool > 0, "Vesting: Team tokens are claimed already");
        IERC20(tokenAddress).safeTransfer(multiSigSafe, teamPool);
        teamPool = 0;
    }
}
