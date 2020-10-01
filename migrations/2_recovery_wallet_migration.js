const RecoveryWallet = artifacts.require('RecoveryWallet')

module.exports = (deployer, _network, accounts) => {
  deployer.deploy(RecoveryWallet, accounts.slice(2, 5), accounts[1], 2)
}
