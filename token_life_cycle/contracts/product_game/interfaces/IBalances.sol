// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IBalances{

    function depositToken(uint _token, uint _value, uint _landId)external;

    function withdrawToken(uint _token, uint _value, uint _landId)external;

    function balances(address _who, uint _landId, uint _tokenId)external view returns(uint _amount);

    function shipBalances(address _who, uint _shipId, uint _tokenId)external view returns(uint _amount);

    function _mint(uint _type, address _who, uint _landID)external;

    function _claim(address _who, uint _type, uint _landID, address _landOwner, bool _ownerBank)external; 

    function _startWork(address _who, uint _type, uint _landID)external;

    function _destroyClaim(address _who, uint _type, uint _landID)external;

    function _upgradeToWork(address _who, uint _landID)external;

    function _upgradeToTech(address _who, uint _landID)external;

    function _mintShip(address _who, uint _landID, uint _shipType, string memory _name)external;

    function _createAlliance(address _who, uint _landId)external;

    function _loadShip(address _who, uint _shipId, uint _resType, uint _landId, uint _value)external;

    function _unloadShip(address _who, uint _shipId, uint _resType, uint _landId, uint _value)external;

    function _joinToAlliance(address _user, uint _landId)external;

}
