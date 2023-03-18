// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ISolo{

    function createSoloGameEther(address user, uint answer, uint bet)external returns(uint gameId);

    function finishSoloGameEther(address user, uint gameId)external returns(address winner, uint bet);

    function createSoloGameToken(address user, uint answer, address token, uint amount)external returns(uint gameId);

    function finishSoloGameToken(address user, uint gameId)external returns(address winner, address token, uint bet);

}
