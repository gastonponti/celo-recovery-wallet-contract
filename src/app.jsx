import React from 'react';
import ReactDOM from 'react-dom';
const Web3 = require("web3")
const web3 = new Web3("http://127.0.0.1:8545")


const walletJson = require('../build/contracts/RecoveryWallet.json');
const tokenJson = require('../build/contracts/ExampleToken.json');
let wallet = new web3.eth.Contract(walletJson['abi']);
let token = new web3.eth.Contract(tokenJson['abi']);
let accounts
const accountNums = {}

async function setup() {
    accounts = await web3.eth.getAccounts();
    for (let i = 0; i < 10; i++) {
        accountNums[accounts[i]] = i;
    }
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

const ready = setup()


class App extends React.Component {
    constructor(args) {
        super(args)
        this.state = {
            admins: [],
            owner: "",
        }
    }

    async componentDidMount() {
        await ready;
        await this.reload();
    }

    async reload() {
        const admins = await wallet.methods.getAdmins().call();
        const owner = await wallet.methods.owner().call();
        this.setState({
            admins,
            owner,
        })
    }


    ready() {
        return !!(wallet._address && token._address);
    }


    render() {

        return (
            <div>
                <h1>Recovery Wallet</h1>
                <p>Owner: {accountNums[this.state.owner]}</p>
                <p>Admins: {JSON.stringify(this.state.admins.map(x => accountNums[x]))}</p>
            </div>
        )
    }
}

const wrapper = document.getElementById("app");
wrapper ? ReactDOM.render(<App />, wrapper) : false;