// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILands.sol";
import "./interfaces/INuclear.sol";
import "./interfaces/IShips.sol";

contract Balances {
    uint public constant STORAGE = 20e18; 
    uint public constant FEE = 1e18;
    uint public constant DEPOSIT_FEE = 33; 

    address private dev;
    address private ships;
    address private nuclear;
    address private lands;

    mapping(address => uint) public goldBalance;
    mapping(address => mapping(uint => mapping(uint => uint))) public balances;
    mapping(address => mapping(uint => mapping(uint => uint))) public shipBalances;
    mapping(uint => uint) private plankCost;
    mapping(uint => uint) private fishCost;
    mapping(uint => uint) private brickCost;
    mapping(uint => uint) private steelCost;
    mapping(uint => uint) private liftCost;
    mapping(uint => uint) private meatCost;
    mapping(uint => uint) private rumCost;
    mapping(uint => uint) private goldCost;
    mapping(address => bool) private roleCall;
    mapping(uint => address) private tokenAddress;
    mapping(uint => uint) private structureResource;
    
    error NotEnoughResources();
    
    modifier onlyRole(address _caller){
        require (roleCall[_caller] == true, "1x00");
        _;
    }

    constructor(address[17] memory _addresses){
        for(uint i; i < _addresses.length; i++){
            tokenAddress[i] = _addresses[i];
        } 
        roleCall[msg.sender] = true;
        dev = msg.sender;
    }

    function setData(uint _type, uint[9] calldata _amounts)external onlyRole(msg.sender){
        plankCost[_type] = _amounts[0];
        fishCost[_type] = _amounts[1];
        brickCost[_type] = _amounts[2];
        steelCost[_type] = _amounts[3];
        liftCost[_type] = _amounts[4];
        meatCost[_type] = _amounts[5];
        rumCost[_type] = _amounts[6];
        goldCost[_type] = _amounts[7];
        structureResource[_type] = _amounts[8];
    }

    function setAddresses(address _ships, address _nuclear, address _lands)external onlyRole(msg.sender){
        ships = _ships;
        nuclear = _nuclear;
        lands = _lands;
    }

    function setRole(address _caller)external onlyRole(msg.sender){
        roleCall[_caller] = true;
    }

    function depositToken(uint _token, uint _value, uint _landId)external {
        require (ILands(lands).totalSupply() > _landId, "1x01");
        if (ILands(lands)._ownerCheck(_landId) != dev){
            require(INuclear(nuclear).haveAllianceCore(_landId) == true, "1x02");
        }
        IERC20(tokenAddress[_token]).transferFrom(msg.sender, address(this), _value);
        uint _fee = _value / DEPOSIT_FEE;
        if (INuclear(nuclear).haveAllianceCore(_landId) == true){
            if (_token == 17){
                goldBalance[ILands(lands)._ownerCheck(_landId)] += _fee;
                goldBalance[msg.sender] += _value - _fee;
            } else {
                balances[ILands(lands)._ownerCheck(_landId)][_landId][_token] += _fee;
                balances[msg.sender][_landId][_token] += _value - _fee;
            }
        } else {
            if (_token == 17) {
                goldBalance[msg.sender] += _value - _fee;
            } else {
                balances[msg.sender][_landId][_token] += _value - _fee;
            }        
        }
    }

    function withdrawToken(uint _token, uint _value, uint _landId)external {
        require (ILands(lands).totalSupply() > _landId, "1x01");
        if (_landId != 0){
            require(INuclear(nuclear).haveAllianceCore(_landId) == true, "1x03");
        }
        require(balances[msg.sender][_landId][_token] >= _value, "1x04");
        IERC20(tokenAddress[_token]).transfer(msg.sender, _value);
        if (_token == 17){
            goldBalance[msg.sender] -= _value;
        } else {
            balances[msg.sender][_landId][_token] -= _value;
        }       
    }

    function _mint(uint _type, address _who, uint _landID)external onlyRole(msg.sender){
        if (balances[_who][_landID][2] < plankCost[_type]){revert NotEnoughResources();}
        if (balances[_who][_landID][3] < fishCost[_type]){revert NotEnoughResources();}
        if (balances[_who][_landID][5] < brickCost[_type]){revert NotEnoughResources();}
        if (balances[_who][_landID][8] < steelCost[_type]){revert NotEnoughResources();}
        if (balances[_who][_landID][9] < liftCost[_type]){revert NotEnoughResources();}
        if (balances[_who][_landID][10] < meatCost[_type]){revert NotEnoughResources();}
        if (balances[_who][_landID][12] < rumCost[_type]){revert NotEnoughResources();}
        if (goldBalance[_who] < goldCost[_type]){revert NotEnoughResources();}
        balances[_who][_landID][2] -= plankCost[_type];
        balances[_who][_landID][3] -= fishCost[_type];
        balances[_who][_landID][5] -= brickCost[_type];
        balances[_who][_landID][8] -= steelCost[_type];
        balances[_who][_landID][9] -= liftCost[_type];
        balances[_who][_landID][10] -= meatCost[_type];
        balances[_who][_landID][12] -= rumCost[_type];
        goldBalance[_who] -= goldCost[_type];
    }

    function _startWork(address _who, uint _type, uint _landID)external onlyRole(msg.sender){
        if (_type == 3) {
            balances[_who][_landID][1] -= STORAGE;
        }
        if (_type == 6) {
            balances[_who][_landID][3] -= STORAGE;
            balances[_who][_landID][4] -= STORAGE;
        }
        if (_type == 11) {
            balances[_who][_landID][3] -= STORAGE;
            balances[_who][_landID][6] -= STORAGE;
            balances[_who][_landID][7] -= STORAGE;
        }
        if (_type == 14) {
            balances[_who][_landID][2] -= STORAGE;
            balances[_who][_landID][3] -= STORAGE;
            balances[_who][_landID][5] -= STORAGE;
            balances[_who][_landID][8] -= STORAGE;
        }
        if (_type == 15) {
            balances[_who][_landID][6] -= STORAGE;
        }
        if (_type == 19) {
            balances[_who][_landID][2] -= STORAGE;
            balances[_who][_landID][9] -= STORAGE;
            balances[_who][_landID][10] -= STORAGE;
            balances[_who][_landID][11] -= STORAGE;          
        }
        if (_type == 21) {
            balances[_who][_landID][2] -= STORAGE;
            balances[_who][_landID][8] -= STORAGE;
            balances[_who][_landID][10] -= STORAGE;
            balances[_who][_landID][13] -= STORAGE;          
        }
        if (_type == 24) {
            balances[_who][_landID][7] -= STORAGE;
            balances[_who][_landID][10] -= STORAGE;
            balances[_who][_landID][15] -= STORAGE;          
        }
        if (_type == 25) {
            balances[_who][_landID][7] -= STORAGE;
            balances[_who][_landID][9] -= STORAGE;
            balances[_who][_landID][10] -= STORAGE;
            balances[_who][_landID][14] -= STORAGE;
            balances[_who][_landID][16] -= STORAGE;      
        }
    }

    function _claim(address _who, uint _type, uint _landID, address _landOwner, bool _ownerBank)external onlyRole(msg.sender){
        if (_ownerBank == true){
            if (_type == 25){
                goldBalance[_who] += STORAGE - FEE;
                goldBalance[_landOwner] += FEE;
            } else {
                balances[_who][_landID][structureResource[_type]] += STORAGE - FEE;
                balances[_landOwner][_landID][structureResource[_type]] += FEE;
            }           
        } else {
            if (_type == 25) {
                goldBalance[_who] += STORAGE;
            } else {
                balances[_who][_landID][structureResource[_type]] += STORAGE;
            }   
        }    
    }

    function _destroyClaim(address _who, uint _type, uint _landID)external onlyRole(msg.sender){
        balances[_who][_landID][2] += plankCost[_type]/5;
        balances[_who][_landID][3] += fishCost[_type]/5;
        balances[_who][_landID][5] += brickCost[_type]/5;
        balances[_who][_landID][8] += steelCost[_type]/5;
        balances[_who][_landID][9] += liftCost[_type]/5;
        balances[_who][_landID][10] += meatCost[_type]/5;
        balances[_who][_landID][12] += rumCost[_type]/5;       
    }

    function _upgradeToWork(address _who, uint _landID)external onlyRole(msg.sender){
        balances[_who][_landID][2] -= 10e18;
        balances[_who][_landID][3] -= 8e18;
        balances[_who][_landID][5] -= 6e18;
        goldBalance[_who] -= 4e18;
    }

    function _upgradeToTech(address _who, uint _landID)external onlyRole(msg.sender){
        balances[_who][_landID][2] -= 15e18;
        balances[_who][_landID][3] -= 12e18;
        balances[_who][_landID][5] -= 10e18;
        balances[_who][_landID][8] -= 8e18;
        balances[_who][_landID][9] -= 6e18;
        balances[_who][_landID][10] -= 5e18;
        balances[_who][_landID][12] -= 3e18;
        goldBalance[_who] -= 8e18;
    }

    function _mintShip(address _who, uint _landID, uint _shipType, string memory _name)external onlyRole(msg.sender){
        if (_shipType == 1){
            balances[_who][_landID][2] -= 70e18; 
            balances[_who][_landID][3] -= 40e18;
            balances[_who][_landID][6] -= 25e18;
            balances[_who][_landID][8] -= 15e18;
            goldBalance[_who] -= 45e18;
        }
        if (_shipType == 2){
            balances[_who][_landID][2] -= 120e18;
            balances[_who][_landID][3] -= 60e18;
            balances[_who][_landID][6] -= 40e18;
            balances[_who][_landID][8] -= 35e18;
            goldBalance[_who] -= 90e18;
        }
        if (_shipType == 3){
            balances[_who][_landID][2] -= 140e18;
            balances[_who][_landID][3] -= 40e18;
            balances[_who][_landID][6] -= 50e18;
            balances[_who][_landID][8] -= 30e18;
            balances[_who][_landID][10] -= 25e18;
            goldBalance[_who] -= 130e18;
        }
        if (_shipType == 4){
            balances[_who][_landID][2] -= 250e18;
            balances[_who][_landID][3] -= 200e18;
            balances[_who][_landID][6] -= 140e18;
            balances[_who][_landID][8] -= 100e18;
            balances[_who][_landID][10] -= 70e18;
            balances[_who][_landID][12] -= 100e18;
            goldBalance[_who] -= 350e18;
        }
        IShips(ships)._createShip(_name, _shipType, _who, _landID);
    }

    function _loadShip(address _who, uint _shipId, uint _resType, uint _landId, uint _value)external onlyRole(msg.sender){
        balances[_who][_landId][_resType] -= _value;
        shipBalances[_who][_shipId][_resType] += _value;
    }

    function _unloadShip(address _who, uint _shipId, uint _resType, uint _landId, uint _value)external onlyRole(msg.sender){
        shipBalances[_who][_shipId][_resType] -= _value;
        balances[_who][_landId][_resType] += _value;     
    }

    function _createAlliance(address _who, uint _landId)external onlyRole(msg.sender){
        balances[_who][_landId][2] -= 100e18;
        balances[_who][_landId][3] -= 50e18;
        balances[_who][_landId][8] -= 50e18;
        balances[_who][_landId][10] -= 30e18;
        goldBalance[_who] -= 200e18;
    }

    function _joinToAlliance(address _who, uint _landId)external onlyRole(msg.sender){
        balances[_who][_landId][2] -= 20e18;
        balances[_who][_landId][3] -= 10e18;
        balances[_who][_landId][8] -= 10e18;
        goldBalance[_who] -= 10e18;
    }
}
