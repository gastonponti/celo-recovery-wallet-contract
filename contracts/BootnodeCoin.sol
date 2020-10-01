pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract BootnodeCoin {

  using SafeMath for uint256;

  string public name;
  string public symbol;
  address public owner;
  uint256 public totalSupply;
  mapping(address => uint256) public balances;
  uint256 public decimals = 18;

  constructor(string memory _name, string memory _symbol) public {
    name = _name;
    symbol = _symbol;
    owner = msg.sender;
    totalSupply = 0;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    // 2. Update the onlyOwner modifier to throw when called by any account other than 'owner'.
    require(msg.sender == owner);
    _;
  }

  event Transfer(address from, address to, uint256 value);

  /**
  * @notice Increases the sender's balance by 'value'.
  * @param value The amount to be minted.
  * @return True if minting succeeded.
  */
  function mint(uint256 value) public onlyOwner returns (bool) {
    // 3. Populate the mint function to increment the user's balance.
    totalSupply = totalSupply.add(value);
    balances[msg.sender] = balances[msg.sender].add(value);
    emit Transfer(address(0), msg.sender, value);
    return true;
  }

  /**
  * @notice Gets the balance of the specified address.
  * @param user The address to query the the balance of.
  * @return A uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address user) public view returns (uint256) {
    // 4. Populate the balanceOf function to get a user's BootnodeCoin balance.
    return balances[user];
  }

  /**
  * @notice Transfer token for a specified address
  * @param to The address to transfer to.
  * @param value The amount to be transferred.
  * @return True if the transfer succeeded.
  */
  function transfer(address to, uint256 value) public returns (bool) {
    // 5. Populate the transfer function to allow balance transfers.
    require(value <= balances[msg.sender]);
    require(to != address(0));

    balances[msg.sender] = balances[msg.sender].sub(value);
    balances[to] = balances[to].add(value);

    emit Transfer(to, msg.sender, value);
    return true;
  }
}
