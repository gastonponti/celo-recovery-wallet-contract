var ExampleToken = artifacts.require('ExampleToken');
module.exports = function (deployer, _network, _accounts) {
    deployer.deploy(ExampleToken);
};
