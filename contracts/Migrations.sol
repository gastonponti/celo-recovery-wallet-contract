pragma solidity ^0.5.15;


contract Migrations {
    address public owner;
    uint public last_completed_migration; // solhint-disable var-name-mixedcase

    constructor() public {
        owner = msg.sender;
    }

    modifier restricted() {
        if (msg.sender == owner) _;
    }

    function setCompleted(uint completed) public restricted {
        last_completed_migration = completed; // solhint-disable var-name-mixedcase
    }

    // solhint-disable-next-line func-param-name-mixedcase
    function upgrade(address new_address) public restricted {
        Migrations upgraded = Migrations(new_address);
        upgraded.setCompleted(last_completed_migration);
    }
}
