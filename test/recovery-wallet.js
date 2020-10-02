// import { RecoveryWallet as RecoveryWalletType } from "../build/typechain/RecoveryWallet";
const BigNumber = require('bignumber.js')

const RecoveryWallet = artifacts.require("./contracts/RecoveryWallet.sol");
const ExampleToken = artifacts.require("./contracts/ExampleToken.sol")


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
  async function assertOwner(owner) {
    const realOwner = await wallet.owner();
    // console.log("OWNER IS", realOwner)
    assert(owner === realOwner, `Expected owner to be ${owner}, but it was ${realOwner}`)
  }

  // Truffle sends transactions from accounts[0] unless otherwise directed.
  let wallet
  let owner = accounts[1]
  let admins = accounts.slice(2, 5)
  const otherAccount = web3.eth.accounts.create()

  beforeEach(async () => {
    // Deploy a new instance of BootnodeCoin to the network.
    wallet = await RecoveryWallet.new(accounts.slice(2,5), accounts[1], 2)
  })

  describe('#transfer', () => {
    it('should revert if the owner tries to transfer more than the wallet has', async () => {
      await assertRevert(wallet.transferCelo(accounts[2], 100, {from: accounts[1]}))
    })

    it('should transfer if the owner asks it it', async () => {
      await wallet.send("100000")
      await assertBalance(wallet.address, "100000")
      await wallet.transferCelo(otherAccount.address, "40000", {from: accounts[1]})
      await assertBalance(wallet.address, "60000")
      await assertBalance(otherAccount.address, "40000")
    })

    it('should revert if someonelse else asks it it', async () => {
      await wallet.send("100000")
      await assertBalance(wallet.address, "100000")
      await assertRevert(wallet.transferCelo(otherAccount.address, "40000", {from: accounts[2]}))
    })
  })

  describe('#setOwner', () => {
    it('should be proposable, votable, executable, and should work', async () => {
      await wallet.proposeSetOwner(accounts[8], {from: accounts[1]})
      await assertOwner(accounts[1])
      await wallet.vote(1, true, {from: accounts[2]})
      await assertRevert(wallet.execute(1, {from: accounts[3]}))
      await wallet.vote(1, true, {from: accounts[3]})
      await assertOwner(accounts[1])
      await wallet.execute(1, {from: accounts[3]})
      await assertOwner(accounts[8])
    })
  })

  describe('#tokens', () => {
    let exampleToken;
    beforeEach(async () => {
      exampleToken = await ExampleToken.new();
      await exampleToken.mint(100, {from: accounts[0]});
    })

    async function addTheToken() {
      await wallet.proposeAddToken(exampleToken.address, 30, {from: accounts[1]})
      await wallet.vote(1, true, {from: accounts[2]})
      await wallet.vote(1, true, {from: accounts[3]})
      await wallet.execute(1, {from: accounts[3]})
    }

    it('can be added', async () => {
      await addTheToken()
      const tokenInfo = await wallet.tokens(exampleToken.address)
      assert(tokenInfo.limit.toNumber() == 30);
    })

    it('can be sent', async () => {
      await addTheToken();
      await exampleToken.transfer(wallet.address, 90, {from: accounts[0]});
      assert((await exampleToken.balanceOf(wallet.address)).toNumber() == 90)
      await wallet.transferToken(exampleToken.address, accounts[8], 10, {from: accounts[1]})
      assert((await exampleToken.balanceOf(wallet.address)).toNumber() == 80)
      assert((await exampleToken.balanceOf(accounts[8])).toNumber() == 10)
      // not enough funds, so will revert
      await assertRevert(wallet.transferToken(exampleToken.address, accounts[8], 90, {from: accounts[1]}))
    })
  })
})
