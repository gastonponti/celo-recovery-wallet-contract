pragma solidity ^0.6.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract ExampleToken {

  using SafeMath for uint256;

  string public name = "ExampleToken";
  string public symbol = "XMPL";
  address public owner;
  uint256 public totalSupply;
  mapping(address => uint256) public balances;
  uint256 public decimals = 18;

  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    // 2. Update the onlyOwner modifier to throw when called by any account other than 'owner'.
    require(msg.sender == owner);
    _;
  }

  /**
  * @notice Increases the sender's balance by 'value'.
  * @param _value The amount to be minted.
  * @return True if minting succeeded.
  */
  function mint(uint256 _value) public onlyOwner returns (bool) {
    balances[owner] += _value;
    totalSupply += _value;
  }

  /**
  * @notice Gets the balance of the specified address.
  * @param _user The address to query the the balance of.
  * @return A uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _user) public view returns (uint256) {
    return balances[_user];
  }

  /**
  * @notice Transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  * @return True if the transfer succeeded.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(balances[msg.sender] >= _value);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
  }
}
