const BootnodeCoin: any = artifacts.require("./BootnodeCoin.sol")

module.exports = (_deployer: any, _network: any, _accounts: string[]) => {
  _deployer.deploy(BootnodeCoin, 'BootnodeCoin', 'BNC');
}
