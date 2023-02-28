// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IFactory{
    function pair(address _tokenAddress, address _WETHAddress)external returns(address);
}

interface IPair{
    function getReserves()external view returns(uint, uint);
}

contract TokenSale is AccessControl, ReentrancyGuard{
    using SafeERC20 for IERC20;

    uint public immutable stableCoinPrice;
    uint public immutable vestingStart;
    uint public constant tokenTotalCap = 1000e18;
    uint public constant ACCURACY = 1e18;
    uint public constant tokenSaleDuration = 4 weeks;

    address private immutable stableCoinAddress;
    address private immutable pairAddress;

    mapping(address => uint) public purchased;
    mapping(address => bool) private participantList;

    event TokensPurchased(address indexed user, uint tokens_amount);

    constructor(address _stableCoinAddress, address _factory, address _WETHAddress, uint _stableCoinPrice) {
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        stableCoinPrice = _stableCoinPrice;
        stableCoinAddress = _stableCoinAddress;
        pairAddress = IFactory(_factory).pair(_stableCoinAddress, _WETHAddress);
        vestingStart = block.timestamp + tokenSaleDuration;
    }
    
    function buyWithEther()public payable nonReentrant{
        address _user = msg.sender;
        require(participantList[_user] == false, "TokenSale: You are already participate in the Token Sale");
        require(block.timestamp < vestingStart, "TokenSale: TokenSale is already closed");
        uint ethReceived = msg.value;
        require(ethReceived > 0, "TokenSale: 0 ETH sent");
        (uint reserve0, uint reserve1) = IPair(pairAddress).getReserves();
        uint ethPrice = reserve0 * ACCURACY / reserve1; 
        uint purchasedTokens = ethReceived * ethPrice / stableCoinPrice;
        require(purchasedTokens >= ACCURACY, "TokenSale: You can not buy less than 1 token");
        uint buy = tokenTotalCap - purchased[_user];
        purchased[_user] += purchasedTokens;
        if (purchased[_user] >= tokenTotalCap){
            purchased[_user] = tokenTotalCap;
            uint refund = (ethPrice * ethReceived - buy * stableCoinPrice) / ethPrice;
            (bool success,) = _user.call{value: refund}("");
            require(success, "TokenSale: Failed refund Ether transfer");
            participantList[_user] = true;
        }

        emit TokensPurchased(_user, purchasedTokens);
    }

    function buyWithStableCoin(uint _amount)external nonReentrant{
        address _user = msg.sender;
        require(participantList[_user] == false, "TokenSale: You are participate in the Token Sale already ");
        require(block.timestamp < vestingStart, "TokenSale: Token Sale is closed already ");
        require(_amount > 0, "TokenSale: You can not transfer zero tokens");
        uint purchasedTokens = _amount * ACCURACY / stableCoinPrice;
        require(purchasedTokens >= ACCURACY, "TokenSale: You can not buy less than 1 token");
        uint buy = tokenTotalCap - purchased[_user];  
        purchased[_user] += purchasedTokens;
        if (purchased[_user] >= tokenTotalCap){
            purchased[_user] = tokenTotalCap;
            _amount = buy * stableCoinPrice / ACCURACY;
            participantList[_user] = true;
        }
        IERC20(stableCoinAddress).safeTransferFrom(_user, address(this), _amount);

        emit TokensPurchased(_user, purchasedTokens);
    }

    function withdrawEther(address _receiver, uint _amount)external onlyRole(DEFAULT_ADMIN_ROLE){
        (bool success,) = _receiver.call{value: _amount}("");
        require(success, "TokenSale: Failed Ether transfer");
    }

    function withdrawStableCoin(address _receiver, uint _amount)external onlyRole(DEFAULT_ADMIN_ROLE){
        IERC20(stableCoinAddress).safeTransfer(_receiver, _amount);
    }

    receive() external payable {
        buyWithEther();
    }
}
