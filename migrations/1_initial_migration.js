const Migrations = artifacts.require("./Migrations.sol");

module.exports = (deployer, _network, _accounts) => {
  deployer.deploy(Migrations);
}
