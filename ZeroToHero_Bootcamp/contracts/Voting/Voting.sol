// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IToken {
    function totalSouls()external returns(uint);
}

contract Voting is ReentrancyGuard, AccessControl {  

    uint public totalVotings; 
 
    uint public constant VOTING_DURATION = 1 weeks;  
    uint public constant MINIMUM_QUORUM = 3;

    string public constant reVoting = "That theme has expired and recreated";

    address public immutable SBToken;
    
    mapping(string => bool) public themeVeto;
    mapping(bytes32 => bool) public sessionDenied;
    mapping(bytes32 => VotingSession) public sessions;
    mapping(string => bytes32) public sessionIdByTheme;
    mapping(bytes32 => mapping(address => bool)) public userVoted;

    string[] public sessionsArray;

    enum VoteOptions{Abstain, Yes, No, NoWithVeto}

    event CreatedSession(bytes32 indexed sessionId, string indexed theme, uint quorum, uint time);
    event Voted(bytes32 indexed sessionId, address voter, string indexed theme, uint indexed voteType, uint time);
    event VotingConfirmed(bytes32 indexed sessionId, string indexed theme, uint time);
    event VotingDeniedWithVeto(bytes32 indexed sessionId, string indexed theme, uint time);
    event VotingDenied(bytes32 indexed sessionId, string indexed theme, uint time);

    struct VotingSession {
        bytes32 sessionId;
        address creator;
        string theme;
        string description;
        uint abstainVotes;
        uint yesVotes;
        uint noVotes; 
        uint noWithVetoVotes;
        uint votingStart;
        uint votingEnd;
        uint quorum;
        bool executed;
    }

    constructor(address _SBToken){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        SBToken = _SBToken;
    }

    function createSession(
        string calldata _theme, 
        string calldata _description, 
        uint _quorum
    )
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        returns(bytes32 _sessionId)
    {
        address _user = msg.sender;
        require(themeVeto[_theme] == false, "Voting: Theme is under veto");
        require(IToken(SBToken).totalSouls() >= _quorum && _quorum >= MINIMUM_QUORUM, "Voting: Invalid quorum amount");
        _sessionId = calculateSessionId(
            totalVotings, _user, keccak256(bytes(_theme)), keccak256(bytes(_description)), block.timestamp, _quorum
        );
        sessions[_sessionId] = VotingSession({
            sessionId: _sessionId,
            creator: _user,
            theme: _theme,
            description: _description,
            abstainVotes: 0,
            yesVotes: 0,
            noVotes: 0,
            noWithVetoVotes: 0,
            votingStart: block.timestamp,
            votingEnd: block.timestamp + VOTING_DURATION,
            quorum: _quorum,
            executed: false
        });
        if(sessionIdByTheme[_theme] != 0x00){
            sessions[sessionIdByTheme[_theme]].votingEnd = block.timestamp; 
            string memory _theme_ = sessions[sessionIdByTheme[_theme]].theme;
            sessions[sessionIdByTheme[_theme]].theme = reVoting;
            sessionDenied[sessionIdByTheme[_theme]] = true;
        
            emit VotingDenied(sessionIdByTheme[_theme], _theme_, block.timestamp);
        } else {
            sessionsArray.push(_theme);
        }
        sessionIdByTheme[_theme] = _sessionId;
        totalVotings += 1;

        emit CreatedSession(_sessionId, _theme, _quorum, block.timestamp);
    }

    function voteFor(bytes32 _sessionId, uint _voteType)external {
        address _user = msg.sender;
        require(
            _voteType == uint(VoteOptions.Abstain) || 
            _voteType == uint(VoteOptions.Yes) || 
            _voteType == uint(VoteOptions.No) || 
            _voteType == uint(VoteOptions.NoWithVeto), 
            "Voting: Choosed wrong vote type"
        );
        require(sessionDenied[_sessionId] == false, "Voting: Session has denied");
        require(sessions[_sessionId].votingStart > 0, "Voting: Session is not exist");
        require(sessions[_sessionId].votingEnd > block.timestamp, "Voting: Session has ended already");
        require(sessions[_sessionId].executed == false , "Voting: Session has executed already");
        require(userVoted[_sessionId][_user] == false, "Voting: Voted already");
        require(IERC721(SBToken).balanceOf(_user) > 0, "Voting: You are not a voter");
        if(_voteType == uint(VoteOptions.Yes)){ 
            sessions[_sessionId].yesVotes += 1;
        } else {
            if(_voteType == uint(VoteOptions.Abstain)){ 
                sessions[_sessionId].abstainVotes += 1;
            } else {
                if(_voteType == uint(VoteOptions.No)){ 
                    sessions[_sessionId].noVotes += 1;
                } else {
                    sessions[_sessionId].noWithVetoVotes += 1;
                }
            }
        }
        userVoted[_sessionId][_user] = true;

        emit Voted(_sessionId, _user, sessions[_sessionId].theme, _voteType, block.timestamp);
    }

    function confirmSession(bytes32 _sessionId)external returns(string memory result){
        require(sessions[_sessionId].votingStart > 0, "Voting: That session is not exist");
        require(block.timestamp > sessions[_sessionId].votingEnd, "Voting: That session is not ended");
        require(sessions[_sessionId].executed == false , "Voting: That session is executed already");
        require(themeVeto[sessions[_sessionId].theme] == false, "Voting: Theme is under veto");
        require(sessionDenied[_sessionId] == false, "Voting: That session is denied already");
        require(keccak256(abi.encode(sessions[_sessionId].theme)) != keccak256(abi.encode(reVoting)), "Voting: That session is revoted");
        uint _totalVotes = 
        sessions[_sessionId].abstainVotes + 
        sessions[_sessionId].yesVotes + 
        sessions[_sessionId].noVotes + 
        sessions[_sessionId].noWithVetoVotes;
        require(_totalVotes >= sessions[_sessionId].quorum, "Voting: Not enough voters to confirm");
        if(sessions[_sessionId].yesVotes > _totalVotes / 2){
            sessions[_sessionId].executed = true;

            emit VotingConfirmed(_sessionId, sessions[_sessionId].theme, block.timestamp);

            return "Confirmed";
        } 
        if(sessions[_sessionId].noWithVetoVotes > _totalVotes / 2){
            themeVeto[sessions[_sessionId].theme] = true;

            emit VotingDeniedWithVeto(_sessionId, sessions[_sessionId].theme, block.timestamp);

            return "Veto";
        }
        sessionDenied[_sessionId] = true;
        
        emit VotingDenied(_sessionId, sessions[_sessionId].theme, block.timestamp);

        return "Denied";
    }

    function calculateSessionId(
        uint _number, 
        address _creator, 
        bytes32 _theme, 
        bytes32 _description, 
        uint _votingStart,
        uint _quorum
    )
        public 
        pure 
        returns(bytes32)
    {
        return keccak256(abi.encodePacked(
            _number, _creator, _theme, _description, _votingStart, _quorum
        ));
    }   

    function viewAllSessions()external view returns(string[] memory){
        return sessionsArray;
    }
}
