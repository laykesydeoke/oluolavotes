import React from 'react';
import { uintCV, trueCV, falseCV } from '@stacks/transactions';
import { getContractInfo } from '../utils/votingApi';
import styled from 'styled-components';

const ProposalContainer = styled.div`
  background-color: #f9f9f9;
  border: 1px solid #ddd;
  border-radius: 4px;
  padding: 15px;
  margin-bottom: 15px;
`;

const Title = styled.h3`
  color: #333;
  margin-bottom: 10px;
`;

const Description = styled.p`
  color: #666;
  margin-bottom: 10px;
`;

const VoteCount = styled.p`
  font-weight: bold;
  margin-bottom: 5px;
`;

const ButtonContainer = styled.div`
  display: flex;
  gap: 10px;
`;

const Button = styled.button`
  padding: 5px 10px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;

  &:hover {
    opacity: 0.8;
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

  const handleVote = async (voteFor) => {
    await doContractCall({
      contractAddress,
      contractName,
      functionName: 'vote',
      functionArgs: [uintCV(proposal.proposalId), voteFor ? trueCV() : falseCV()],
      onFinish: (data) => {
        console.log('Vote cast:', data);
        onVoteOrEnd();
      },
      onCancel: () => {
        console.log('Voting cancelled');
      },
    });
  };

  const handleEndVoting = async () => {
    await doContractCall({
      contractAddress,
      contractName,
      functionName: 'end-voting',
      functionArgs: [uintCV(proposal.proposalId)],
      onFinish: (data) => {
        console.log('Voting ended:', data);
        onVoteOrEnd();
      },
      onCancel: () => {
        console.log('End voting cancelled');
      },
    });
  };

  return (
    <ProposalContainer>
      <Title>{proposal.title}</Title>
      <Description>{proposal.description}</Description>
      <VoteCount>Votes For: {proposal.votesFor}</VoteCount>
      <VoteCount>Votes Against: {proposal.votesAgainst}</VoteCount>
      <ButtonContainer>
        <VoteForButton onClick={() => handleVote(true)}>Vote For</VoteForButton>
        <VoteAgainstButton onClick={() => handleVote(false)}>Vote Against</VoteAgainstButton>
        <EndVotingButton onClick={handleEndVoting}>End Voting</EndVotingButton>
      </ButtonContainer>
    </ProposalContainer>
  );
};

export default Proposal;
