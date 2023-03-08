// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BetGame is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public totalVotes;
    uint private feePool;
    uint public constant FEE_RATE = 100; 

    address public immutable tokenAddress;

    mapping(uint => vote) public votes;
    mapping(uint => mapping(address => uint)) private value;

    modifier votingExist(uint _id){
        require(_id <= totalVotes, "BetGame: Voting is not exist");
        _;
    }

    struct vote {
        uint id;
        address[] candidates;
        uint startTime;
        uint endTime;
        address winner;
        uint pool;
        bool ended;
        bool withdrawn;
    }

    constructor(address _tokenAddress){
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        tokenAddress = _tokenAddress;
    }

    function setVote(address[] memory _candidates, uint _voteTime)external nonReentrant(){
        totalVotes += 1;
        vote memory newVote = vote(
            totalVotes,
            _candidates,
            block.timestamp,
            block.timestamp + _voteTime,
            address(0),
            0,
            false,
            false          
        );
        votes[totalVotes] = newVote;
    }

    function voteFor(uint _id, uint _candidate, address _candidateAddress, uint _value)external votingExist(_id) nonReentrant(){
        address candidateAddress = votes[_id].candidates[_candidate];
        address _user = msg.sender;
        require(_value > 0, "BetGame: Wrong vote power");
        require(candidateAddress == _candidateAddress, "BetGame: Recheck candidate address and his number list");
        require(votes[_id].ended == false , "BetGame: Voting time out");
        if (block.timestamp >= votes[_id].endTime ){
            votes[_id].ended = true;
        } else {
            value[_id][candidateAddress] += _value;
            if (value[_id][candidateAddress] > value[_id][votes[_id].winner]){
                votes[_id].winner = candidateAddress;
            }
            uint _fee = _value / FEE_RATE;
            feePool += _fee;
            votes[_id].pool += _value - _fee;
            IERC20(tokenAddress).safeTransferFrom(_user, address(this), _value);
        }
    }

    function withdrawFee(address _to, uint _amount)external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant(){
        require(feePool > 0, "BetGame: Fee pool is empty");
        require(IERC20(tokenAddress).balanceOf(address(this)) >= _amount, "BetGame: Amount is exceed balance");
        IERC20(tokenAddress).safeTransfer(_to, _amount);
        feePool -= _amount;
    } 

    function withdrawWinner(uint _id)external votingExist(_id) nonReentrant(){
        if (block.timestamp >= votes[_id].endTime ){
            votes[_id].ended = true;
        }
        require(votes[_id].ended == true, "BetGame: Voting is not ended yet");
        address _user = msg.sender;
        require(votes[_id].winner == _user, "BetGame: You are not a winner");
        require(votes[_id].withdrawn == false, "BetGame: Tokens is already withdrawn");
        IERC20(tokenAddress).safeTransfer(_user, votes[_id].pool);
        votes[_id].withdrawn = true;
        votes[_id].pool = 0;
    }

    function checkCandidates(uint _id)external view votingExist(_id) returns(address[] memory){
        return votes[_id].candidates;
    }
}
