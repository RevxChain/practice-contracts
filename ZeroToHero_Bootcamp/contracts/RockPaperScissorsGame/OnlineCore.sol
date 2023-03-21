// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract OnlineCore is AccessControl{

    uint public totalOnlineBatches;    
    
    uint public constant OPTION_ROCK = 0;
    uint public constant OPTION_PAPER = 1;
    uint public constant OPTION_SCISSORS = 2;
    uint public constant MINIMAL_TOKEN_BET = 1e18;
    uint public constant PROOF_DURATION = 3 days;

    address public router; 

    bytes32 public constant DISPOSABLE_CALLER = keccak256(abi.encode("DISPOSABLE_CALLER"));
    bytes32 public constant ROUTER_CALLER = keccak256(abi.encode("ROUTER_CALLER"));

    mapping(uint => onlineBatch) public onlineBatches;

    modifier onlineGameExist(uint _gameId){ 
        require(totalOnlineBatches > _gameId, "OnlineCore: That game ID is not exist");
        _;
    }

    struct onlineBatch{
        uint id;
        address token;
        address playerOne;
        bytes32 answerHash; 
        uint answerOne;
        address playerTwo; 
        uint answerTwo;
        uint bet;
        address winner;
        uint startTimeToProof;
        bool closed;
    }

    constructor() {
        _setupRole(DISPOSABLE_CALLER, msg.sender);
    }

    function setRouter(address _router)external onlyRole(DISPOSABLE_CALLER){
        router = _router;
        _setupRole(ROUTER_CALLER, router); 
    }

    function createOnlineGameEther(
        address _user, 
        bytes32 _answerHash, 
        uint _bet
    )
        external 
        onlyRole(ROUTER_CALLER) 
        returns(uint _gameId)
    {
        onlineDefineData(address(0), _user, _answerHash, _bet);
        _gameId = totalOnlineBatches;
        totalOnlineBatches += 1;
    }

    function participateOnlineGameEther(
        address _user, 
        uint _gameId, 
        uint _answer
    )
        external 
        onlineGameExist(_gameId) 
        onlyRole(ROUTER_CALLER) 
        returns(uint, address)
    {
        require(onlineBatches[_gameId].closed == false, "OnlineCore: Game has closed already");
        checkParticipateThree(_gameId, _user);
        checkOptionInternal(_answer);
        onlineBatches[_gameId].playerTwo = _user;
        onlineBatches[_gameId].answerTwo = _answer;
        onlineBatches[_gameId].startTimeToProof = block.timestamp;

        return (onlineBatches[_gameId].bet, onlineBatches[_gameId].playerOne);  
    } 

    function finishOnlineGameEther(
        address _user, 
        uint _gameId, 
        uint _answer, 
        string memory _salt
    )
        external 
        onlineGameExist(_gameId) 
        onlyRole(ROUTER_CALLER) 
        returns(address, address, uint)
    {
        checkParticipateOne(_user, _gameId);
        checkClosed(_gameId);
        require(onlineBatches[_gameId].playerTwo != address(0), "OnlineCore: Player 2 is not set yet");
        require(onlineBatches[_gameId].startTimeToProof + PROOF_DURATION >= block.timestamp, "OnlineCore: Expired");
        checkOptionInternal(_answer);
        bytes32 answerHash = keccak256(abi.encode(_answer, _salt));
        require(answerHash == onlineBatches[_gameId].answerHash, "OnlineCore: Wrong answer hash");
        onlineBatches[_gameId].answerOne = _answer;
        address winner = checkWinnerInternal(
            onlineBatches[_gameId].playerOne, 
            _answer,
            onlineBatches[_gameId].playerTwo, 
            onlineBatches[_gameId].answerTwo
        );
        onlineBatches[_gameId].winner = winner;

        return (onlineBatches[_gameId].playerTwo, winner, onlineBatches[_gameId].bet);    
    }

    function refundBetFromExpiredOnlineGameEther(
        address _user, 
        uint _gameId
    )
        external 
        onlineGameExist(_gameId) 
        onlyRole(ROUTER_CALLER) 
        returns(address, uint)
    {
        checkParticipateTwo(_user, _gameId);
        checkClosed(_gameId);
        require(block.timestamp >= onlineBatches[_gameId].startTimeToProof + PROOF_DURATION, "OnlineCore: Not expired");
        onlineBatches[_gameId].winner = onlineBatches[_gameId].playerTwo;

        return (onlineBatches[_gameId].playerOne, onlineBatches[_gameId].bet);
    }

    function cancelOnlineGameEther(
        address _user, 
        uint _gameId
    )
        external 
        onlineGameExist(_gameId)
        onlyRole(ROUTER_CALLER) 
        returns(uint)
    {
        checkParticipateOne(_user, _gameId);
        checkClosed(_gameId);
        require(onlineBatches[_gameId].playerTwo == address(0), "OnlineCore: You are have opponent already");

        return onlineBatches[_gameId].bet; 
    }

    function createOnlineGameToken(
        address _user, 
        bytes32 _answerHash, 
        address _token, 
        uint _amount
    )
        external 
        onlyRole(ROUTER_CALLER) 
        returns(uint _gameId)
    {
        checkTokenAddress(_user, _token, _amount);
        onlineDefineData(_token, _user, _answerHash, _amount);
        _gameId = totalOnlineBatches;
        totalOnlineBatches += 1;   
    }

    function participateOnlineGameToken(
        address _user, 
        uint _gameId, 
        uint _answer
    )
        external 
        onlineGameExist(_gameId) 
        onlyRole(ROUTER_CALLER) 
        returns(uint bet, address, address)
    {
        address _token = onlineBatches[_gameId].token;
        bet = onlineBatches[_gameId].bet;
        require(IERC20(_token).balanceOf(_user) >= bet, "OnlineCore: Not enough tokens to bet");
        require(onlineBatches[_gameId].closed == false, "OnlineCore: Game has closed already");
        checkParticipateThree(_gameId, _user);
        checkOptionInternal(_answer);
        onlineBatches[_gameId].playerTwo = _user;
        onlineBatches[_gameId].answerTwo = _answer;
        onlineBatches[_gameId].startTimeToProof = block.timestamp;

        return (bet, onlineBatches[_gameId].playerOne, onlineBatches[_gameId].token);   
    }

    function finishOnlineGameToken(
        address _user, 
        uint _gameId, 
        uint _answer, 
        string memory _salt
    )
        external 
        onlineGameExist(_gameId) 
        onlyRole(ROUTER_CALLER) 
        returns(address winner, address, address, uint)
    {
        checkParticipateOne(_user, _gameId);
        checkClosed(_gameId);
        require(onlineBatches[_gameId].playerTwo != address(0), "OnlineCore: Player 2 is not set yet");
        require(onlineBatches[_gameId].startTimeToProof + PROOF_DURATION >= block.timestamp, "OnlineCore: Expired");
        checkOptionInternal(_answer);
        bytes32 answerHash = keccak256(abi.encode(_answer, _salt));
        require(answerHash == onlineBatches[_gameId].answerHash, "OnlineCore: Wrong answer hash");
        onlineBatches[_gameId].answerOne = _answer;
        winner = checkWinnerInternal(
            onlineBatches[_gameId].playerOne, 
            _answer,
            onlineBatches[_gameId].playerTwo, 
            onlineBatches[_gameId].answerTwo
        );
        onlineBatches[_gameId].winner = winner;

        return(winner, onlineBatches[_gameId].playerTwo, onlineBatches[_gameId].token, onlineBatches[_gameId].bet);   
    }

    function refundBetFromExpiredOnlineGameToken(
        address _user, 
        uint _gameId
    )
        external 
        onlineGameExist(_gameId) 
        onlyRole(ROUTER_CALLER) 
        returns(address, address, uint)
    {
        checkParticipateTwo(_user, _gameId);
        checkClosed(_gameId);
        require(block.timestamp >= onlineBatches[_gameId].startTimeToProof + PROOF_DURATION, "OnlineCore: Not expired");
        onlineBatches[_gameId].winner = onlineBatches[_gameId].playerTwo;

        return (onlineBatches[_gameId].playerOne, onlineBatches[_gameId].token, onlineBatches[_gameId].bet);
    }

    function cancelOnlineGameToken(
        address _user, 
        uint _gameId
    )
        external 
        onlineGameExist(_gameId) 
        onlyRole(ROUTER_CALLER) 
        returns(address, uint)
    {
        checkParticipateOne(_user, _gameId);
        checkClosed(_gameId);
        require(onlineBatches[_gameId].playerTwo == address(0), "OnlineCore: You are have opponent already");

        return(onlineBatches[_gameId].token, onlineBatches[_gameId].bet);
    }

    function checkWinnerInternal(address userOne, uint answerOne, address userTwo, uint answerTwo)internal pure returns(address winner){
        if(answerOne == answerTwo){ 
            return (address(0));
        } else {
            if(answerOne == OPTION_ROCK){
                if(answerTwo == OPTION_PAPER){
                    return userTwo;    
                } else {
                    return userOne;
                }
            }
            if(answerOne == OPTION_PAPER){
                if(answerTwo == OPTION_ROCK){
                    return userOne;
                } else {
                    return userTwo;
                }
            }
            if(answerOne == OPTION_SCISSORS){
                if(answerTwo == OPTION_ROCK){
                    return userTwo;
                } else {
                    return userOne;
                }
            }
        }    
    }

    function checkOptionInternal(uint _answer)internal pure {
        require(_answer == OPTION_ROCK || _answer == OPTION_PAPER || _answer == OPTION_SCISSORS, "OnlineCore: Choosed wrong option");
    }

    function checkClosed(uint _gameId)internal { 
        require(onlineBatches[_gameId].closed == false, "OnlineCore: Game has closed already");
        onlineBatches[_gameId].closed = true;
    }

    function checkParticipateOne(address _user, uint _gameId)internal view {
        require(onlineBatches[_gameId].playerOne == _user, "OnlineCore: You are not player of that game");
    }

    function checkParticipateTwo(address _user, uint _gameId)internal view {
        require(onlineBatches[_gameId].playerTwo == _user, "OnlineCore: You are not player of that game");
    }

    function checkParticipateThree(uint _gameId, address _user)internal view {
        require(onlineBatches[_gameId].playerOne != _user, "OnlineCore: You are player of that game already");
        require(onlineBatches[_gameId].playerTwo == address(0), "OnlineCore: Player two is set already");
    }

    function checkTokenAddress(address _user, address _token, uint _amount)internal view {
        require(_token != address(0), "OnlineCore: Zero adress");
        require(_amount >= MINIMAL_TOKEN_BET, "OnlineCore: Too small bet");
        require(IERC20(_token).balanceOf(_user) >= _amount, "OnlineCore: Not enough tokens");
    }

    function onlineDefineData(address _token, address _user, bytes32 _answerHash, uint _amount)internal {
        onlineBatches[totalOnlineBatches].id = totalOnlineBatches;
        onlineBatches[totalOnlineBatches].token = _token;
        onlineBatches[totalOnlineBatches].playerOne = _user;
        onlineBatches[totalOnlineBatches].answerHash = _answerHash;
        onlineBatches[totalOnlineBatches].bet = _amount;
    }
}
