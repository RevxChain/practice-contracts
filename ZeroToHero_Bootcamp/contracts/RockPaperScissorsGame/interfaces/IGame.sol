// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IGame{

    function createSoloGameBNB(uint answer)external payable returns(uint gameId);

    function finishSoloGameBNB(uint gameId)external;

    function forceFinishSoloGameBNB(uint gameId, address user)external;

    function createSoloGameToken(uint answer, address token, uint amount)external returns(uint gameId);

    function finishSoloGameToken(uint gameId)external;

    function forceFinishSoloGameToken(uint gameId, address user)external;

    function createOnlineGameBNB(bytes32 answerHash)external payable returns(uint gameId);

    function participateOnlineGameBNB(uint gameId, uint answer)external payable;

    function finishOnlineGameBNB(uint gameId, uint answer, string memory salt)external;

    function refundBetFromExpiredOnlineGameBNB(uint gameId)external;

    function cancelOnlineGameBNB(uint gameId)external;

    function createOnlineGameToken(bytes32 answerHash, address token, uint amount)external returns(uint gameId);

    function participateOnlineGameToken(uint gameId, uint answer)external;

    function finishOnlineGameToken(uint gameId, uint answer, string memory salt)external;

    function refundBetFromExpiredOnlineGameToken(uint gameId)external;

    function cancelOnlineGameToken(uint gameId)external;

    function fillBNBRewardPool()external payable;

    function fillTokenRewardPool(address token, uint amount)external;

    function withdrawBNB(uint amount)external;

    function withdrawToken(address token, uint amount)external;

    function createHash(uint answer, string memory salt)external pure returns(bytes32 hash);

    function soloCore()external view returns(address);

    function onlineCore()external view returns(address);

}
