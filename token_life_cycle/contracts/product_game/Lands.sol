// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./interfaces/IAlliances.sol";
import "./interfaces/INuclear.sol";

contract Lands { 

    uint public totalSupply;
    uint public warLandNow;

    uint public constant WAR_DURATION = 1 days;
    uint public constant POST_WAR_DURATION = 12 hours;
    uint private constant STORAGE = 20e18;
    uint private constant LAND_BARGAIN_BAN_DURATION = 3 days;
    uint private constant LAND_WAR_BAN_DURATION = 1 days;
    
    bool public warNow;  

    address private nuclear;
    address private alliances;

    mapping(address => uint) public ownerLandSupply;
    mapping(uint => mapping(uint => bool)) public locationCheck;
    mapping(uint => uint) private warStart;
    mapping(uint => uint) private landPrice;
    mapping(uint => bool) private warStatus;
    mapping(address => bool) private roleCall;
    mapping(uint => bool) private landBargain;
    mapping(uint => address) private landSeller;
    mapping(uint => bool) private landBargainBan;
    mapping(uint => uint) private landBargainBanStart;

    event openTheLand(uint indexed _landId, uint indexed _dataX, uint indexed _dataY, uint _time);
    event conquerTheLand(address indexed _who, uint _landId, uint _time);
    event tradeTheLand(address indexed _buyer, address indexed _seller, uint _id, uint _time);

    modifier onlyRole(address _caller){
        require (roleCall[_caller] == true, "2x00");
        _;
    }

    modifier onlyOwner(address _who, uint _id){
        require (_who == lands[_id].owner, "2x01");
        _;
    }

    modifier idExist(uint _id) {
        require (_id < totalSupply, "2x02");
        _;
    }

    Land[] public lands;

    struct Land {
        uint id;
        string name;
        address owner;
        uint locationX;
        uint locationY;
        uint space;
        uint freeSpace;
        uint fishSlot;
        uint mineSlot;
        uint shipSlot;
        uint goldAmount;
        uint goldPersonalAmount;
    }

    constructor(){
        roleCall[msg.sender] = true;
    }

    function createLand(   
        string memory _name, 
        uint _dataX, 
        uint _dataY, 
        uint _space, 
        uint _fishSlot, 
        uint _mineSlot,
        uint _shipSlot,
        uint _goldAmount,
        uint _goldPersonalAmount
    ) 
        external 
        onlyRole(msg.sender)
    {
        require (locationCheck[_dataX][_dataY] == false, "2x25");
        Land memory land = Land(
            totalSupply, 
            _name, 
            msg.sender, 
            _dataX, 
            _dataY, 
            _space,
            _space, 
            _fishSlot, 
            _mineSlot, 
            _shipSlot, 
            _goldAmount, 
            _goldPersonalAmount
        ); 
        lands.push(land); 
        locationCheck[_dataX][_dataY] = true;
        ownerLandSupply[msg.sender] += 1;
        totalSupply += 1;

        emit openTheLand(totalSupply - 1, _dataX, _dataY, block.timestamp);
    }

    function setRole(address _caller)external onlyRole(msg.sender){
        roleCall[_caller] = true;
    }

    function setAddresses(address _nuclear, address _alliances)external onlyRole(msg.sender){
        nuclear = _nuclear;
        alliances = _alliances;
    }

    function startWar(uint _landId)external onlyRole(msg.sender){
        require(warNow == false, "2x03");
        require(_landId + 1 == totalSupply, "2x04");
        require(warStatus[_landId] == false, "2x03");
        require(lands[_landId].owner == msg.sender, "2x26");
        warNow = true;
        warLandNow = _landId;
        warStatus[_landId] = true;
        warStart[_landId] = block.timestamp;
    } 

    function finishWar()external onlyRole(msg.sender){
        require(warNow == true, "2x05");
        require(block.timestamp >= (warStart[warLandNow] + WAR_DURATION), "2x06");
        warNow = false;
        warLandNow = 0;
        warStatus[warStart[warLandNow]] = false;
        warStart[warStart[warLandNow]] = 0;
    }

    function sellLand(uint _id, uint _price)external onlyOwner(msg.sender,  _id) idExist(_id){
        require(landBargainBan[_id] ==false, "2x07");
        require(landBargain[_id] == false, "2x08");
        require(INuclear(nuclear).haveAllianceCore(_id) == false, "2x09");
        require(block.timestamp >= (warStart[_id] + WAR_DURATION + POST_WAR_DURATION + LAND_WAR_BAN_DURATION), "2x10");
        landBargain[_id] = true;
        landPrice[_id] = _price;
        landSeller[_id] = msg.sender;
    }

    function buyLand(uint _id)external payable idExist(_id){
        require(landBargain[_id] == true, "2x11");
        require(msg.value == landPrice[_id], "2x12");
        address _buyer = msg.sender;
        address payable _seller = payable(landSeller[_id]);
        IAlliances(alliances)._changeNumberOfLands(_seller, _buyer);
        (_seller).transfer(landPrice[_id]);
        lands[_id].owner = _buyer;
        ownerLandSupply[_seller] -= 1;
        ownerLandSupply[_buyer] += 1;
        landBargain[_id] = false;
        landBargainBan[_id] = true;
        landBargainBanStart[_id] = block.timestamp;

        emit tradeTheLand(_buyer, _seller, _id, block.timestamp);
    }

    function cancelSellLand(uint _id)external onlyOwner(msg.sender, _id) idExist(_id){
        require(landBargain[_id] == true, "2x13");
        landBargain[_id] = false;
    }

    function unbanLandBargain(uint _id)external onlyOwner(msg.sender, _id) idExist(_id){
        require(landBargainBan[_id] == true, "2x14");
        require(block.timestamp >= (landBargainBanStart[_id] + LAND_BARGAIN_BAN_DURATION), "2x15");
        landBargainBan[_id] = false;
    } 

    function _spaceCheck(address _who, uint _id, uint _space, uint _slot)external onlyRole(msg.sender) returns(bool result){
        require(lands[_id].freeSpace >= _space, "2x16");
        lands[_id].freeSpace -= _space;      
        if (_slot == 1){
            require(lands[_id].fishSlot >= 1, "2x17");
            lands[_id].fishSlot -=1;
        }
        if (_slot == 2){
            require(lands[_id].mineSlot >= 1, "2x18");
            lands[_id].mineSlot -=1;
        }
        if (_slot == 3){
            require(lands[_id].shipSlot >= 1, "2x19");
            lands[_id].shipSlot -=1;
        } 

        bool _check = IAlliances(alliances).memberStatus(_who);
        if (_check == true) {           
            if (lands[_id].owner == _who){
                result = true;
            }
        }
    }

    function _spaceDisengage(uint _id, uint _space, uint _slot)external onlyRole(msg.sender){
        require((lands[_id].freeSpace + _space) <= lands[_id].space, "2x20");
        lands[_id].freeSpace += _space;
        if (_slot == 1){
            lands[_id].fishSlot +=1;
        }
        if (_slot == 2){
            lands[_id].mineSlot +=1;
        }
        if (_slot == 3){
            lands[_id].shipSlot +=1;
        }
    }

    function _resultWar(address _winner)external onlyRole(msg.sender){
        require(warNow == false, "2x21");
        require(block.timestamp >= (warStart[totalSupply - 1] + WAR_DURATION + POST_WAR_DURATION), "2x22");
        lands[totalSupply - 1].owner = _winner;
        ownerLandSupply[_winner] += 1;

        emit conquerTheLand(_winner, totalSupply - 1,  block.timestamp);
    }

    function _startWorkCheckGold(address _who, uint _landId)external onlyRole(msg.sender){
        if (lands[_landId].owner == _who){
            require (lands[_landId].goldPersonalAmount >= STORAGE, "2x23");
            lands[_landId].goldPersonalAmount -= STORAGE;
        } else {
            require (lands[_landId].goldAmount >= STORAGE, "2x24");
            lands[_landId].goldAmount -= STORAGE;
        }       
    }

    function _locationCheckX(uint _id)external view returns(uint){
        return lands[_id].locationX;
    }

    function _locationCheckY(uint _id)external view returns(uint){
        return lands[_id].locationY;
    }

    function _ownerCheck(uint _id)external view returns(address){
        return lands[_id].owner;
    }
}
