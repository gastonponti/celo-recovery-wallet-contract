const Migrations: any = artifacts.require("./Migrations.sol");

module.exports = (deployer: any, _network: any, _accounts: string[]) => {
  deployer.deploy(Migrations);
}
