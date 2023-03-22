// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IOracle.sol";

contract SoloCore is AccessControl{
    uint public totalSoloBatches;  
    
    uint public constant OPTION_ROCK = 0;
    uint public constant OPTION_PAPER = 1;
    uint public constant OPTION_SCISSORS = 2;
    uint public constant MINIMAL_TOKEN_BET = 1e18;
    uint public constant PROOF_DURATION = 3 days;

    address public router;
    address public oracle; 

    bytes32 public constant DISPOSABLE_CALLER = keccak256(abi.encode("DISPOSABLE_CALLER"));
    bytes32 public constant ROUTER_CALLER = keccak256(abi.encode("ROUTER_CALLER"));

    mapping(uint => soloBatch) public soloBatches;

    modifier soloGameExist(uint _gameId){
        require(totalSoloBatches > _gameId, "SoloCore: That game ID is not exist");
        _;
    }

    struct soloBatch{
        uint id;
        uint oracleRequestId;
        address token;
        address playerOne; 
        uint answerOne;
        address playerTwo; 
        uint answerTwo;
        uint bet;
        address winner;
        bool closed;
    }

    constructor(){
        _setupRole(DISPOSABLE_CALLER, msg.sender);
    }

    function setAddresses(address _router, address _oracle)external onlyRole(DISPOSABLE_CALLER){
        router = _router;
        oracle = _oracle;
        _setupRole(ROUTER_CALLER, router); 
    }

    function createSoloGameEther(address _user, uint _answer, uint _bet)external onlyRole(ROUTER_CALLER) returns(uint _gameId){ 
        checkOptionInternal(_answer);
        uint _oracleRequestId = IOracle(oracle).requestRandomWords();
        soloDefineData(_oracleRequestId, address(0), _user, _answer, _bet);
        _gameId = totalSoloBatches;
        totalSoloBatches += 1;
    }

    function finishSoloGameEther(
        address _user, 
        uint _gameId
    )
        external 
        soloGameExist(_gameId) 
        onlyRole(ROUTER_CALLER) 
        returns(address _winner, uint _bet)
    {
        checkParticipateOne(_user, _gameId);
        checkClosed(_gameId);
        (bool fullfilled, uint256[] memory randomWords) = IOracle(oracle).getRequestStatus(soloBatches[_gameId].oracleRequestId);
        require(fullfilled == true, "SoloCore: Too soon");
        uint answerTwo = randomWords[0] % 3;
        soloBatches[_gameId].answerTwo = answerTwo;
        _bet = soloBatches[_gameId].bet;
        _winner = checkWinnerInternal(_user, soloBatches[_gameId].answerOne, address(this), answerTwo);
        soloBatches[_gameId].winner = _winner;
    }

    function createSoloGameToken(
        address _user,
        uint _answer, 
        address _token, 
        uint _amount
    )
        external 
        onlyRole(ROUTER_CALLER) 
        returns(uint _gameId)
    {
        checkTokenAddress(_user, _token, _amount);
        checkOptionInternal(_answer);
        uint _oracleRequestId = IOracle(oracle).requestRandomWords();
        soloDefineData(_oracleRequestId, _token, _user, _answer, _amount);
        _gameId = totalSoloBatches;
        totalSoloBatches += 1;
    }

    function finishSoloGameToken(
        address _user, 
        uint _gameId
    )
        external 
        soloGameExist(_gameId) 
        onlyRole(ROUTER_CALLER) 
        returns(address _winner, address _token, uint _bet)
    {
        checkParticipateOne(_user, _gameId);
        checkClosed(_gameId);
        (bool fullfilled, uint256[] memory randomWords) = IOracle(oracle).getRequestStatus(soloBatches[_gameId].oracleRequestId);
        require(fullfilled == true, "SoloCore: Too soon");
        uint answerTwo = randomWords[0] % 3;
        soloBatches[_gameId].answerTwo = answerTwo;
        _winner = checkWinnerInternal(_user, soloBatches[_gameId].answerOne, address(this), answerTwo);
        soloBatches[_gameId].winner = _winner;     
        _bet = soloBatches[_gameId].bet;
        _token = soloBatches[_gameId].token;
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
        require(_answer == OPTION_ROCK || _answer == OPTION_PAPER || _answer == OPTION_SCISSORS, "SoloCore: Choosed wrong option");
    }

    function checkClosed(uint _gameId)internal { 
        require(soloBatches[_gameId].closed == false, "SoloCore: Game is closed already");
        soloBatches[_gameId].closed = true;
    }

    function checkParticipateOne(address _user, uint _gameId)internal view {
        require(soloBatches[_gameId].playerOne == _user, "SoloCore: You are not player of that game");
    }

    function checkTokenAddress(address _user, address _token, uint _amount)internal view {
        require(_token != address(0), "SoloCore: Zero adress");
        require(_amount >= MINIMAL_TOKEN_BET, "SoloCore: Too small bet");
        require(IERC20(_token).balanceOf(_user) >= _amount, "SoloCore: Not enough tokens");
    }

    function soloDefineData(uint _oracleRequestId, address _token, address _user, uint _answer, uint _amount)internal {
        soloBatches[totalSoloBatches].id = totalSoloBatches;
        soloBatches[totalSoloBatches].oracleRequestId = _oracleRequestId;
        soloBatches[totalSoloBatches].token = _token;
        soloBatches[totalSoloBatches].playerOne = _user;
        soloBatches[totalSoloBatches].answerOne = _answer;
        soloBatches[totalSoloBatches].playerTwo = address(this);
        soloBatches[totalSoloBatches].bet = _amount;
    }
}
