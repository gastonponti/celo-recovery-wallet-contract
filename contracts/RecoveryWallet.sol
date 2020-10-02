pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract RecoveryWallet {

  using SafeMath for uint256;

  address public owner;
  mapping (address => bool) boardMembers;
  uint neededForConsensus;
  bool isBlocked;

  Proposal activeProposal;
  uint activeProposalId;
  // proposalId => { address: acceptedVote }
  mapping(uint => mapping(address => bool)) votes;
  uint positiveVotes;

  enum ProposalType {
    AddMember, 
    RemoveMember, 
    ModifyNeededConsensus, 
    Unblock, 
    Recover, 
    Invoke 
  }

  struct Proposal {
    ProposalType proposalType;
    address proposer;
    uint expiryTime;
    address relatedAddress;
    bool executed;
  }

  event Transfer(address from, address to, uint256 value);

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  modifier onlyOwnerAndBoard() {
    require(msg.sender == owner || boardMembers[msg.sender]);
    _;
  }

  modifier onlyBoard() {
    require(boardMembers[msg.sender]);
    _;
  }

  modifier isProposalReadyToAccept(ProposalType proposalType, uint proposalId) {
    require(activeProposal.proposalType == proposalType);
    require(!activeProposal.executed);
    require(proposalId == activeProposalId);
    require(positiveVotes >= neededForConsensus);
    require(now <= activeProposal.expiryTime);
    _;
  }

  constructor(address[] _boardMembers, uint _neededForConsensus) public {
    owner = msg.sender;
    for (uint8 index = 0; index < _boardMembers.length; index++) {
      boardMembers[_boardMembers[index]] = true;
    }
    neededForConsensus = _neededForConsensus;
  }

  function setupNewProposal() internal {
    activeProposalId++;
    positiveVotes = 0;
  }

  function createAddBoardMemberProposal(address newBoardMember) public onlyOwnerAndBoard {
    setupNewProposal();
    activeProposal = Proposal({
      proposalType: ProposalType.AddMember,
      proposer: msg.sender,
      expiryTime: now + 24 hours,
      relatedAddress: newBoardMember,
      executed: false
    });
  }

  function executeAddBoardMemberProposal(uint proposalId) public isProposalReadyToAccept(ProposalType.AddMember, proposalId) {
    require(msg.sender == activeProposal.relatedAddress);
    activeProposal.executed = true;
    boardMembers[msg.sender] = true;
  }

  function createRemoveBoardMemberProposal(address boardMemberToRemove) public onlyOwnerAndBoard {
    setupNewProposal();
    activeProposal = Proposal({
      proposalType: ProposalType.RemoveMember,
      proposer: msg.sender,
      expiryTime: now + 24 hours,
      relatedAddress: boardMemberToRemove,
      executed: false
    });
  }

  function executeRemoveBoardMemberProposal(uint proposalId) public isProposalReadyToAccept(ProposalType.RemoveMember, proposalId) onlyOwner {
    activeProposal.executed = true;
    boardMembers[activeProposal.relatedAddress] = false;
  }

  function createRecoverProposal(address newAddress) public onlyOwnerAndBoard {
    setupNewProposal();
    activeProposal = Proposal({
      proposalType: ProposalType.Recover,
      proposer: msg.sender,
      expiryTime: now + 24 hours,
      relatedAddress: newAddress,
      executed: false
    });
  }

  function executeRecoverProposal(uint proposalId) public isProposalReadyToAccept(ProposalType.Recover, proposalId) {
    require(boardMembers[msg.sender] || msg.sender == activeProposal.relatedAddress);
    activeProposal.executed = true;
    owner = activeProposal.relatedAddress;
  }

  function createUnlockProposal() public onlyOwnerAndBoard {
    setupNewProposal();
    activeProposal = Proposal({
      proposalType: ProposalType.Unblock,
      proposer: msg.sender,
      expiryTime: now + 24 hours,
      relatedAddress: 0,
      executed: false
    });
  }

  function executeUnlockProposal(uint proposalId) public isProposalReadyToAccept(ProposalType.Unblock, proposalId) onlyOwner {
    activeProposal.executed = true;
    isBlocked = false;
  }

  function acceptProposal(uint proposalId) public onlyBoard {
    require(proposalId == activeProposalId);
    require(!votes[proposalId][msg.sender], 'Proposal was already accepted');
    votes[proposalId][msg.sender] = true;
    positiveVotes++;
  }

  function rejectProposal(uint proposalId) public onlyBoard {
    require(proposalId == activeProposalId);
    require(votes[proposalId][msg.sender], 'Proposal was already rejected');
    votes[proposalId][msg.sender] = false;
    positiveVotes--;
  }

  function blockAccount() public onlyOwnerAndBoard {
    isBlocked = true;
  }

  function transferCelo(address to, uint256 value) public onlyOwner returns (bool success) {
    require(to != address(0));
    require(!isBlocked);

    success = to.send(value);

    emit Transfer(address(this), to, value);
  }

}
