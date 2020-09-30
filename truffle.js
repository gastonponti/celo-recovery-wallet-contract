module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*', // Match any network id
    },
    testnet: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*', // Match any network id
      from: '0xd2628502a6441e52f81d2Aea7A0C97D6079f45c7',
      gas: 4000000,
    },
  },
}
