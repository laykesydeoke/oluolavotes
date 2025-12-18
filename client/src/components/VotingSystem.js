import React, { useState, useEffect } from 'react';
import { useConnect } from '@stacks/connect-react';
import { fetchProposals } from '../utils/votingApi';
import ProposalList from './ProposalList';
import CreateProposal from './CreateProposal';
import styled from 'styled-components';

const VotingSystemContainer = styled.div`
  background-color: #f5f5f5;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
`;

const Title = styled.h1`
  color: #333;
  text-align: center;
  margin-bottom: 20px;
`;

const VotingSystem = () => {
  const { doContractCall } = useConnect();
  const [proposals, setProposals] = useState([]);

  useEffect(() => {
    const getProposals = async () => {
      const fetchedProposals = await fetchProposals();
      setProposals(fetchedProposals);
    };
    getProposals();
  }, []);

  const refreshProposals = async () => {
    const fetchedProposals = await fetchProposals();
    setProposals(fetchedProposals);
  };

  return (
    <VotingSystemContainer>
      <Title>Decentralized Voting System</Title>
      <CreateProposal doContractCall={doContractCall} onProposalCreated={refreshProposals} />
      <ProposalList proposals={proposals} doContractCall={doContractCall} onVoteOrEnd={refreshProposals} />
    </VotingSystemContainer>
  );
};

export default VotingSystem;
