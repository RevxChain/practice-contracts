// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./interfaces/IBalances.sol";
import "./interfaces/ILands.sol";
import "./interfaces/INuclear.sol";
import "./interfaces/IShips.sol";

contract Front { 
    
    uint public PRODUCTION_TIME = 2 hours; 
    uint public BUILDING_TIME = 3 hours; 
    uint public SHIP_BUILDING_TIME = 1 hours; 
    uint public CRUISER_SHIP_EXTRA_BUILDING_TIME = 2 hours;
    uint private idList;

    uint private constant STRUCTURE_BARGAIN_BAN_DURATION = 1 days; 

    address private balances;
    address private nuclear;
    address private lands;
    address private ships;

    mapping(address => uint) public ownerBuildedSupply;
    mapping(uint => uint) private shipType;
    mapping(address => bool) private roleCall;
    mapping(uint => uint) private structurePrice;
    mapping(uint => uint) private shipBuildStart;
    mapping(uint => uint) private structureWorkTime;
    mapping(uint => address) private structureSeller;
    mapping(uint => bool) private structureBargainBan;
    mapping(uint => uint) private structureStartBuildTime;
    mapping(uint => uint) private structureBargainBanStart;

    event mintTheStructure(address indexed _who, uint _id, uint _type, uint indexed _land);
    event buildedTheStructure(address indexed _who, uint _id, uint indexed _land);
    event tradeTheStructure(address indexed _buyer, address indexed _seller, uint _id, uint indexed _land);

    modifier onlyRole(address _caller){
        require (roleCall[_caller] == true, "5x00");
        _;
    }

    modifier onlyOwner(uint _id) {
        require (structures[_id].owner == msg.sender, "5x01");
        _;
    }

    modifier idExist(uint _id) {
        require (_id < idList, "5x02");
        _;
    }

    modifier idBuilded(uint _id) {
        require (structures[_id].builded == true, "5x03");
        _;
    }

    Structure[] public structures;

    struct Structure {
        uint id;
        address owner;
        uint typeId;
        uint landId;
        bool builded;
        bool work;
        bool bargain;
        bool destroyed;
    }

    constructor (){
        roleCall[msg.sender] = true;
    }

    function setRole(address _caller)external onlyRole(msg.sender){
        roleCall[_caller] = true;
    }

    function setAddresses(address _balances, address _nuclear, address _lands, address _ships)external onlyRole(msg.sender){
        balances = _balances;
        nuclear = _nuclear;
        lands = _lands;
        ships = _ships;
    }

    function mintStructure(uint _type, uint _landId)external {
        require (_type != 8, "5x29");
        require (_type != 17, "5x30");
        address _who = msg.sender;
        IBalances(balances)._mint(_type, _who, _landId);
        Structure memory structure = Structure(idList, _who, _type, _landId, false, false, false, false); 
        structures.push(structure); 
        idList +=1;      

        emit mintTheStructure( _who, idList -1, _type, _landId);
    }

    function setToPlace(uint _id)external onlyOwner(_id) idExist(_id){
        require(structureStartBuildTime[_id] == 0, "5x04");
        require(structures[_id].builded == false, "5x05");
        address _who = msg.sender;
        structureStartBuildTime[_id] = block.timestamp;
        INuclear(nuclear)._set(_who, structures[_id].landId, structures[_id].typeId);
    }

    function buildFinish(uint _id)external onlyOwner(_id) idExist(_id){
        require(structures[_id].builded == false, "5x05");
        require((block.timestamp - structureStartBuildTime[_id]) >= BUILDING_TIME, "5x06");
        require(structureStartBuildTime[_id] > 0, "5x07");
        structures[_id].builded = true;
        structureStartBuildTime[_id] = 0;
        ownerBuildedSupply[msg.sender] += 1;

        emit buildedTheStructure(msg.sender, _id, structures[_id].landId);
    }

    function startWork(uint _id)external onlyOwner(_id) idExist(_id) idBuilded(_id){
        require (structures[_id].work == false, "5x08");
        require (structures[_id].bargain == false, "5x09");
        address _who = msg.sender;
        INuclear(nuclear)._work( _who, structures[_id].typeId, structures[_id].landId);
        structureWorkTime[_id] = block.timestamp;
        structures[_id].work = true;
    }

    function claim(uint _id)external onlyOwner(_id) idExist(_id){
        require (structures[_id].work == true, "5x10");
        require ((block.timestamp - structureWorkTime[_id]) >= PRODUCTION_TIME, "5x11");
        address _who = msg.sender;  
        address _landOwner = ILands(lands)._ownerCheck(structures[_id].landId);
        INuclear(nuclear)._claimCheck(_who, structures[_id].typeId, structures[_id].landId, _landOwner);       
        structures[_id].work = false;   
    }

    function destroy(uint _id)external onlyOwner(_id) idExist(_id) idBuilded(_id){
        require (structures[_id].bargain == false, "5x12");
        require (structures[_id].work == false, "5x08");
        address _who = msg.sender;
        INuclear(nuclear)._destroy(_who, structures[_id].typeId, structures[_id].landId);
        structures[_id].owner = address(0);
        structures[_id].destroyed = true;
        ownerBuildedSupply[_who] -= 1;
    }

    function upgradeToWorkers(uint _id)external onlyOwner(_id) idExist(_id) idBuilded(_id){
        require (structures[_id].typeId == 1, "5x13");
        address _who = msg.sender;
        INuclear(nuclear)._upgradeToWorkers(_who, structures[_id].landId);
        structures[_id].typeId = 8;
    }

    function upgradeToTechnologists(uint _id)external onlyOwner(_id) idExist(_id) idBuilded(_id){
        require (structures[_id].typeId == 8, "5x14");
        address _who = msg.sender;
        INuclear(nuclear)._upgradeToTechnologists(_who, structures[_id].landId);
        structures[_id].typeId = 17;
    }

    function createShip(uint _shipyardId, uint _type, string memory _name)external onlyOwner(_shipyardId) idBuilded(_shipyardId){
        require(_type != 0, "5x15");
        require(_type <= 4, "5x15");
        require(structures[_shipyardId].typeId == 12, "5x16");
        require(structures[_shipyardId].bargain == false, "5x17");
        require(structures[_shipyardId].work == false, "5x18");       
        address _who = msg.sender;
        INuclear(nuclear)._checkCreateShip(_who, _shipyardId, _type, _name);
        structures[_shipyardId].work = true;
        shipBuildStart[_shipyardId] = block.timestamp;       
        if (_type == 4){
            shipBuildStart[_shipyardId] = block.timestamp + CRUISER_SHIP_EXTRA_BUILDING_TIME;
        }        
    }

    function finishShip(uint _shipyardId, uint _shipId)external onlyOwner(_shipyardId) idBuilded(_shipyardId){
        require(structures[_shipyardId].typeId == 12, "5x16");
        require(structures[_shipyardId].work == true, "5x19"); 
        require((shipBuildStart[_shipyardId] + SHIP_BUILDING_TIME) >= block.timestamp, "5x20");
        address _who = msg.sender;
        IShips(ships)._finishShip(_who, _shipyardId, _shipId);
        structures[_shipyardId].work = false;
        shipBuildStart[_shipyardId] = block.timestamp;
    }

    function sellStructure(uint _id, uint _price)external onlyOwner(_id) idExist(_id){
        require(structures[_id].work == false, "5x21");
        require(structureBargainBan[_id] == false, "5x22");
        require(structures[_id].bargain == false, "5x23");
        INuclear(nuclear)._sellFactoryCheck(structures[_id].typeId);
        structures[_id].bargain = true;
        structurePrice[_id] = _price;
        structureSeller[_id] = msg.sender; 
    }

    function buyStructure(uint _id)external payable idExist(_id){
        require(structures[_id].bargain == true, "5x24");
        require(msg.value == structurePrice[_id], "5x25");
        address _buyer = msg.sender;
        address payable _seller = payable(structureSeller[_id]);
        INuclear(nuclear)._buyFactoryCheck(_buyer, _seller, structures[_id].typeId, structures[_id].landId);
        (_seller).transfer(structurePrice[_id]);
        structures[_id].owner = _buyer;
        ownerBuildedSupply[_seller] -= 1;
        ownerBuildedSupply[_buyer] += 1;
        structures[_id].bargain = false;
        structureBargainBan[_id] = true;
        structureBargainBanStart[_id] = block.timestamp;

        emit tradeTheStructure(_buyer, _seller, _id, structures[_id].landId);
    }

    function cancelSellStructure(uint _id)external onlyOwner(_id) idExist(_id){
        require(structures[_id].bargain == true, "5x26");
        structures[_id].bargain = false;
    }

    function unbanStructureBargain(uint _id)external onlyOwner(_id) idExist(_id){
        require(structureBargainBan[_id] == true, "5x27");
        require(block.timestamp >= (structureBargainBanStart[_id] + STRUCTURE_BARGAIN_BAN_DURATION), "5x28");
        structureBargainBan[_id] = false;
    } 

    function changeParameter(uint _parameterId, uint _newValue)external onlyRole(msg.sender){
        if(_parameterId == 0){
            PRODUCTION_TIME = _newValue;
        }
        if(_parameterId == 1){
            BUILDING_TIME = _newValue;
        }
        if(_parameterId == 2){
            SHIP_BUILDING_TIME = _newValue;
        }
        if(_parameterId == 3){
            CRUISER_SHIP_EXTRA_BUILDING_TIME = _newValue;
        }
    } 
}
