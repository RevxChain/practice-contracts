// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./interfaces/IBalances.sol";
import "./interfaces/ILands.sol";
import "./interfaces/INuclear.sol";

contract Alliances { 
    uint public totalSupply;
    uint public allianceWinner;
    uint private totalProposals;
    uint private allianceWinnerPower;
    uint private memberWinnerLostPower;

    uint private constant RESIDENCE_TIME_TO_VOTE = 7 days;
    uint private constant PROPOSAL_LIFE_TIME = 3 days;

    bool public warResultingStatus;

    address public memberWinner;
    address private lands;
    address private balances;
    address private nuclear;

    mapping(address => bool) public memberStatus;
    mapping(address => uint) public allianceStatus;
    mapping(address => bool) private roleCall;
    mapping(uint => uint) private alliancePower;
    mapping(address => uint) private memberPower;
    mapping(address => uint) private memberLostPower;
    mapping(address => uint) private memberResidenceStart;
    mapping(address => mapping(uint => bool)) private memberVoted;
    mapping(uint => mapping (address => bool)) private allianceMember;

    event AllianceCreated(address indexed _user, uint _allianceId, uint _time);
    event JoinedToAlliance(address indexed _user, uint indexed _allianceId, uint _time);
    event AbandonedAlliance(address indexed _user, uint  indexed _allianceId, uint _time);

    modifier onlyRole(address _caller){
        require (roleCall[_caller] == true, "3x00");
        _;
    }

    modifier warTime(){
        bool _war = ILands(lands).warNow();
        require (_war == false, "3x01");
        require (warResultingStatus == false, "3x01");
        _;
    }

    modifier allianceExist(uint _id){
        require (_id < totalSupply, "3x02");
        _;
    }

    modifier proposalExist(uint _id){
        require (_id < totalProposals, "3x03");
        _;
    }

    Alliance[] public alliances;
    Proposal[] public proposals;

    struct Alliance {
        uint id;
        string name;
        uint members;
        uint lands;
    }

    struct Proposal {
        uint id;
        uint alliance;
        string name;
        address aimToKick;
        uint startTime;
        uint confirmations;
        uint endTime;
        bool ended;
        bool executed;
    }

    constructor (){
        roleCall[msg.sender] = true;
    }

    function setRole(address _caller)external onlyRole(msg.sender){
        roleCall[_caller] = true;
    }

    function setAddresses(
        address _lands, 
        address _balances, 
        address _nuclear
    )
        external 
        onlyRole(msg.sender)
    {
        lands = _lands;
        balances = _balances;
        nuclear = _nuclear;
    }

    function createAlliance(string memory _name, uint _landId)external warTime(){
        address _user = msg.sender;
        require (memberStatus[_user] == false, "3x04");
        if (totalSupply > 0) {
            INuclear(nuclear)._createAllianceCheck(_user, _landId);
        }
        uint _lands = ILands(lands).ownerLandSupply(_user);
        Alliance memory alliance = Alliance(totalSupply, _name, 1, _lands); 
        alliances.push(alliance);        
        memberStatus[_user] = true;
        allianceStatus[_user] = totalSupply;
        allianceMember[totalSupply][_user] = true;
        totalSupply += 1;
        memberResidenceStart[_user] = block.timestamp;

        emit AllianceCreated(_user, totalSupply - 1, block.timestamp);
        emit JoinedToAlliance(_user, totalSupply - 1, block.timestamp);
    }

    function joinToAlliance(uint _allianceId, uint _landId)external warTime() allianceExist(_allianceId){
        address _user = msg.sender;
        require (memberStatus[_user] == false, "3x04");
        require (_allianceId > 0, "3x05");
        IBalances(balances)._joinToAlliance(_user, _landId);
        alliances[_allianceId].members += 1;
        uint _lands = ILands(lands).ownerLandSupply(_user);
        alliances[_allianceId].lands += _lands;
        memberStatus[_user] = true;
        allianceStatus[_user] = _allianceId;
        allianceMember[_allianceId][_user] = true;
        memberResidenceStart[_user] = block.timestamp;

        emit JoinedToAlliance(_user, _allianceId, block.timestamp);
    }

    function abandonAlliance()external warTime() allianceExist(allianceStatus[msg.sender]){
        address _user = msg.sender;
        require (memberStatus[_user] == true, "3x06");
        _kickFromAlliance(_user);        
    }

    function createProposal(address _aimToKick, uint _allianceId)external warTime() allianceExist(_allianceId){
        address _user = msg.sender;
        require (memberStatus[_user] == true, "3x06");
        require (memberStatus[_aimToKick] == true, "3x07");
        require (allianceStatus[_user] == _allianceId, "3x08");
        require (allianceStatus[_aimToKick] == _allianceId, "3x09");
        require (block.timestamp >= (memberResidenceStart[_user] + RESIDENCE_TIME_TO_VOTE), "3x10");
        require (block.timestamp >= (memberResidenceStart[_aimToKick] + RESIDENCE_TIME_TO_VOTE), "3x11");
        require (allianceMember[_allianceId][_user] == true, "3x12");
        require (allianceMember[_allianceId][_aimToKick] == true, "3x13");
        Proposal memory proposal = 
        Proposal(
            totalProposals, 
            _allianceId, 
            "Kick player", 
            _aimToKick, 
            block.timestamp, 
            1,
            block.timestamp + PROPOSAL_LIFE_TIME,
            false,
            false 
        ); 
        proposals.push(proposal);
        memberVoted[_user][totalProposals] = true;
        totalProposals += 1;
    }
        
    function confirmProposal(uint _id)external warTime() allianceExist(proposals[_id].alliance) proposalExist(_id){
        require (memberStatus[msg.sender] == true, "3x06");
        require (allianceStatus[msg.sender] == proposals[_id].alliance, "3x08");
        require (block.timestamp >= (memberResidenceStart[msg.sender] + RESIDENCE_TIME_TO_VOTE), "3x10");
        require (allianceMember[proposals[_id].alliance][msg.sender] == true, "3x12");
        require (proposals[_id].ended == false, "3x14");
        require (memberVoted[msg.sender][_id] == false, "3x15");
        proposals[_id].confirmations += 1;
        memberVoted[msg.sender][_id] = true;
        if (block.timestamp >= proposals[_id].endTime) {
            proposals[_id].ended = true;
        }
        if (proposals[_id].confirmations >= (alliances[proposals[_id].alliance].members / 2)){
            proposals[_id].endTime = block.timestamp;
            proposals[_id].ended = true;
            proposals[_id].executed = true;
            _kickFromAlliance(proposals[_id].aimToKick);        
        }
    }

    function warResult()external onlyRole(msg.sender){
        alliances[allianceStatus[memberWinner]].lands += 1;
        ILands(lands)._resultWar(memberWinner);
        warResultingStatus = false;   
        alliancePower[allianceStatus[memberWinner]] = 0;
        memberPower[memberWinner] = 0;
        memberLostPower[memberWinner] = 0;
        allianceWinner = 0;
        allianceWinnerPower = 0;
        memberWinnerLostPower = 0;
        memberWinner = address(0);
    }

    function _finishWar()external onlyRole(msg.sender){
        warResultingStatus = true;
    }

    function _joinToWar(address _user, uint _shipPower)external onlyRole(msg.sender){
        require (memberStatus[_user] == true, "3x06");
        alliancePower[allianceStatus[_user]] += _shipPower;
        memberPower[_user] += _shipPower;
        if (alliancePower[allianceStatus[_user]] > allianceWinnerPower) {
            allianceWinnerPower = alliancePower[allianceStatus[_user]];
            allianceWinner = allianceStatus[_user];
        }
    }

    function _returnShipFromWar(address _user, uint _lostPower)external onlyRole(msg.sender){
        if (allianceStatus[_user] == allianceWinner){
            memberLostPower[_user] += _lostPower;
            if (memberLostPower[_user] > memberWinnerLostPower) {
                memberWinnerLostPower = memberLostPower[_user];
                memberWinner = _user;
            }
        } else {
            alliancePower[allianceStatus[_user]] = 0; 
            memberPower[_user] = 0;
        }
    } 

    function _changeNumberOfLands(address _seller, address _buyer)external onlyRole(msg.sender){
        alliances[allianceStatus[_seller]].lands -= 1;
        alliances[allianceStatus[_buyer]].lands += 1;
    }

    function _kickFromAlliance(address _user)internal warTime() allianceExist(allianceStatus[_user]){
        uint _allianceId = allianceStatus[_user];
        alliances[_allianceId].members -= 1;
        uint _lands = ILands(lands).ownerLandSupply(_user);
        alliances[_allianceId].lands -= _lands;
        memberStatus[_user] = false;
        allianceStatus[_user] = 0;
        allianceMember[_allianceId][_user] = false;

        emit AbandonedAlliance(_user, _allianceId, block.timestamp);
    }
}
