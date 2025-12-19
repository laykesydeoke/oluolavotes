import React, { useState, useEffect } from 'react';
import { uintCV, trueCV, falseCV } from '@stacks/transactions';
import { getContractInfo, isVotingActive } from '../utils/votingApi';
import styled from 'styled-components';

const ProposalContainer = styled.div`
  background-color: #f9f9f9;
  border: 1px solid #ddd;
  border-radius: 4px;
  padding: 15px;
  margin-bottom: 15px;
`;

const ProposalHeader = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
`;

const Title = styled.h3`
  color: #333;
  margin: 0;
`;

const StatusBadge = styled.span`
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  background-color: ${props => {
    if (props.$status === 'active') return '#4CAF50';
    if (props.$status === 'passed') return '#2196F3';
    if (props.$status === 'rejected') return '#f44336';
    return '#999';
  }};
  color: white;
`;

const Description = styled.p`
  color: #666;
  margin-bottom: 15px;
  line-height: 1.5;
`;

const MetaInfo = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 10px;
  margin-bottom: 15px;
  padding: 10px;
  background-color: #fff;
  border-radius: 4px;
`;

const MetaItem = styled.div`
  display: flex;
  flex-direction: column;
`;

const MetaLabel = styled.span`
  font-size: 11px;
  color: #999;
  text-transform: uppercase;
  margin-bottom: 4px;
`;

const MetaValue = styled.span`
  font-size: 14px;
  color: #333;
  font-weight: 600;
`;

const VoteStats = styled.div`
  display: flex;
  gap: 20px;
  margin-bottom: 15px;
`;

const VoteCount = styled.div`
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 10px;
  background-color: #fff;
  border-radius: 4px;
  flex: 1;
`;

const VoteLabel = styled.span`
  font-size: 12px;
  color: #666;
  margin-bottom: 4px;
`;

const VoteNumber = styled.span`
  font-size: 24px;
  font-weight: bold;
  color: ${props => props.$type === 'for' ? '#4CAF50' : '#f44336'};
`;

const ButtonContainer = styled.div`
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
`;

const Button = styled.button`
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;
  transition: all 0.2s;

  &:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
`;

const VoteForButton = styled(Button)`
  background-color: #4CAF50;
  color: white;
`;

const VoteAgainstButton = styled(Button)`
  background-color: #f44336;
  color: white;
`;

const EndVotingButton = styled(Button)`
  background-color: #2196F3;
  color: white;
`;

const Proposal = ({ proposal, doContractCall, onVoteOrEnd }) => {
  const { contractAddress, contractName } = getContractInfo();
  const [votingActive, setVotingActive] = useState(true);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const checkVotingStatus = async () => {
      const active = await isVotingActive(proposal.proposalId);
      setVotingActive(active);
    };
    checkVotingStatus();
  }, [proposal.proposalId]);

  const handleVote = async (voteFor) => {
    setLoading(true);
    try {
      await doContractCall({
        contractAddress,
        contractName,
        functionName: 'vote',
        functionArgs: [uintCV(proposal.proposalId), voteFor ? trueCV() : falseCV()],
        onFinish: (data) => {
          console.log('Vote cast:', data);
          onVoteOrEnd();
          setLoading(false);
        },
        onCancel: () => {
          console.log('Voting cancelled');
          setLoading(false);
        },
      });
    } catch (error) {
      console.error('Error voting:', error);
      setLoading(false);
    }
  };

  const handleEndVoting = async () => {
    setLoading(true);
    try {
      await doContractCall({
        contractAddress,
        contractName,
        functionName: 'end-voting',
        functionArgs: [uintCV(proposal.proposalId)],
        onFinish: (data) => {
          console.log('Voting ended:', data);
          onVoteOrEnd();
          setLoading(false);
        },
        onCancel: () => {
          console.log('End voting cancelled');
          setLoading(false);
        },
      });
    } catch (error) {
      console.error('Error ending voting:', error);
      setLoading(false);
    }
  };

  const formatTimestamp = (timestamp) => {
    const date = new Date(timestamp * 1000);
    return date.toLocaleString();
  };

  const formatAddress = (address) => {
    return `${address.substring(0, 8)}...${address.substring(address.length - 6)}`;
  };

  const totalVotes = proposal.votesFor + proposal.votesAgainst;
  const votesForPercentage = totalVotes > 0 ? ((proposal.votesFor / totalVotes) * 100).toFixed(1) : 0;
  const votesAgainstPercentage = totalVotes > 0 ? ((proposal.votesAgainst / totalVotes) * 100).toFixed(1) : 0;

  return (
    <ProposalContainer>
      <ProposalHeader>
        <Title>#{proposal.proposalId}: {proposal.title}</Title>
        <StatusBadge $status={proposal.status}>{proposal.status}</StatusBadge>
      </ProposalHeader>

      <Description>{proposal.description}</Description>

      <MetaInfo>
        <MetaItem>
          <MetaLabel>Proposer</MetaLabel>
          <MetaValue title={proposal.proposer}>{formatAddress(proposal.proposer)}</MetaValue>
        </MetaItem>
        <MetaItem>
          <MetaLabel>Created At</MetaLabel>
          <MetaValue>{formatTimestamp(proposal.createdAt)}</MetaValue>
        </MetaItem>
        <MetaItem>
          <MetaLabel>Voting Ends</MetaLabel>
          <MetaValue>{formatTimestamp(proposal.endTime)}</MetaValue>
        </MetaItem>
        <MetaItem>
          <MetaLabel>Total Votes</MetaLabel>
          <MetaValue>{totalVotes}</MetaValue>
        </MetaItem>
      </MetaInfo>

      <VoteStats>
        <VoteCount>
          <VoteLabel>Votes For</VoteLabel>
          <VoteNumber $type="for">{proposal.votesFor}</VoteNumber>
          <MetaLabel>{votesForPercentage}%</MetaLabel>
        </VoteCount>
        <VoteCount>
          <VoteLabel>Votes Against</VoteLabel>
          <VoteNumber $type="against">{proposal.votesAgainst}</VoteNumber>
          <MetaLabel>{votesAgainstPercentage}%</MetaLabel>
        </VoteCount>
      </VoteStats>

      <ButtonContainer>
        <VoteForButton
          onClick={() => handleVote(true)}
          disabled={!votingActive || loading}
        >
          {loading ? 'Processing...' : 'Vote For'}
        </VoteForButton>
        <VoteAgainstButton
          onClick={() => handleVote(false)}
          disabled={!votingActive || loading}
        >
          {loading ? 'Processing...' : 'Vote Against'}
        </VoteAgainstButton>
        <EndVotingButton
          onClick={handleEndVoting}
          disabled={votingActive || loading}
        >
          {loading ? 'Processing...' : 'End Voting'}
        </EndVotingButton>
      </ButtonContainer>
    </ProposalContainer>
  );
};

export default Proposal;
