// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

/** 
 * @title Ballot
 * @dev Implements voting process along with vote delegation
 */
contract Ballot {
    // Maybe add the blacklist function
    event NewVoterRequest(uint proposalId, address beneficiary);
    event NewVoterApproved(uint proposalId, address beneficiary);
    event FundTransferRequest(uint proposalId, address beneficiary, uint amount);
    event FundTransferApproved(uint proposalId, address beneficiary, uint amount, uint blockTime);
    event RepayExtensionRequest(uint proposalId);
    event RepayExtensionApproved(uint proposalId, uint blockTime);
    event LoanWaiverRequest(uint proposalId);
    event LoanWaiverApproved(uint proposalId);
    event LoanRepaid(uint proposalId, address payer);

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
        // Types:
        // 0: New Member
        // 1: Fund Transfer
        // 2: Repay Extension
        // 3: Loan Waiver
        uint8 propType; 
        uint priorProposalId; // id of prior proposal for repay and waiver
        bytes ipfsHash;   // IPFS hash of the application
        uint amount; // For fund borrowing proposal
        address beneficiary; // Address to be member or to take funds 
        uint voteCount; // number of accumulated votes
        bool approved;  // if the proposal has been approved
    }

    struct FundsAlloted {
        address beneficiary;    // The benefitting address
        uint amount;    // Amount of loan
        uint amountRecievedBack; // Amount the beneficiary has repaid
        uint blockTime; // Time when the funds were sent
        bool paidBack; // If amount has been paid back
    }

    // Map address to proposalId to ProposalInfo for the voter
    mapping(address => Voter) public voters;
    uint public numVoters;

    Proposal[] public proposals;

    mapping(uint => FundsAlloted) public proposalIdToFunds;

    constructor() {
        voters[msg.sender].isVoter = true;
        numVoters++;
    }
    
    /** 
     * @dev Adds proposal to add new voter, emits NewVoterRequest event
     * @param applicationHash IPFS hash of the application to retrieve
     */
    function addVoterProposal(bytes memory applicationHash) public returns(uint) {
        require(voters[msg.sender].isVoter != true, "msg.sender is already a voter");
        Proposal memory prop = Proposal(0, 0, applicationHash, 0, msg.sender, 0, false);
        proposals.push(prop);

        emit NewVoterRequest(proposals.length - 1, msg.sender);
        
        return proposals.length - 1;
    }

    function approveVoterProposal(uint proposalId) virtual public validProposal(proposalId) ofPropType(proposalId, 0) returns(bool)  {
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
        Proposal memory prop = Proposal(1, 0, applicationHash, amount, msg.sender, 0, false);
        proposals.push(prop);

        emit FundTransferRequest(proposals.length - 1, msg.sender, amount);
        
        vote(proposals.length - 1);
        return proposals.length - 1;
    }

    function approveFundTransferProposal(uint proposalId) public onlyVoter validProposal(proposalId) ofPropType(proposalId, 1) returns(bool) {
        {
            uint amount = proposals[proposalId].amount;
            _beforeFundTransferApproved(amount);
        }

        Proposal storage prop = proposals[proposalId];
        uint numVotes = prop.voteCount;

        if (numVotes >= numVoters / 2 + 1) {
            // SuperApp can crawl through proposalIdToFunds in view mode to find all non-paid and defaulters
            proposalIdToFunds[proposalId] = FundsAlloted(prop.beneficiary, prop.amount, 0, block.timestamp, false);
            prop.approved = true;
            emit FundTransferApproved(proposalId, prop.beneficiary, prop.amount, block.timestamp);
        } else {
            revert("Proposal has not acquirred enough votes");
        }

        _afterFundTransferApproved();
        
        return prop.approved;
    }

    function addRepayExtensionProposal(bytes memory applicationHash, uint proposalId) public onlyVoter validProposal(proposalId) returns(uint) {
        proposals.push(Proposal(2, proposalId, applicationHash, 0, msg.sender, 0, false));

        emit RepayExtensionRequest(proposalId);
        
        vote(proposals.length - 1);
        return proposals.length - 1;
    }

    function approveRepayExtensionProposal(uint proposalId) public onlyVoter validProposal(proposalId) ofPropType(proposalId, 1) returns(bool) {
        Proposal storage prop = proposals[proposalId];
        uint numVotes = prop.voteCount;

        if (numVotes >= numVoters / 2 + 1) {
            FundsAlloted storage fundDescr = proposalIdToFunds[prop.priorProposalId];
            fundDescr.blockTime = block.timestamp; // Actual logic

            prop.approved = true;
            emit RepayExtensionApproved(prop.priorProposalId, block.timestamp);
        } else {
            revert("Proposal has not acquirred enough votes");
        }

        return prop.approved;
    }

    function addLoanWaiverProposal(bytes memory applicationHash, uint proposalId) public onlyVoter validProposal(proposalId) ofPropType(proposalId, 1) returns(uint) {
        proposals.push(Proposal(3, proposalId, applicationHash, 0, msg.sender, 0, false));

        emit LoanWaiverRequest(proposalId);
        
        vote(proposals.length - 1);
        return proposals.length - 1;
    }

    function approveLoanWaiverProposal(uint proposalId) public onlyVoter validProposal(proposalId) ofPropType(proposalId, 2) returns(bool) {
        Proposal storage prop = proposals[proposalId];
        uint numVotes = prop.voteCount;

        if (numVotes >= numVoters / 2 + 1) {
            FundsAlloted storage fundDescr = proposalIdToFunds[prop.priorProposalId];
            fundDescr.paidBack = true; // Actual logic

            prop.approved = true;
            emit LoanWaiverApproved(prop.priorProposalId);
        } else {
            revert("Proposal has not acquirred enough votes");
        }
                
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
    
    function _revokeVoteRight(address voter) private {
        voters[voter].isVoter = false;
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

    modifier ofPropType(uint proposalId, uint8 _propType) {
        require(proposals[proposalId].propType == _propType, "proposal is of different type");
        _;
    }

    // ***************************************************
    // HOOKS
    // ***************************************************

    // Called in approveFundTransferRequest before core logic, can be used for reverts
    function _beforeFundTransferApproved(uint amount) private {}
    // Called in approveFundTransferRequest after core logic, before return
    function _afterFundTransferApproved() private {}
}