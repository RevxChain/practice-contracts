// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OrderBook {
    using SafeERC20 for IERC20;

    uint public totalOffers;
    uint public constant feeRate = 1000;
    
    address public immutable ownerAddress;

    mapping(bytes32 => Offer) public offers;

    event newOrder(bytes32 indexed orderId, address sellToken, uint sellAmount, address buyToken, uint buyAmount, bool indexed status);
    event executedOrder(bytes32 indexed orderId, address sellToken, uint sellAmount, address buyToken, uint buyAmount, bool indexed status);
    event closedOrder(bytes32 indexed orderId, bool indexed status);
    event changedOrder(bytes32 indexed orderId, address sellToken, uint sellAmount, address buyToken, uint buyAmount, bool indexed status);
    event canceledOrder(bytes32 indexed orderId, bool indexed status);

    modifier offerActive(bytes32 _id){
        require(offers[_id].owner != address(0), "OrderBook: Offer is not exist");
        require(offers[_id].active != false, "OrderBook: Offer is closed already");
        _;
    }

    struct Offer {
        bytes32 id;
        uint count;
        address owner;
        address sellToken;
        uint sellAmount;
        address buyToken;
        uint buyAmount;
        uint openTime;
        bool active;
    }

    constructor(){
        ownerAddress = tx.origin;
    }

    function createOrder(address _sellToken, uint _sellAmount, address _buyToken, uint _buyAmount)external returns(bytes32 _orderId){
        address _user = msg.sender;
        require(_sellToken != address(0) && _buyToken != address(0), "OrderBook: Zero address");
        require(_sellToken != _buyToken, "OrderBook: Same addresses");
        require(_sellAmount > 0 && _buyAmount > 0, "OrderBook: Zero amount");
        require(IERC20(_sellToken).balanceOf(_user) >= _sellAmount, "OrderBook: Not enough tokens");
        _orderId = calculateOrderId(totalOffers, _user, _sellToken, _buyToken, block.timestamp);
        require(offers[_orderId].owner == address(0), "OrderBook: Same order is already exist");
        Offer memory newOffer = Offer(
            _orderId,
            totalOffers,
            _user,
            _sellToken, 
            _sellAmount,
            _buyToken, 
            _buyAmount,
            block.timestamp,
            true
        );
        offers[_orderId] = newOffer;
        totalOffers += 1;
        IERC20(_sellToken).safeTransferFrom(_user, address(this), _sellAmount);

        emit newOrder(_orderId, _sellToken, _sellAmount, _buyToken, _buyAmount, offers[_orderId].active);
    }

    function executeOrder(bytes32 _orderId, uint _amount)external offerActive(_orderId){
        address _user = msg.sender;
        uint feeAmount = _amount / feeRate;
        require(IERC20(offers[_orderId].buyToken).balanceOf(_user) >= _amount, "OrderBook: Not enough tokens");
        require(IERC20(offers[_orderId].buyToken).balanceOf(_user) >= _amount + feeAmount, "OrderBook: Not enough fee for order execution");
        uint amountOut;
        if(_amount >= offers[_orderId].buyAmount){
            _amount = offers[_orderId].buyAmount;
            amountOut = offers[_orderId].sellAmount;
            offers[_orderId].active = false;

            emit closedOrder(_orderId, offers[_orderId].active);
        } else {
            amountOut = offers[_orderId].sellAmount * _amount / offers[_orderId].buyAmount;
            offers[_orderId].sellAmount -= amountOut;
            offers[_orderId].buyAmount -= _amount;

            emit executedOrder(
                _orderId, 
                offers[_orderId].sellToken, 
                offers[_orderId].sellAmount, 
                offers[_orderId].buyToken, 
                offers[_orderId].buyAmount, 
                offers[_orderId].active
            );
        }       
        IERC20(offers[_orderId].buyToken).safeTransferFrom(_user, offers[_orderId].owner, _amount);
        IERC20(offers[_orderId].buyToken).safeTransferFrom(_user, ownerAddress, feeAmount);
        IERC20(offers[_orderId].sellToken).safeTransfer(_user, amountOut);  
    }

    function changeOrder(bytes32 _orderId, uint _sellAmount, uint _buyAmount)external offerActive(_orderId){
        address _user = msg.sender;
        require(offers[_orderId].owner == _user, "OrderBook: You are not an owner");
        require(_sellAmount > 0 && _buyAmount > 0, "OrderBook: Zero amount");
        if(_sellAmount > offers[_orderId].sellAmount){
            require(IERC20(offers[_orderId].sellToken).balanceOf(_user) >= _sellAmount - offers[_orderId].sellAmount, "OrderBook: Not enough tokens");
            IERC20(offers[_orderId].sellToken).safeTransferFrom(_user, address(this), _sellAmount - offers[_orderId].sellAmount);
        } else {
            if(_sellAmount != offers[_orderId].sellAmount){
                IERC20(offers[_orderId].sellToken).safeTransfer(_user, offers[_orderId].sellAmount - _sellAmount);
            }   
        }
        offers[_orderId].sellAmount = _sellAmount;
        offers[_orderId].buyAmount = _buyAmount;

        emit changedOrder(
            _orderId, 
            offers[_orderId].sellToken, 
            offers[_orderId].sellAmount, 
            offers[_orderId].buyToken, 
            offers[_orderId].buyAmount, 
            offers[_orderId].active
        );   
    }

    function cancelOrder(bytes32 _orderId)external offerActive(_orderId){
        address _user = msg.sender;
        require(offers[_orderId].owner == _user, "OrderBook: You are not an owner");
        offers[_orderId].active = false;
        IERC20(offers[_orderId].sellToken).safeTransfer(_user, offers[_orderId].sellAmount);

        emit canceledOrder(_orderId, offers[_orderId].active);
    }

    function calculateOrderId(uint _count, address _owner, address _sellToken, address _buyToken, uint _openTime)public pure returns(bytes32){
        return keccak256(abi.encode(
            _count, _owner, _sellToken, _buyToken, _openTime
        ));    
    }
}
