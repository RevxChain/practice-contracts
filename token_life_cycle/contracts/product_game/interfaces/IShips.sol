// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IShips{

    function shipBuilded(uint _shipId)external view returns(bool);

    function startJourney(uint _shipId)external view returns(uint);

    function aimJourney(uint _shipId)external view returns(uint);

    function journey(uint _id, uint _toLandId)external;

    function finishJourney(uint _id)external;

    function joinToWar(uint _shipId)external;

    function returnShipFromWar(uint _shipId)external;

    function loadShip(uint _id, uint _resType, uint _value)external;

    function unloadShip(uint _id, uint _resType, uint _value)external;

    function _createShip(string memory _name, uint _type, address _who, uint shipyardId)external;

    function _finishShip(address _who, uint _shipyardId, uint _shipId)external;

}
