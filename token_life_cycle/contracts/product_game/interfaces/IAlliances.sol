// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IAlliances{

    function createAlliance(string memory _name, uint _landId)external;

    function joinToAlliance(uint _allianceId, uint _landId)external;

    function abandonAlliance()external;

    function createProposal(address _aimToKick, uint _allianceId)external;
        
    function confirmProposal(uint _id)external;

    function memberStatus(address _who)external returns(bool);

    function allianceStatus(address _who)external returns(uint _allianceId);

    function _returnShipFromWar(address _who, uint _lostPower)external;

    function _changeNumberOfLands(address _seller, address _buyer)external;

    function _joinToWar(address _who, uint _shipId, uint _shipPower)external;
    
}
