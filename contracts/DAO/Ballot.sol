// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

/** 
 * @title Ballot
 * @dev Implements voting process along with vote delegation
 */
contract Ballot {
    event NewVoterRequest(uint proposalId, address beneficiary);
    event NewVoterApproved(uint proposalId, address beneficiary);
    event FundTransferRequest(uint proposalId, address beneficiary, uint amount);
    event FundTransferApproved(uint proposalId, address beneficiary, uint amount, uint blockTime);

    struct VoterProposalInfo {
        bool interacted; // if the voter has interacted with a proposal
        uint weight;
        bool voted;
        address delegate;
    }

    struct Voter {
        bool isVoter; // Used for onlyVoter modifier
        mapping(uint => VoterProposalInfo) inProposal;
    }

    struct Proposal {
        bytes ipfsHash;   // IPFS hash of the application
        uint amount; // For fund borrowing proposal
        address beneficiary; // Address to be member or to take funds 
        uint voteCount; // number of accumulated votes
        bool approved;  // if the proposal has been approved
    }

    struct FundsAlloted {
        address beneficiary;
        uint amount;
        uint blockTime;
        bool fundsSent;
        bool paidBack; // If amount has been paid back
    }

    address public chairperson; // Creator of the ballot
    // Map address to proposalId to ProposalInfo for the voter
    mapping(address => Voter) public voters;
    uint public numVoters;

    Proposal[] public proposals;

    mapping(uint => FundsAlloted) public proposalIdToFunds;

    constructor() {
        chairperson = msg.sender;
        Voter storage cp = voters[chairperson];
        cp.isVoter = true;
        numVoters++;
    }
    
    /** 
     * @dev Adds proposal to add new voter, emits NewVoterRequest event
     * @param applicationHash IPFS hash of the application to retrieve
     */
    function addVoterProposal(bytes memory applicationHash) public returns(uint) {
        require(voters[msg.sender].isVoter != true, "msg.sender is already a voter");
        Proposal memory prop = Proposal(applicationHash, 0, msg.sender, 0, false);
        proposals.push(prop);

        emit NewVoterRequest(proposals.length - 1, msg.sender);
        
        return proposals.length - 1;
    }

    function approveVoterProposal(uint proposalId) public validProposal(proposalId) returns(bool) {
        Proposal storage prop = proposals[proposalId];
        uint numVotes = prop.voteCount;

        if (numVotes >= numVoters / 2 + 1) {
            Voter storage newVoter = voters[prop.beneficiary];
            newVoter.isVoter = true;
            numVoters++;
            prop.approved = true;
            emit NewVoterApproved(proposalId, prop.beneficiary);
        } else {
            revert("Proposal has not acquirred enough votes");
        }
        
        return prop.approved;
    }

     /** 
     * @dev Adds proposal to take out funds, emits FundTransferRequest event
     * @param applicationHash IPFS hash of the application to retrieve
     * @param amount to transfer to beneficiary from pool
     */
    function addFundTransferProposal(bytes memory applicationHash, uint amount) public onlyVoter returns(uint) {
        Proposal memory prop = Proposal(applicationHash, amount, msg.sender, 0, false);
        proposals.push(prop);

        emit FundTransferRequest(proposals.length - 1, msg.sender, amount);
        
        vote(proposals.length - 1);
        return proposals.length - 1;
    }

    function approveFundTransferProposal(uint proposalId) public validProposal(proposalId) returns(bool) {
        Proposal storage prop = proposals[proposalId];
        uint numVotes = prop.voteCount;

        if (numVotes >= numVoters / 2 + 1) {
            // SuperApp can crawl through proposalIdToFunds in view mode to find all non-paid and defaulters
            proposalIdToFunds[proposalId] = FundsAlloted(prop.beneficiary, prop.amount, block.timestamp, false, false);
            prop.approved = true;
            emit FundTransferApproved(proposalId, prop.beneficiary, prop.amount, block.timestamp);
        } else {
            revert("Proposal has not acquirred enough votes");
        }

        _afterFundTransferApproved();
        
        return prop.approved;
    }

    /**
     * @dev Delegate your vote to the voter 'to'.
     * @param to address to which vote is delegated
     */
    function delegate(address to, uint proposalId) public validProposal(proposalId) {
        Voter storage sender = voters[msg.sender];
        _setProposalInteracted(proposalId);

        require(!sender.inProposal[proposalId].voted, "You already voted.");
        require(to != msg.sender, "Self-delegation is disallowed.");
        require(voters[to].isVoter, "address delegated to is not a voter.");

        while (voters[to].inProposal[proposalId].delegate != address(0)) {
            to = voters[to].inProposal[proposalId].delegate;

            // We found a loop in the delegation, not allowed.
            require(to != msg.sender, "Found loop in delegation.");
        }

        sender.inProposal[proposalId].voted = true;
        sender.inProposal[proposalId].delegate = to;
        Voter storage delegate_ = voters[to];
        if (delegate_.inProposal[proposalId].voted) {
            // If the delegate already voted,
            // directly add to the number of votes
            proposals[proposalId].voteCount += sender.inProposal[proposalId].weight;
        } else {
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.inProposal[proposalId].weight += sender.inProposal[proposalId].weight;
        }
    }

    /**
     * @dev Give your vote (including votes delegated to you) to proposal 'proposals[proposal].name'.
     * @param proposalId index of proposal in the proposals array
     */
    function vote(uint proposalId) public onlyVoter validProposal(proposalId) {
        Voter storage sender = voters[msg.sender];
        _setProposalInteracted(proposalId);

        require(sender.inProposal[proposalId].weight != 0, "No voting right available. Vote might have been delegated.");
        require(!sender.inProposal[proposalId].voted, "Already voted.");
        sender.inProposal[proposalId].voted = true;

        // If 'proposal' is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        proposals[proposalId].voteCount += sender.inProposal[proposalId].weight;
    }

    function _setProposalInteracted(uint proposalId) private validProposal(proposalId) {
        Voter storage sender = voters[msg.sender];
        if(!sender.inProposal[proposalId].interacted) {
            sender.inProposal[proposalId].weight += 1;
            sender.inProposal[proposalId].interacted = true;
        }
    }
    
    function _revokeVoteRight(address adx) private {
        voters[adx].isVoter = false;
    }

    // function addressIsVoter(address adx) public view returns(bool) {
    //     return voters[adx].isVoter;
    // }
    
    // function getVoterProposalData(address voter, uint proposalId) public view validProposal(proposalId) returns(bool, uint, bool, address) {
    //     VoterProposalInfo memory tmp = voters[voter].inProposal[proposalId];
    //     return (tmp.interacted, tmp.weight, tmp.voted, tmp.delegate);
    // }

    // ***************************************************
    // MODIFIERS
    // ***************************************************
    modifier onlyVoter {
        require(voters[msg.sender].isVoter == true, "msg.sender is not a voter");
        _;
    }
    
    modifier validProposal(uint proposalId) {
        require(proposalId < proposals.length, "invalid proposalId");
        _;
    }

    // ***************************************************
    // HOOKS
    // ***************************************************

    // Called in approveFundTransferRequest after core logic, before return
    function _afterFundTransferApproved() private {}
}