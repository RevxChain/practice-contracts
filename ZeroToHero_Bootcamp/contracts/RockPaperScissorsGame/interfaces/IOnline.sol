// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IOnline{

    function createOnlineGameEther(address user, bytes32 answerHash, uint bet)external returns(uint gameId);

    function participateOnlineGameEther(address userTwo, uint gameId, uint answer)external returns(uint bet, address userOne);

    function finishOnlineGameEther(address user, uint gameId, uint answer, string memory salt)external returns(address userTwo, address winner, uint bet);

    function refundBetFromExpiredOnlineGameEther(address user, uint gameId)external returns(address userOne, uint bet);

    function cancelOnlineGameEther(address user, uint gameId)external returns(uint bet);

    function createOnlineGameToken(address user, bytes32 answerHash, address token, uint amount)external returns(uint gameId);

    function participateOnlineGameToken(address user, uint gameId, uint answer)external returns(uint bet, address userOne, address token);

    function finishOnlineGameToken(address user, uint gameId, uint answer, string memory salt)external returns(address winner, address userTwo, address token, uint bet);

    function refundBetFromExpiredOnlineGameToken(address user, uint gameId)external returns(address userOne, address token, uint bet);

    function cancelOnlineGameToken(address user, uint gameId)external returns(address token, uint bet);
}
