pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract RecoveryWallet {

    using SafeMath for uint256;

    // events
    event NewProposal(uint256 id, address target, uint256 value, bytes data, address proposer);
    event Vote(uint256 proposalId, bool approve, address admin);
    event Approved(uint256 proposalId);
    event Executed(uint256 proposalId);

    event SetOwnerProposed(uint256 id, address newOwner);
    event InvokeProposed(uint256 id);
    event AddTokenProposed(uint256 id, address addr, uint256 limit);

    event NewOwner(uint256 owner);
    event NewToken(address addr, uint256 limit);

    // Types
    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        mapping(address => bool) votes;
        uint256 total;
    }

    struct Token {
        uint256 limit;
        uint256 used;
        uint256 lastUsedAt;
    }

    // Storage
    uint256 public nAdmins;
    mapping(address => bool) public isAdmin;
    uint256 public quorum;
    address public owner;

    uint256 proposalCounter = 1;
    mapping(uint256 => Proposal) public proposals;

    mapping(address => Token) public tokens;

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
        uint256 _quorum
    ) public {
        owner = _owner;
        nAdmins = _admins.length;
        quorum = _quorum;
        for (uint256 i = 0; i < _admins.length; i++) {
            isAdmin[_admins[i]] = true;
        }
    }

    function transferCelo(address payable _to, uint256 _amount) external onlyOwner {
        if (address(this).balance < _amount) {
            revert();
        }
        _to.transfer(_amount);
    }

    function transferToken(address _tokenAddr, address _to, uint256 _amount) external onlyOwner {
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", _to, _amount);
        _tokenAddr.call(data);
    }

    fallback () external payable {}

    function getBalance() public view returns (uint256 res) {
        return address(this).balance;
    }

    function propose(address _target, uint256 _value, bytes calldata _data) external onlyWallet returns (uint256) {
        uint256 id = proposalCounter;
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

    function vote(uint256 id, bool approve) external onlyAdmin {
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

    function execute(uint256 _id) external onlyOwnerOrAdmin {
        if (proposals[_id].total >= quorum) {
            address(proposals[_id].target).call.value(proposals[_id].value)(proposals[_id].data);
        } else {
            revert("The proposal hasn't reached a quorum of admins, so it cannot be executed");
        }
    }

    function proposeSetOwner(address _newOwner) external onlyOwnerOrAdmin {
        bytes memory data = abi.encodeWithSignature("setOwner(address)", _newOwner);
        uint256 id = this.propose(address(this), 0, data);
        emit SetOwnerProposed(id, msg.sender);
    }

    function setOwner(address _newOwner) public onlyWallet {
        owner = _newOwner;
    }

    function proposeInvoke(address _target, uint256 _value, bytes calldata _data) external onlyOwner {
        uint256 id = this.propose(_target, _value, _data);
        emit InvokeProposed(id);
    }

    function proposeAddToken(address _addr, uint256 _limit) external onlyOwner {
        require(tokens[_addr].limit == 0, "A token cannot be added if it's already registered");
        bytes memory data = abi.encodeWithSignature("addToken(address,uint256)", _addr, _limit);
        uint256 id = this.propose(address(this), 0, data);
        emit AddTokenProposed(id, _addr, _limit);
    }

    function addToken(address _addr, uint256 _limit) public onlyWallet {
        tokens[_addr] = Token({
            limit: _limit,
            used: 0,
            lastUsedAt: now
        });
        emit NewToken(_addr, _limit);
    }
}