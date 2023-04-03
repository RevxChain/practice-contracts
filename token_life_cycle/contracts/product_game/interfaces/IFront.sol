// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFront {

    function ownerBuildedSupply(address _who)external view returns(uint);

    function mintStructure(uint _type, uint _landId)external;

    function setToPlace(uint _id)external;

    function buildFinish(uint _id)external;

    function startWork(uint _id)external;

    function claim(uint _id)external;

    function destroy(uint _id)external;

    function upgradeToWorkers(uint _id)external;

    function upgradeToTechnologists(uint _id)external;

    function createShip(uint _shipyardId, uint _type, string memory _name)external;       
    
    function finishShip(uint _shipyardId, uint _shipId)external;

    function sellStructure(uint _id, uint _price)external;

    function buyStructure(uint _id)external payable;

    function cancelSellStructure(uint _id)external;

    function unbanStructureBargain(uint _id)external; 
    
}
