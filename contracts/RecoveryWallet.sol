pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract RecoveryWallet {

    using SafeMath for uint256;

    // events
    event NewProposal(uint id, address target, uint value, bytes data, address proposer);
    event SetOwnerProposed(uint id, address newOwner);
    event Vote(uint proposalId, bool approve, address admin);
    event Approved(uint proposalId);
    event Executed(uint proposalId);
    event NewOwner(uint owner);

    // Types
    struct Proposal {
        address target;
        uint value;
        bytes data;
        mapping(address => bool) votes;
        uint total;
    }

    // Storage
    uint public nAdmins;
    mapping(address => bool) public isAdmin;
    uint public quorum;
    address public owner;

    uint proposalCounter = 1;
    mapping(uint => Proposal) proposals;

    // modifiers
    modifier onlyOwner {
        require(
            msg.sender == owner,
            "Only owner can call this function."
        );
        _;
    }

    modifier onlyAdmin {
        require(
            isAdmin[msg.sender],
            "Only admins can call this function."
        );
        _;
    }

    modifier onlyOwnerOrAdmin {
        require(
            msg.sender == owner || isAdmin[msg.sender],
            "Only owner and admins can call this function."
        );
        _;
    }

    modifier onlyOwnerOrAdminOrWallet {
        require(
            msg.sender == owner || isAdmin[msg.sender] || msg.sender == address(this),
            "Only owner and admins and the wallet can call this function."
        );
        _;
    }

    modifier onlyWallet {
        require(msg.sender == address(this), "Only the wallet itself can call this function");
        _;
    }

    // functions
    constructor(
        address[] memory _admins,
        address _owner,
        uint _quorum
    ) public {
        owner = _owner;
        nAdmins = _admins.length;
        quorum = _quorum;
        for (uint i = 0; i < _admins.length; i++) {
            isAdmin[_admins[i]] = true;
        }
    }

    function transferCelo(address payable to, uint amount) external onlyOwner {
        if (address(this).balance < amount) {
            revert();
        }
        to.transfer(amount);
    }

    fallback () external payable {}

    function getBalance() public view returns (uint res) {
        return address(this).balance;
    }

    function propose(address _target, uint _value, bytes calldata _data) external onlyOwnerOrAdminOrWallet returns (uint) {
        uint id = proposalCounter;
        proposalCounter++;
        proposals[id] = Proposal({
            target: _target,
            value: _value,
            data: _data,
            total: 0
        });
        emit NewProposal(id, _target, _value, _data, msg.sender);
        return id;
    }

    function vote(uint id, bool approve) external onlyAdmin {
        bool curr = proposals[id].votes[msg.sender];
        if (approve != curr) {
            proposals[id].votes[msg.sender] = true;
            if (approve) {
                proposals[id].total += 1;
            } else {
                proposals[id].total -= 1;
            }
        }
        emit Vote(id, approve, msg.sender);
    }

    function execute(uint id) external onlyOwnerOrAdmin {
        if (proposals[id].total >= quorum) {
            address(proposals[id].target).call.value(proposals[id].value)(proposals[id].data);
        } else {
            revert("The proposal hasn't reached a quorum of admins, so it cannot be executed");
        }
    }

    function proposeSetOwner(address newOwner) external onlyOwnerOrAdmin returns (uint) {
        bytes memory data = abi.encodeWithSignature("setOwner(address)", newOwner);
        uint id = this.propose(address(this), 0, data);
        emit SetOwnerProposed(id, msg.sender);
    }

    function setOwner(address newOwner) public onlyWallet {
        owner = newOwner;
    }
}