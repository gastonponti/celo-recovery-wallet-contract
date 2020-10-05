import React from 'react';
import ReactDOM from 'react-dom';
const Web3 = require("web3")
const web3 = new Web3("http://127.0.0.1:8545")


const walletJson = require('../build/contracts/RecoveryWallet.json');
const tokenJson = require('../build/contracts/ExampleToken.json');
let wallet = new web3.eth.Contract(walletJson['abi']);
let token = new web3.eth.Contract(tokenJson['abi']);
let accounts

async function setup() {
    accounts = await web3.eth.getAccounts();
    await deployWallet();
    await deployToken();
    window.contracts = {wallet, token, accounts}
}

async function deployWallet() {
    const args = [accounts.slice(2, 5), accounts[1], 2];
    const tx = wallet.deploy({data: walletJson['bytecode'], arguments: args});
    wallet = await tx.send({from: accounts[0], gas: 6000000});
}

async function deployToken() {
    const args = [];
    const tx = token.deploy({data: tokenJson['bytecode'], arguments: args});
    token = await tx.send({from: accounts[0], gas: 6000000});
    await token.methods.mint(100).send({from: accounts[0]});
}

setup()

class App extends React.Component {


    render() {
        return <h1>Hello there</h1>
    }
}

const wrapper = document.getElementById("app");
wrapper ? ReactDOM.render(<App />, wrapper) : false;