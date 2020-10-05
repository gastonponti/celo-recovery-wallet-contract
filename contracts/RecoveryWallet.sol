pragma solidity ^0.5.3;
// pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/utils/EnumerableSet.sol";

import "./UsedPrecompiles.sol";


contract RecoveryWallet is UsedPrecompiles {

    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    // events
    event NewProposal(uint256 id, address target, uint256 value, bytes data, address proposer);
    event Vote(uint256 proposalId, bool approve, address admin);
    event Approved(uint256 proposalId);
    event Executed(uint256 proposalId);



    event SetOwnerProposed(uint256 id, address newOwner);
    event InvokeProposed(uint256 id);
    event IncreaseTokenProposed(uint256 id, address addr, uint256 limit);
    event AddAdminProposed(uint256 id, address newAdmin);
    event RemoveAdminProposed(uint256 id, address admin);
    event ChangeAdminProposed(uint256 id, address oldAdmin, address newAdmin);
    event QuorumChangeProposed(uint256 id, uint256 newQuorum);
    event UnlockProposed(uint256 id);

    event NewOwner(address owner);
    event LimitTokenChanged(address addr, uint256 limit);
    event AdminAdded(address newAdmin);
    event AdminRemoved(address admin);
    event QuorumChanged(uint256 newQuorum);
    event Locked(address locker);
    event Unlocked();

    // Types
    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        EnumerableSet.AddressSet votes;
        bool executed;
    }

    struct Token {
        uint256 limit;
        mapping(uint256 => uint256) usedInEpoch;
    }

    // Storage
    EnumerableSet.AddressSet private admins;
    uint256 public quorum;
    address public owner;
    bool public locked;

    uint256 proposalCounter = 1;

    uint256 public proposalsValidFromId;
    mapping(uint256 => Proposal) private proposals;

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
            admins.contains(msg.sender),
            "Only admins can call this function."
        );
        _;
    }

    modifier onlyOwnerOrAdmin {
        require(
            msg.sender == owner || admins.contains(msg.sender),
            "Only owner and admins can call this function."
        );
        _;
    }

    modifier onlyOwnerOrAdminOrWallet {
        require(
            msg.sender == owner || admins.contains(msg.sender) || msg.sender == address(this),
            "Only owner and admins and the wallet can call this function."
        );
        _;
    }

    modifier onlyWallet {
        require(msg.sender == address(this), "Only the wallet itself can call this function");
        _;
    }

    modifier notLocked() {
        require(!locked, "The account is locked, so transfers are not possible");
        _;
    }

    // functions
    constructor(
        address[] memory _admins,
        address _owner,
        uint256 _quorum
    ) public {
        require(_quorum > 0, "requires a quorum bigger that 0");
        for (uint256 i = 0; i < _admins.length; i = i.add(1)) {
            require(_admins[i] != address(0), "should be a valid address");
            require(admins.add(_admins[i]), "duplicated member");
        }
        require(admins.length() > _quorum, "need more admin members");

        if (_owner != address(0)) {
            owner = _owner;
        } else {
            owner = msg.sender;
        }
        quorum = _quorum;
        proposalsValidFromId = proposalCounter;

        emit NewOwner(owner);
    }

    function transfer(address _tokenAddr, address _to, uint256 _amount) external notLocked onlyOwner returns (bool) {
        // This is in a different required, because it could happen that the used token is bigger that the limit set
        // if in the same epoch the limit was decreased by the user. If we left only the "limit.sub(used)" require
        // the error showned to the user will be an overflow and not a "limit reached"
        uint256 epoch = getEpochNumber();
        require(tokens[_tokenAddr].limit >= tokens[_tokenAddr].usedInEpoch[epoch], "limit reached");
        require(tokens[_tokenAddr].limit.sub(tokens[_tokenAddr].usedInEpoch[epoch]) >= _amount, "limit reached");
        tokens[_tokenAddr].usedInEpoch[epoch] = tokens[_tokenAddr].usedInEpoch[epoch].add(_amount);
        return IERC20(_tokenAddr).transfer(_to, _amount);
    }

    function balance(address _tokenAddr) public view returns (uint256) {
        return IERC20(_tokenAddr).balanceOf(address(this));
    }

    function propose(address _target, uint256 _value, bytes calldata _data) external onlyWallet returns (uint256) {
        require(_target != address(0), "Invalid proposal target");
        uint256 id = proposalCounter;
        proposalCounter++;
        Proposal memory proposal;
        proposal.target = _target;
        proposal.value = _value;
        proposal.data = _data;
        proposals[id] = proposal;

        emit NewProposal(id, _target, _value, _data, msg.sender);
        return id;
    }

    function vote(uint256 id, bool approve) external onlyAdmin {
        require(proposals[id].executed, "The proposal was already executed");
        require(id >= proposalsValidFromId, "Not a valid proposal anymore. An admin change proposal was invoked in between");
        require(id < proposalCounter, "Cannot vote for future proposals");
        
        if (approve) {
            proposals[id].votes.add(msg.sender);
        } else {
            proposals[id].votes.remove(msg.sender);
        }
        
        emit Vote(id, approve, msg.sender);
    }

    function execute(uint256 _id) external onlyOwnerOrAdmin {
        require(proposals[_id].executed, "Proposal already executed");
        require(_id >= proposalsValidFromId, "Not a valid proposal anymore. An admin change proposal was invoked in between");
        require(proposals[_id].votes.length() >= quorum, "The proposal hasn't reached a quorum of admins, so it cannot be executed");
        proposals[_id].executed = true;
        (bool success,) = address(proposals[_id].target).call.value(proposals[_id].value)(proposals[_id].data);
        if (!success) {
            revert("Proposal execution reverted");
        }
    }

    function proposeSetOwner(address _newOwner) external onlyOwnerOrAdmin {
        bytes memory data = abi.encodeWithSignature("setOwner(address)", _newOwner);
        uint256 id = this.propose(address(this), 0, data);
        emit SetOwnerProposed(id, msg.sender);
    }

    function setOwner(address _newOwner) public onlyWallet {
        owner = _newOwner;
        emit NewOwner(owner);
    }

    /**
     * Locks the wallet by disabling the transfer() function until unlocked via a proposal
     * This is security feature allowing either the owner or any admin to quickly lock in case
     * the owner's account seems to have been compromised.
     */
    function lock() external onlyOwnerOrAdmin {
        locked = true;
        emit Locked(msg.sender);
    }

    function proposeUnlock() external onlyOwnerOrAdmin {
        bytes memory data = abi.encodeWithSignature("unlock()");
        uint256 id = this.propose(address(this), 0, data);
        emit UnlockProposed(id);
    }

    function unlock() public onlyWallet {
        locked = false;
        emit Unlocked();
    }

    function proposeInvoke(address _target, uint256 _value, bytes calldata _data) external onlyOwner {
        uint256 id = this.propose(_target, _value, _data);
        emit InvokeProposed(id);
    }

    function proposeAddAdmin(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "Invalid Address");
        require(!admins.contains(newAdmin), "this proposal if approved could duplicate an admin");
        bytes memory data = abi.encodeWithSignature("addAdmin(address)", newAdmin);
        uint256 id = this.propose(address(this), 0, data);
        emit AddAdminProposed(id, newAdmin);
    }

    function addAdmin(address newAdmin) public onlyOwner {
        // this shouldn't happen because it's checked when the proposal was created
        require(newAdmin != address(0), "Invalid Address");
        require(admins.add(newAdmin), "The user was already an admin"); 
        proposalsValidFromId = proposalCounter;
        emit AdminAdded(newAdmin);
    }

    function proposeRemoveAdmin(address admin) external onlyOwner {
        require(admins.contains(admin), "The user to removed is not an admin");
        require(admins.length().sub(1) >= quorum, "This proposal if approved could will left the contract without quorum");
        bytes memory data = abi.encodeWithSignature("removeAdmin(address)", admin);
        uint256 id = this.propose(address(this), 0, data);
        emit RemoveAdminProposed(id, admin);
    }

    function removeAdmin(address admin) public onlyWallet {
        // this shouldn't happen because it's checked when the proposal was created
        require(admins.length().sub(1) >= quorum, "Will left the contract without quorum");
        require(admins.remove(admin), "The user was not an admin"); 
        proposalsValidFromId = proposalCounter;
        emit AdminRemoved(admin);
    }

    function proposeChangeAdmin(address oldAdmin, address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "Invalid Address");
        require(newAdmin != oldAdmin, "Unnecessary change, same address");
        require(admins.contains(oldAdmin), "The user to removed is not an admin");
        require(!admins.contains(newAdmin), "This proposal if approved could duplicate an admin");
        bytes memory data = abi.encodeWithSignature("changeAdmin(address, address)", oldAdmin, newAdmin);
        uint256 id = this.propose(address(this), 0, data);
        emit ChangeAdminProposed(id, oldAdmin, newAdmin);
    }

    function changeAdmin(address oldAdmin, address newAdmin) public onlyWallet {
        // this shouldn't happen because it's checked when the proposal was created
        require(newAdmin != address(0), "Invalid Address");
        require(newAdmin != oldAdmin, "Unnecessary change, same address");
        require(admins.remove(oldAdmin), "The user to removed is not an admin");
        require(!admins.add(newAdmin), "The user was already an admin"); 
        proposalsValidFromId = proposalCounter;
        emit AdminRemoved(oldAdmin);
        emit AdminAdded(newAdmin);
    }

    function proposeChangeQuorum(uint256 newQuorum) external onlyOwner {
        require(admins.length() >= newQuorum, "This proposal if approved could will left the contract without quorum");
        require(newQuorum > 0, "Quorum must be bigger than 0");
        bytes memory data = abi.encodeWithSignature("changeQuorum(uint256)", newQuorum);
        uint256 id = this.propose(address(this), 0, data);
        emit QuorumChangeProposed(id, newQuorum);
    }

    function changeQuorum(uint256 newQuorum) public onlyWallet {
        // this shouldn't happen because it's checked when the proposal was created
        require(admins.length() >= newQuorum, "Will left the contract without quorum");
        require(newQuorum > 0, "Quorum must be bigger than 0");
        quorum = newQuorum;
        proposalsValidFromId = proposalCounter;
        emit QuorumChanged(newQuorum);
    }

    function proposeIncreaseTokenLimit(address _addr, uint256 _limit) external onlyOwner {
        bytes memory data = abi.encodeWithSignature("increaseTokenLimit(address,uint256)", _addr, _limit);
        uint256 id = this.propose(address(this), 0, data);
        emit IncreaseTokenProposed(id, _addr, _limit);
    }

    function increaseTokenLimit(address _addr, uint256 _limit) public onlyWallet {
        require(tokens[_addr].limit < _limit, "no need to use a proposal to decrease the limit"); 
        tokens[_addr].limit = _limit;
        emit LimitTokenChanged(_addr, _limit);
    }

    function decreaseTokenLimit(address _addr, uint256 _limit) public onlyOwner {
        require(tokens[_addr].limit > _limit, "use a proposal to increase the limit"); 
        tokens[_addr].limit = _limit;
        emit LimitTokenChanged(_addr, _limit);
    }
}