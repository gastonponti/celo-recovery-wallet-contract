pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract RecoveryWallet {

    using SafeMath for uint256;

    // Events
    // TODO

    // bytes4 constants for each method that can be called in a proposal
    // This will allow us to examine a proposed transaction and identify which method it calls,
    // so that we can then lookup in `req` how many approvals are required
    bytes4 private constant SET_OWNER_BYTES4 = bytes4("");
    bytes4 private constant SET_ADMINS_BYTES4 = bytes4("");

    uint constant YES = 1;
    uint constant NO = 0;

    // Storage
    uint nAdmins;
    mapping(address => bool) isAdmin;
    address owner;

    uint proposalCounter = 1;
    mapping(uint => Proposal) proposals;
    mapping(bytes4 => uint) reqs;

    // Types
    struct Proposal {
        uint id;
        bytes data;
//        mapping(address => uint) votes;
        uint yesVotes;
        uint noVotes;
        uint req;
    }

    struct Transaction {
        address destination;
        uint256 value;
        bytes date;
    }

    // TODO: events

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

    // functions
    constructor(
        address[] memory _admins,
        address _owner,
        uint _reqForSetAdmins,
        uint _reqForSetOwner
    ) public {
        nAdmins = _admins.length;
        for (uint i = 0; i < _admins.length; i++) {
            isAdmin[_admins[i]] = true;
            owner = _owner;
            reqs[SET_OWNER_BYTES4] = _reqForSetOwner;
            reqs[SET_ADMINS_BYTES4] = _reqForSetAdmins;
        }
    }

    function transfer(address payable to, uint amount) external onlyOwner {
        if (address(this).balance < amount) {
            revert();
        }
        to.transfer(amount);
    }

    fallback () external payable {}

    function getBalance() public view returns (uint res) {
        return address(this).balance;
    }

    function propose(bytes calldata _data) external onlyOwnerOrAdmin {
        bytes4 sig = abi.decode(_data[:4], (bytes4));
        uint req = reqs[sig];
        if (req == 0) {
            revert();
        }
        uint id = proposalCounter;
        proposalCounter++;
        proposals[id] = Proposal({
            id: id,
            data: _data,
//            votes: {},
            yesVotes: 0,
            noVotes: 0,
            req: req
        });
    }

    function vote(uint id, uint vote) external onlyAdmin {

    }
}