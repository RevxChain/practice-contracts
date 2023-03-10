// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFront {
    function PRODUCTION_TIME()external returns(uint);
    function BUILDING_TIME()external returns(uint);
    function SHIP_BUILDING_TIME()external returns(uint);
    function CRUISER_SHIP_EXTRA_BUILDING_TIME()external returns(uint);
    function changeParameter(uint _parameterId, uint _newValue)external;
}

contract DAO is AccessControl {

    uint public constant MINIMUM_AMOUNT_TO_PROPOSE = 1000e18; 
    uint public constant VOTING_DURATION = 3 days; 

    address public immutable administeredAddress; 
    address public immutable VPTokenAddress;

    bytes32 public constant GREAT_COMMUNITY_MEMBER = keccak256(abi.encode("GREAT_COMMUNITY_MEMBER"));

    mapping(uint => bool) public closeProposalType;
    mapping(address => uint) public totalLockedVotingPower;
    mapping(bytes32 => Proposal) public proposals;
    mapping(address => mapping(bytes32 => uint)) public lockedVotingPower;

    event ProposalCreated(bytes32 indexed proposalId, uint time);
    event ConfirmProposal(bytes32 indexed proposalId, address indexed user, uint time);
    event executeProposal(bytes32 indexed proposalId,uint time);
    event cancelProposal(bytes32 indexed proposalId, uint time);

    struct Proposal {
        bytes32 proposalId;
        string parameter;
        uint parameterId;
        uint baseValue;
        uint newValue;
        string description;
        uint againstVotes;
        uint forVotes; 
        uint votingStart;
        uint votingEnd;
        bool executed;
        bool canceled;
    }

    constructor(address _administeredAddress, address _VPTokenAddress){
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        _setupRole(GREAT_COMMUNITY_MEMBER, tx.origin);
        administeredAddress = _administeredAddress;
        VPTokenAddress = _VPTokenAddress;
    }

    function createProposal(uint _parameterId, uint _newValue, string calldata _description)external onlyRole(GREAT_COMMUNITY_MEMBER) returns(bytes32){
        address _user = msg.sender;
        require(IERC20(VPTokenAddress).balanceOf(_user) >= MINIMUM_AMOUNT_TO_PROPOSE, "DAO: Not enough tokens");
        require(_parameterId >= 0 && _parameterId < 4, "DAO: Choose the right parameter Id");
        require(closeProposalType[_parameterId] == false, "DAO: Changing that parameter is already proposed");
        uint _value;
        string memory _parameter;
        if(_parameterId == 0){
            _value = IFront(administeredAddress).PRODUCTION_TIME();
            _parameter = "PRODUCTION_TIME";
            closeProposalType[0] = true;
        }
        if(_parameterId == 1){
            _value = IFront(administeredAddress).BUILDING_TIME();
            _parameter = "BUILDING_TIME";
            closeProposalType[1] = true;
        }
        if(_parameterId == 2){
            _value = IFront(administeredAddress).SHIP_BUILDING_TIME();
            _parameter = "SHIP_BUILDING_TIME";
            closeProposalType[2] = true;
        }
        if(_parameterId == 3){
            _value = IFront(administeredAddress).CRUISER_SHIP_EXTRA_BUILDING_TIME();
            _parameter = "CRUISER_SHIP_EXTRA_BUILDING_TIME";
            closeProposalType[3] = true;
        }
        bytes32 _proposalId = calculateProposalId(
            _parameter, _value, _newValue, keccak256(bytes(_description)), block.timestamp
        );

        proposals[_proposalId] = Proposal({
            proposalId: _proposalId,
            parameter: _parameter,
            parameterId: _parameterId,
            baseValue: _value,
            newValue: _newValue,
            description: _description,
            againstVotes: 0,
            forVotes: 0,
            votingStart: block.timestamp,
            votingEnd: block.timestamp + VOTING_DURATION,
            executed: false,
            canceled: false
        });

        emit ProposalCreated(_proposalId, block.timestamp);

        return _proposalId;
    }

    function confirmProposal(bytes32 _proposalId, uint _votingPower, uint _votingType)external{
        address _user = msg.sender;
        require(proposals[_proposalId].votingStart > 0, "DAO: That proposal is not exist");
        require(proposals[_proposalId].executed == false && proposals[_proposalId].canceled == false , "DAO: That proposal is ended already");
        if(block.timestamp >= proposals[_proposalId].votingEnd){
            uint _span = proposals[_proposalId].againstVotes * 2;
            closeProposalType[proposals[_proposalId].parameterId] = false;
            if(proposals[_proposalId].forVotes > _span){
                proposals[_proposalId].executed = true;
                IFront(administeredAddress).changeParameter(proposals[_proposalId].parameterId, proposals[_proposalId].newValue);

                emit executeProposal(_proposalId, block.timestamp);
            } else {    
                proposals[_proposalId].canceled = true;

                emit cancelProposal(_proposalId, block.timestamp);
            }
        } else {
            require(IERC20(VPTokenAddress).balanceOf(_user) - totalLockedVotingPower[_user] >= _votingPower, "DAO: Not enough voting power");
            require(_votingType == 0 || _votingType == 1, "DAO: Choose the right voting type");
            lockedVotingPower[_user][_proposalId] += _votingPower;
            totalLockedVotingPower[_user] += _votingPower;
            if(_votingType == 0) {
                proposals[_proposalId].againstVotes += _votingPower;
            } else {
                proposals[_proposalId].forVotes += _votingPower;
            } 

            emit ConfirmProposal(_proposalId, _user, block.timestamp);
        }            
    }

    function unlockVotingPower(bytes32 _proposalId)external{
        address _user = msg.sender;
        require(proposals[_proposalId].executed == false || proposals[_proposalId].canceled == false , "DAO: That proposal is not ended yet");
        require(lockedVotingPower[_user][_proposalId] > 0, "DAO: You have not got locked voting power in that proposal");
        require(totalLockedVotingPower[_user] > 0, "DAO: You have not got locked total voting power");
        totalLockedVotingPower[_user] -= lockedVotingPower[_user][_proposalId];
        lockedVotingPower[_user][_proposalId] = 0;
    }

    function calculateProposalId(string memory _parameter, uint _baseValue, uint _newValue, bytes32 _description, uint _votingStart)public pure returns(bytes32){
        return keccak256(abi.encodePacked(
            _parameter, _baseValue, _newValue, _description, _votingStart
        ));
    }
}
