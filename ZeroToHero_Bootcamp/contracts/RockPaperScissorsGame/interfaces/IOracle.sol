// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IOracle{

    function requestRandomWords()external returns(uint256 requestId);

    function getRequestStatus(uint256 requestId)external view returns(bool fulfilled, uint256[] memory randomWords);

}
