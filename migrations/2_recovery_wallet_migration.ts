const RecoveryWallet: any = artifacts.require("./RecoveryWallet.sol")

module.exports = (_deployer: any, _network: any, _accounts: string[]) => {
  _deployer.deploy(RecoveryWallet, [], 2);
}
