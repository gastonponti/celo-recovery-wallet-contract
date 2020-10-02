pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/utils/EnumerableSet.sol";


contract RecoveryWallet {

    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    // events
    event NewProposal(uint256 id, address target, uint256 value, bytes data, address proposer);
    event Vote(uint256 proposalId, bool approve, address admin);
    event Approved(uint256 proposalId);
    event Executed(uint256 proposalId);

    event SetOwnerProposed(uint256 id, address newOwner);
    event InvokeProposed(uint256 id);
    event AddTokenProposed(uint256 id, address addr, uint256 limit);
    event UnlockProposed(uint256 id);

    event NewOwner(uint256 owner);
    event NewToken(address addr, uint256 limit);
    event Locked();
    event Unlocked();

    // Types
    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        EnumerableSet.AddressSet votes;
    }

    struct Token {
        uint256 limit;
        uint256 used;
        uint256 lastUsedAt;
    }

    // Storage
    EnumerableSet.AddressSet private admins;
    uint256 public quorum;
    address public owner;
    bool public locked;

    uint256 proposalCounter = 1;
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

    // functions
    constructor(
        address[] memory _admins,
        address _owner,
        uint256 _quorum
    ) public {
        owner = _owner;
        quorum = _quorum;
        for (uint256 i = 0; i < _admins.length; i++) {
            admins.add(_admins[i]);
        }
    }

    function transfer(address _tokenAddr, address _to, uint256 _amount) external onlyOwner returns (bool) {
        require(!locked, "The account is locked, so transfers are not possible");
        return IERC20(_tokenAddr).transfer(_to, _amount);
    }

    function balance(address _tokenAddr) public view returns (uint256 res) {
        return IERC20(_tokenAddr).balanceOf(address(this));
    }

    function propose(address _target, uint256 _value, bytes calldata _data) external onlyWallet returns (uint256) {
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
        bool curr = proposals[id].votes.contains(msg.sender);
        if (approve != curr) {
            if (approve) {
                proposals[id].votes.add(msg.sender);
            } else {
                proposals[id].votes.remove(msg.sender);
            }
        }
        emit Vote(id, approve, msg.sender);
    }

    function execute(uint256 _id) external onlyOwnerOrAdmin {
        require(
            proposals[_id].votes.length() >= quorum,
            "The proposal hasn't reached a quorum of admins, so it cannot be executed"
        );
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
    }

    /**
     * Locks the wallet by disabling the transfer() function until unlocked via a proposal
     * This is security feature allowing either the owner or any admin to quickly lock in case
     * the owner's account seems to have been compromised.
     */
    function lock() external onlyOwnerOrAdmin {
        locked = true;
    }

    function proposeUnlock() external onlyOwnerOrAdmin {
        bytes memory data = abi.encodeWithSignature("unlock()");
        uint256 id = this.propose(address(this), 0, data);
        emit UnlockProposed(id);
    }

    function unlock() public onlyWallet {
        locked = false;
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