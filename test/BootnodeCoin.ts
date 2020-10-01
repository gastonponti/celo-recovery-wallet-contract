import { BootnodeCoin as BootnodeCoinType } from "../build/typechain/BootnodeCoin";

const BootnodeCoin = artifacts.require("./contracts/BootnodeCoin.sol");

// Asserts the failure of a transaction.
export async function assertRevert(promise: any) {
  try {
    await promise
    assert.fail('Expected revert not received')
  } catch (error) {
    const revertFound = error.message.search('revert') >= 0
    assert(revertFound, `Expected "revert", got ${error} instead`)
  }
}

contract('BootnodeCoin', (accounts: string[]) => {
  // Truffle sends transactions from accounts[0] unless otherwise directed.
  const owner: string = accounts[0]
  let bootnodeCoin: BootnodeCoinType;

  beforeEach(async () => {
    // Deploy a new instance of BootnodeCoin to the network.
    bootnodeCoin = await BootnodeCoin.new('BootnodeCoin', 'BnC')
  })

  describe('#mint', () => {
    it('should allow the owner to mint tokens', async () => {
      // 1. Test that "mint" increments the owner's balance.
      const amount = 100;
      assert.equal(await bootnodeCoin.balanceOf.call(accounts[0]), 0)
      await bootnodeCoin.mint(amount)
      assert.equal((await bootnodeCoin.totalSupply()).toNumber(), amount);

      assert.equal((await bootnodeCoin.balanceOf.call(accounts[0])).toNumber(), amount)
    })

    it('should not allow anyone else to mint tokens', async () => {
      const amount = 100;
      await assertRevert(bootnodeCoin.mint(amount, { from: accounts[1] }))
    })
  })

  describe('#balanceOf', () => {
    it('should get the balance of a user', async () => {
      assert.equal(await bootnodeCoin.balanceOf.call(accounts[1]), 0)
    })
  })

  describe('#transfer', () => {
    it('should allow users to transfer BootnodeCoin', async () => {
      // 4. Test that "transfer" updates both user's balances.
      const mintAmount = 1000, transferAmount = 10;
      assert(transferAmount < mintAmount, `Need to mint more than we are trying to transfer`)

      assert.equal(await bootnodeCoin.balanceOf.call(owner), 0)
      assert.equal((await bootnodeCoin.balanceOf.call(accounts[1])).toNumber(), 0)

      await bootnodeCoin.mint(mintAmount);
      await bootnodeCoin.transfer(accounts[1], transferAmount);

      assert.equal((await bootnodeCoin.balanceOf.call(owner)).toNumber(), mintAmount - transferAmount)
      assert.equal((await bootnodeCoin.balanceOf.call(accounts[1])).toNumber(), transferAmount)
    })

    it('should not allow users to transfer more BootnodeCoin than they possess', async () => {
      // 5. Test that "transfer" fails when transferring too much BootnodeCoin.

      const mintAmount = 10, transferAmount = 100;
      assert(transferAmount > mintAmount, `Need to mint less than we are trying to transfer`)

      assert.equal(await bootnodeCoin.balanceOf.call(owner), 0)
      assert.equal(await bootnodeCoin.balanceOf.call(accounts[1]), 0)

      await bootnodeCoin.mint(mintAmount)

      assert.equal((await bootnodeCoin.balanceOf.call(owner)).toNumber(), mintAmount)
      assert.equal((await bootnodeCoin.balanceOf.call(accounts[1])).toNumber(), 0)

      await assertRevert(bootnodeCoin.transfer(accounts[1], transferAmount))

      assert.equal((await bootnodeCoin.balanceOf.call(owner)).toNumber(), mintAmount)
      assert.equal((await bootnodeCoin.balanceOf.call(accounts[1])).toNumber(), 0)
    })
  })
})
