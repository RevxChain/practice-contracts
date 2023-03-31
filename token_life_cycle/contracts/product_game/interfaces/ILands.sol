// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ILands{
    
    function locationCheck(uint _x, uint _y)external view returns(bool); 

    function totalSupply()external view returns(uint);

    function warNow()external view returns(bool);

    function warLandNow()external view returns(uint);  

    function landsSupply()external view returns(uint);

    function ownerLandSupply(address _user)external view returns(uint); 

    function sellLand(uint _id, uint _price)external;

    function buyLand(uint _id)external payable;

    function cancelSellLand(uint _id)external;

    function unbanLandBargain(uint _id)external;

    function _resultWar(address _winner)external;

    function _ownerCheck(uint _id)external view returns(address);

    function _spaceCheck(address _who, uint _landID, uint _size, uint _slot)external returns(bool);

    function _spaceDisengage(uint _landID, uint _space, uint _slot)external;

    function _startWorkCheckGold(address _who, uint _landId)external view;

    function _locationCheckX(uint _id)external view returns(uint);

    function _locationCheckY(uint _id)external view returns(uint);

}
