pragma solidity ^0.5.15;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract RecoveryWallet {

    using SafeMath for uint256;

    // Events
    // TODO

    // bytes4 constants for each method that can be called in a proposal
    // This will allow us to examine a proposed transaction and identify which method it calls,
    // so that we can then lookup in `req` how many approvals are required
    bytes4 private constant SET_OWNER = bytes4("");

    // Storage
    mapping(address => bool) isAdmin;
    address owner;
    mapping(bytes4 => uint) reqs;

    // modifiers
    modifier onlyOwner {
        require(
            msg.sender == owner,
            "Only owner can call this function."
        );
        _;
    }

    constructor(
        address[] memory _admins,
        address _owner,
//        uint _reqForSetAdmins,
        uint _reqForSetOwner
    ) public {
        for (uint i = 0; i < _admins.length; i++) {
            isAdmin[_admins[i]] = true;
            owner = _owner;
            reqs[SET_OWNER] = _reqForSetOwner;
        }
    }

    function transfer(address payable to, uint amount) external onlyOwner {
        if (address(this).balance < amount) {
            revert();
        }
        to.transfer(amount);
    }
}