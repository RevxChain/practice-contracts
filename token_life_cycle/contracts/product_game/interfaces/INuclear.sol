// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface INuclear{

    function haveAllianceCore(uint _landId)external view returns(bool);

    function colonists(address _who, uint _landId)external view returns(uint _amount);

    function colonistsFree(address _who, uint _landId)external view returns(uint _amount);

    function haveRialto(address _who, uint _landId)external view returns(bool);

    function haveCathouse(address _who, uint _landId)external view returns(bool);

    function haveUniversity(address _who, uint _landId)external view returns(bool);

    function haveBank(address _who, uint _landId)external view returns(bool);

    function _createAllianceCheck(address _user, uint _landId)external;

    function _set(address _who, uint _landID, uint _type)external;

    function _work(address _who, uint _type, uint _landID)external;

    function _claimCheck(address _who, uint _type, uint _landID, address _landOwner)external;

    function _destroy(address _who, uint _type, uint _landID)external;

    function _upgradeToWorkers(address _who, uint _landID)external;

    function _upgradeToTechnologists(address _who, uint _landID)external;

    function _checkCreateShip(address _who, uint _locationId, uint _type, string memory _name)external;

    function _sellFactoryCheck(uint _type)external view;

    function _buyFactoryCheck(address _buyer, address _seller, uint _type, uint _landId)external;

}
