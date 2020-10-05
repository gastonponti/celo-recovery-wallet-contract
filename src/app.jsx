import React from 'react';
import ReactDOM from 'react-dom';
const Web3 = require("web3")
const web3 = new Web3("ws://127.0.0.1:8545")
import {Input} from "reactstrap"


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
            newOwnerProposals: [],
        }
    }

    async componentDidMount() {
        await ready;
        await this.reload();
        wallet.events.SetOwnerProposed((err, ev) => this.handleSetOwnerProposed(err, ev));
    }

    handleSetOwnerProposed(err, ev) {
        const data = ev.returnValues;
        console.log(`Got new owner proposal: ${JSON.stringify(data)}`)
        this.setState({
            newOwnerProposals: [...this.state.newOwnerProposals, {id: data[0], address: data[1]}]
        });
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
                {this.renderWalletInfo()}
                <NewOwnerProposer proposeSetOwner={(i) => this.proposeSetOwner(i)}/>
                {this.renderNewOwnerProposals()}
            </div>
        )
    }

    renderWalletInfo() {
        return (
        <div>
            <p>Owner: {accountNums[this.state.owner]}</p>
            <p>Admins: {JSON.stringify(this.state.admins.map(x => accountNums[x]))}</p>
        </div>)
    }

    renderNewOwnerProposals() {
        const rows = this.state.newOwnerProposals.map(proposal => {
            return <div key={proposal.id}>#{proposal.id}: proposes {proposal.address} (account {accountNums[proposal.address]})</div>
        })
        return <div>
            <h3>New Owner Proposals</h3>
            {rows}
        </div>
    }

    proposeSetOwner(i) {
        console.log(`Proposing account ${i}: ${accounts[i]}`)
        wallet.methods.proposeSetOwner(accounts[i]).send({from: this.state.owner, gas: 500000});
    }
}

class NewOwnerProposer extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            i: 0
        }
    }

    render() {
        return (
            <div>
                Select a new owner to propose:
                <Input type="select" onChange={(ev) => this.setState({i: ev.target.value})} value={this.state.i}>
                    {[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => <option value={i}>{i}</option>)}
                </Input>
                <button onClick={() => this.props.proposeSetOwner(this.state.i)}>Submit</button>
            </div>
        )
    }
}

const wrapper = document.getElementById("app");
wrapper ? ReactDOM.render(<App />, wrapper) : false;