import { callReadOnlyFunction, uintCV, cvToJSON } from '@stacks/transactions';
import { StacksMainnet } from '@stacks/network';

const network = new StacksMainnet();
const contractAddress = 'SP221GWG1PPN83A1TA81DGDWG0V1E21QMKZTGXJ3B';
const contractName = 'oluolavotes';

// Contract addresses for all deployed contracts
export const CONTRACTS = {
  OLUOLAVOTES: {
    address: contractAddress,
    name: 'oluolavotes'
  },
  VOTING_TOKEN: {
    address: contractAddress,
    name: 'voting-token'
  },
  ACCESS_CONTROL: {
    address: contractAddress,
    name: 'access-control'
  },
  PROPOSAL_EXECUTION: {
    address: contractAddress,
    name: 'proposal-execution'
  },
  VOTE_DELEGATION: {
    address: contractAddress,
    name: 'vote-delegation'
  },
  VOTING_STRATEGY: {
    address: contractAddress,
    name: 'voting-strategy'
  },
  VOTING_ANALYTICS: {
    address: contractAddress,
    name: 'voting-analytics'
  }
};

// Get proposal count
export const getProposalCount = async () => {
  try {
    const result = await callReadOnlyFunction({
      contractAddress,
      contractName,
      functionName: 'get-proposal-count',
      functionArgs: [],
      network,
      senderAddress: contractAddress,
    });

    const jsonResult = cvToJSON(result);
    return jsonResult.value ? parseInt(jsonResult.value.value) : 0;
  } catch (error) {
    console.error('Error fetching proposal count:', error);
    return 0;
  }
};

// Fetch a single proposal by ID
export const fetchProposal = async (proposalId) => {
  try {
    const result = await callReadOnlyFunction({
      contractAddress,
      contractName,
      functionName: 'get-proposal',
      functionArgs: [uintCV(proposalId)],
      network,
      senderAddress: contractAddress,
    });

    const jsonResult = cvToJSON(result);

    if (jsonResult.success && jsonResult.value) {
      const proposalData = jsonResult.value.value;
      return {
        proposalId,
        title: proposalData.title.value,
        description: proposalData.description.value,
        proposer: proposalData.proposer.value,
        votesFor: parseInt(proposalData['votes-for'].value),
        votesAgainst: parseInt(proposalData['votes-against'].value),
        endTime: parseInt(proposalData['end-time'].value),
        createdAt: parseInt(proposalData['created-at'].value),
        executed: proposalData.executed.value,
        quorum: parseInt(proposalData.quorum.value),
        status: proposalData.status.value
      };
    }
    return null;
  } catch (error) {
    console.error(`Error fetching proposal ${proposalId}:`, error);
    return null;
  }
};

// Fetch all proposals
export const fetchProposals = async () => {
  try {
    const count = await getProposalCount();
    const proposals = [];

    for (let i = 1; i <= count; i++) {
      const proposal = await fetchProposal(i);
      if (proposal) {
        proposals.push(proposal);
      }
    }

    return proposals;
  } catch (error) {
    console.error('Error fetching proposals:', error);
    return [];
  }
};

// Get voting results for a proposal
export const getVotingResults = async (proposalId) => {
  try {
    const result = await callReadOnlyFunction({
      contractAddress,
      contractName,
      functionName: 'get-voting-results',
      functionArgs: [uintCV(proposalId)],
      network,
      senderAddress: contractAddress,
    });

    const jsonResult = cvToJSON(result);

    if (jsonResult.success && jsonResult.value) {
      const resultsData = jsonResult.value.value;
      return {
        votesFor: parseInt(resultsData['votes-for'].value),
        votesAgainst: parseInt(resultsData['votes-against'].value),
        totalVotes: parseInt(resultsData['total-votes'].value),
        status: resultsData.status.value
      };
    }
    return null;
  } catch (error) {
    console.error(`Error fetching voting results for proposal ${proposalId}:`, error);
    return null;
  }
};

// Check if voting is active for a proposal
export const isVotingActive = async (proposalId) => {
  try {
    const result = await callReadOnlyFunction({
      contractAddress,
      contractName,
      functionName: 'is-voting-active',
      functionArgs: [uintCV(proposalId)],
      network,
      senderAddress: contractAddress,
    });

    const jsonResult = cvToJSON(result);
    return jsonResult.success && jsonResult.value ? jsonResult.value.value : false;
  } catch (error) {
    console.error(`Error checking if voting is active for proposal ${proposalId}:`, error);
    return false;
  }
};

// Get user's vote for a proposal
export const getUserVote = async (voter, proposalId) => {
  try {
    const result = await callReadOnlyFunction({
      contractAddress,
      contractName,
      functionName: 'get-vote',
      functionArgs: [
        { type: 'principal', value: voter },
        uintCV(proposalId)
      ],
      network,
      senderAddress: contractAddress,
    });

    const jsonResult = cvToJSON(result);

    if (jsonResult.success && jsonResult.value) {
      const voteData = jsonResult.value.value;
      return {
        vote: voteData.vote.value,
        timestamp: parseInt(voteData.timestamp.value)
      };
    }
    return null;
  } catch (error) {
    // User hasn't voted yet
    return null;
  }
};

export const getContractInfo = () => ({
  contractAddress,
  contractName,
  network
});
