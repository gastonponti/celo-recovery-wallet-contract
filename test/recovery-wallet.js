// import { RecoveryWallet as RecoveryWalletType } from "../build/typechain/RecoveryWallet";

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

contract('RecoveryWallet', (accounts) => {
  // Truffle sends transactions from accounts[0] unless otherwise directed.
  let wallet
  let owner = accounts[1]
  let admins = accounts.slice(2, 5)

  beforeEach(async () => {
    // Deploy a new instance of BootnodeCoin to the network.
    wallet = await RecoveryWallet.new(admins, owner, 2)
  })

  describe('#transfer', () => {
    it('should allow the owner to transfer CELO', async () => {
      assert(wallet !== null)
    })
  })
})
