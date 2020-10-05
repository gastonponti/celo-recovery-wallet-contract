import React from 'react';
import ReactDOM from 'react-dom';
const Web3 = require("web3")
const web3 = new Web3("ws://127.0.0.1:8545")
import {Input, Col, Row, Button} from "reactstrap"


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
            ready: false,
        }
    }

    async componentDidMount() {
        await ready;
        await this.reload();
        wallet.events.SetOwnerProposed((err, ev) => this.handleSetOwnerProposed(err, ev));
        wallet.events.Vote((err, ev) => this.handleVote(err, ev));
        wallet.events.NewOwner((err, ev) => this.handleNewOwner(err, ev));
        wallet.events.Executed((err, ev) => this.handleExecuted(err, ev));
        this.setState({ready: true});
    }

    handleSetOwnerProposed(err, ev) {
        const data = ev.returnValues;
        console.log(`Got new spender proposal: ${JSON.stringify(data)}`)
        this.setState({
            newOwnerProposals: [...this.state.newOwnerProposals, {
                id: data[0],
                address: data[1],
                approvals: [],
                approved: false,
                executed: false,
            }]
        });
    }

    handleVote(err, ev) {
        const id = ev.returnValues.proposalId;
        const approver = ev.returnValues.admin;
        console.log(`Proposal ${id} approved by ${approver} ${accountNums[approver]}`);
        for (const proposal of this.state.newOwnerProposals) {
            if (proposal.id === id) {
                if (!proposal.approvals.includes(approver)) {
                    proposal.approvals.push(approver);
                    if (proposal.approvals.length >= 2) {
                        proposal.approved = true;
                    }
                }
            }
        }
        this.setState({newOwnerProposals: this.state.newOwnerProposals})
    }

    handleNewOwner(err, ev) {
        const owner = ev.returnValues.owner;
        console.log(`Got new spender: ${owner}`)
        this.setState({
            owner,
        })
    }

    handleExecuted(err, ev) {
        const id = ev.returnValues.proposalId;
        console.log(`Proposal ${id} was executed`)
        for (const proposal of this.state.newOwnerProposals) {
            if (proposal.id === id) {
                proposal.executed = true;
            }
        }
        this.setState({newOwnerProposals: this.state.newOwnerProposals})
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
        return (this.state.ready &&
            <div>
                <h1>Hackathon demo: proposals, voting, and execution (using Ganache)</h1>
                <div><b>Contract address</b>: {wallet._address}</div>
                {this.renderTruffleAccounts()}
                {this.renderWalletInfo()}
                <NewOwnerProposer proposeSetOwner={(i) => this.proposeSetOwner(i)}/>
                {this.renderNewOwnerProposals()}
            </div>
        )
    }

    renderTruffleAccounts() {
        return <div>
            <h3>Truffle accounts:</h3>
            {accounts && [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(i =>
                <div key={i}>#{i}: {accounts[i]}</div>
            )}
        </div>
    }

    renderWalletInfo() {
        return (
        <div>
            <p><b>Spender</b>: {accountNums[this.state.owner]} ({this.state.owner})</p>
            <p><b>Admins</b>: {JSON.stringify(this.state.admins.map(x => accountNums[x]))} (2-of-3 required to approve a proposal)</p>
        </div>)
    }

    renderNewOwnerProposals() {

        const rows = this.state.newOwnerProposals.map(proposal => {
            return <div key={proposal.id}>#{proposal.id}: proposes {proposal.address} (account {accountNums[proposal.address]})</div>
        })
        return (
            <div>
            <h3>New Spender Proposals</h3>
            <table border="1">
                <tr>
                    <th>Proposal id</th>
                    <th>Status</th>
                    <th>Proposed spender</th>
                    <th>1</th>
                    <th>2</th>
                    <th>3</th>
                    <th>4</th>
                    <th>5</th>
                    <th>Execute</th>
                </tr>
                {this.state.newOwnerProposals.map(p => this.renderProposal(p))}
            </table>
            </div>
        )
    }

    renderProposal(proposal) {
        const approveCells = [1, 2, 3, 4, 5].map(i => {
            const approved = proposal.approvals.includes(accounts[i]);
            const isAdmin = this.state.admins.includes(accounts[i])
            return <td key={i}>
                {isAdmin && !proposal.executed && !approved && <Button onClick={() => this.approve(proposal, i)}>Approve</Button>}
                {approved && "Approved"}
                {!isAdmin && "N/A"}
                {proposal.executed && isAdmin && !approved && "Didn't vote"}
                </td>
        })
        return <tr>
            <td>{proposal.id}</td>
            <td>{proposal.executed ? "Executed" : (proposal.approved ? "Approved" : "Pending")}</td>
            <td>{proposal.address} (account {accountNums[proposal.address]})</td>
            {approveCells}
    <td>{proposal.approved && !proposal.executed && <Button onClick={() => this.execute(proposal)}>Execute</Button>}</td>
        </tr>
    }

    approve(proposal, account) {
        wallet.methods.vote(proposal.id, true).send({from: accounts[account]})
    }

    execute(proposal) {
        wallet.methods.execute(proposal.id).send({from: accounts[2]})
    }

    proposeSetOwner(i) {
        console.log(`Proposing account ${i}: ${accounts[i]}`)
        wallet.methods.proposeSetOwner(accounts[i]).send({from: accounts[2], gas: 500000});
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
                Select an account to propose as the new spender:
                <Input type="select" onChange={(ev) => this.setState({i: ev.target.value})} value={this.state.i}>
                    {[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => <option value={i}>{i}</option>)}
                </Input>
                <Button onClick={() => this.props.proposeSetOwner(this.state.i)}>Submit</Button>
            </div>
        )
    }
}

const wrapper = document.getElementById("app");
wrapper ? ReactDOM.render(<App />, wrapper) : false;