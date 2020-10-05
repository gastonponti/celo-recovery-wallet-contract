const UsedPrecompiles = artifacts.require('UsedPrecompiles')

module.exports = (deployer, _network, accounts) => {
  deployer.deploy(UsedPrecompiles, accounts.slice(2, 5), accounts[1], 2)
}
