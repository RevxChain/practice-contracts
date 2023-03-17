// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IGame{

    function createSoloGameEther(uint answer)external payable returns(uint gameId);

    function finishSoloGameEther(uint gameId)external;

    function forceFinishSoloGameEther(uint gameId, address user)external;

    function createSoloGameToken(uint answer, address token, uint amount)external returns(uint gameId);

    function finishSoloGameToken(uint gameId)external;

    function forceFinishSoloGameToken(uint gameId, address user)external;

    function createOnlineGameEther(bytes32 answerHash)external payable returns(uint gameId);

    function participateOnlineGameEther(uint gameId, uint answer)external payable;

    function finishOnlineGameEther(uint gameId, uint answer, string memory salt)external;

    function refundBetFromExpiredOnlineGameEther(uint gameId)external;

    function cancelOnlineGameEther(uint gameId)external;

    function createOnlineGameToken(bytes32 answerHash, address token, uint amount)external returns(uint gameId);

    function participateOnlineGameToken(uint gameId, uint answer)external;

    function finishOnlineGameToken(uint gameId, uint answer, string memory salt)external;

    function refundBetFromExpiredOnlineGameToken(uint gameId)external;

    function cancelOnlineGameToken(uint gameId)external; 

    function fillEtherRewardPool()external payable;

    function fillTokenRewardPool(address token, uint amount)external;

    function withdrawEther(uint amount)external;

    function withdrawToken(address token, uint amount)external;

    function createHash(uint answer, string memory salt)external pure returns(bytes32 hash);

    function soloCore()external view returns(address);

    function onlineCore()external view returns(address);

}
