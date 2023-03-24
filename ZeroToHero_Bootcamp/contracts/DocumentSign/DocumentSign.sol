// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IToken {
    function mintBySign(address _signer, uint _id)external;
}

contract DocumentSign is AccessControl, ReentrancyGuard{

    uint public totalProposals;
    uint public totalSigns;

    address public NFToken;

    mapping(bytes32 => Proposal) public proposals;

    event NewNFTokenSet(address NFToken, uint time);
    event CreatedProposal(bytes32 indexed proposalId, uint indexed number, address indexed creator, uint signers, bytes32 merkleRoot, uint time);
    event SignedProposal(bytes32 indexed proposalId, uint indexed number, address indexed signer, uint tokenId, uint time);
    event FullSignedProposal(bytes32 indexed proposalId, uint indexed number, uint time);

    struct Proposal {
        bytes32 proposalId;
        uint number;
        address creator;
        uint proposalCreated;
        string description;
        uint signersAmount;
        uint signs;
        bytes32 merkleRoot;
        mapping(address => bool) signed;     
        bool fullSigned;   
    }

    constructor(){
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
    }

    function setNewNFToken(address _NFToken)external nonReentrant() onlyRole(DEFAULT_ADMIN_ROLE){
        NFToken = _NFToken;

        emit NewNFTokenSet(_NFToken, block.timestamp);
    } 

    function createProposal(string calldata _description, bytes32 _merkleRoot, uint _signersAmount)external nonReentrant() returns(bytes32 _proposalId){
        address _user = msg.sender;
        _proposalId = calculateProposalId(
            totalProposals, _user, block.timestamp, keccak256(bytes(_description)), _merkleRoot, _signersAmount
        );

        proposals[_proposalId].proposalId = _proposalId;
        proposals[_proposalId].number = totalProposals;
        proposals[_proposalId].creator = _user;
        proposals[_proposalId].proposalCreated = block.timestamp;
        proposals[_proposalId].description = _description;
        proposals[_proposalId].signersAmount = _signersAmount;
        proposals[_proposalId].merkleRoot = _merkleRoot;

        emit CreatedProposal(_proposalId, totalProposals, _user, _signersAmount, _merkleRoot, block.timestamp);

        totalProposals += 1;
    }
    
    function signProposal(bytes32 _proposalId, bytes32[] calldata _proof)external nonReentrant() returns(uint _tokenId){
        address _user = msg.sender;
        require(proposals[_proposalId].creator != address(0), "DocumentSign: That proposal does not exist");
        require(proposals[_proposalId].fullSigned == false, "DocumentSign: Document is full signed already");
        require(proposals[_proposalId].signed[_user] == false, "DocumentSign: You are signed it already");
        require(_user == tx.origin, "DocumentSign: Use EOA address to receive unique NFT");
        bytes32 _leaf = keccak256(abi.encode(_user));
        bool result = MerkleProof.verifyCalldata(_proof, proposals[_proposalId].merkleRoot, _leaf);
        require(result == true, "DocumentSign: You are not whitelisted");           
        proposals[_proposalId].signs += 1;
        proposals[_proposalId].signed[_user] = true;
        _tokenId = totalSigns;
        IToken(NFToken).mintBySign(_user, _tokenId);
        totalSigns += 1;
        if(proposals[_proposalId].signersAmount == proposals[_proposalId].signs){
            proposals[_proposalId].fullSigned = true;

            emit FullSignedProposal(_proposalId, proposals[_proposalId].number, block.timestamp);
        }

        emit SignedProposal(_proposalId, proposals[_proposalId].number, _user, _tokenId, block.timestamp);
    }

    function checkUserSign(bytes32 _proposalId, address _user)external view returns(bool result){
        if(proposals[_proposalId].signed[_user] == true){
            return true;
        }
    }

    function calculateProposalId(
        uint _number, 
        address _creator, 
        uint _time, 
        bytes32 _description, 
        bytes32 _merkleRoot, 
        uint _signersAmount
    )
        public pure returns(bytes32)
    {
        return keccak256(abi.encode(
            _number, 
            _creator, 
            _time, 
            _description, 
            _merkleRoot, 
            _signersAmount
        ));
    }
}
