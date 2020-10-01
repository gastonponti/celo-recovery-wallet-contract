// import { RecoveryWallet as RecoveryWalletType } from "../build/typechain/RecoveryWallet";
const BigNumber = require('bignumber.js')

const RecoveryWallet = artifacts.require("./contracts/RecoveryWallet.sol");


// Asserts the failure of a transaction.
async function assertRevert(promise) {
  try {
    await promise
    assert.fail('Expected revert not received')
  } catch (error) {
    const revertFound = error.message.search('revert') >= 0
    assert(revertFound, `Expected "revert", got ${error} instead`)
  }
}

async function assertBalance(address, amount) {
  const balance = await web3.eth.getBalance(address)
  assert(balance === amount, `Expected balance ${balance} to equal ${amount} for address ${address}`)
}

contract('RecoveryWallet', (accounts) => {
  // Truffle sends transactions from accounts[0] unless otherwise directed.
  let wallet
  let owner = accounts[1]
  let admins = accounts.slice(2, 5)
  const otherAccount = web3.eth.accounts.create()

  beforeEach(async () => {
    // Deploy a new instance of BootnodeCoin to the network.
    wallet = await RecoveryWallet.new(accounts.slice(2,5), accounts[1], 2, 2)
  })

  describe('#transfer', () => {
    it('should revert if the owner tries to transfer more than the wallet has', async () => {
      assertRevert(wallet.transfer(accounts[2], 100, {from: accounts[1]}))
    })

    it('should transfer if the owner asks it it', async () => {
      await wallet.send("100000")
      await assertBalance(wallet.address, "100000")
      await wallet.transfer(otherAccount.address, "40000", {from: accounts[1]})
      await assertBalance(wallet.address, "60000")
      await assertBalance(otherAccount.address, "40000")
    })

    it('should revert if someonelse else asks it it', async () => {
      await wallet.send("100000")
      await assertBalance(wallet.address, "100000")
      assertRevert(wallet.transfer(otherAccount.address, "40000", {from: accounts[2]}))
    })
  })
})
