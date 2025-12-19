import React, { useState, useEffect } from 'react';
import { useConnect } from '@stacks/connect-react';
import { fetchProposals } from '../utils/votingApi';
import { userSession } from '../utils/userSession';
import ProposalList from './ProposalList';
import CreateProposal from './CreateProposal';
import WalletConnect from './WalletConnect';
import styled from 'styled-components';

const VotingSystemContainer = styled.div`
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
`;

const Header = styled.div`
  background: linear-gradient(135deg, #5546FF 0%, #4235E8 100%);
  border-radius: 12px;
  padding: 30px;
  margin-bottom: 30px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
`;

const Title = styled.h1`
  color: white;
  text-align: center;
  margin: 0 0 10px 0;
  font-size: 32px;
`;

const Subtitle = styled.p`
  color: rgba(255, 255, 255, 0.9);
  text-align: center;
  margin: 0;
  font-size: 16px;
`;

const LoadingContainer = styled.div`
  background-color: #fff;
  border-radius: 8px;
  padding: 40px;
  text-align: center;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
`;

const LoadingSpinner = styled.div`
  border: 4px solid #f3f3f3;
  border-top: 4px solid #5546FF;
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 1s linear infinite;
  margin: 0 auto 15px;

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
`;

const LoadingText = styled.p`
  color: #666;
  font-size: 14px;
`;

const ErrorContainer = styled.div`
  background-color: #fff3f3;
  border: 1px solid #ffcdd2;
  border-radius: 8px;
  padding: 20px;
  margin-bottom: 20px;
`;

const ErrorTitle = styled.h3`
  color: #c62828;
  margin: 0 0 10px 0;
`;

const ErrorMessage = styled.p`
  color: #d32f2f;
  margin: 0 0 15px 0;
`;

const RetryButton = styled.button`
  background-color: #f44336;
  color: white;
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;

  &:hover {
    background-color: #d32f2f;
  }
`;

const EmptyState = styled.div`
  background-color: #fff;
  border-radius: 8px;
  padding: 60px 20px;
  text-align: center;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
`;

const EmptyIcon = styled.div`
  font-size: 64px;
  margin-bottom: 20px;
  opacity: 0.3;
`;

const EmptyTitle = styled.h3`
  color: #333;
  margin: 0 0 10px 0;
`;

const EmptyMessage = styled.p`
  color: #666;
  margin: 0;
  font-size: 14px;
`;

const VotingSystem = () => {
  const { doContractCall, isSignedIn } = useConnect();
  const [proposals, setProposals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadProposals();
  }, []);

  const loadProposals = async () => {
    setLoading(true);
    setError(null);
    try {
      const fetchedProposals = await fetchProposals();
      setProposals(fetchedProposals);
    } catch (err) {
      console.error('Error loading proposals:', err);
      setError('Failed to load proposals. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const refreshProposals = async () => {
    try {
      const fetchedProposals = await fetchProposals();
      setProposals(fetchedProposals);
    } catch (err) {
      console.error('Error refreshing proposals:', err);
    }
  };

  return (
    <VotingSystemContainer>
      <Header>
        <Title>OluolaVotes</Title>
        <Subtitle>Decentralized Governance Platform</Subtitle>
      </Header>

      <WalletConnect />

      {isSignedIn && userSession.isUserSignedIn() && (
        <CreateProposal doContractCall={doContractCall} onProposalCreated={refreshProposals} />
      )}

      {error && (
        <ErrorContainer>
          <ErrorTitle>Error</ErrorTitle>
          <ErrorMessage>{error}</ErrorMessage>
          <RetryButton onClick={loadProposals}>Retry</RetryButton>
        </ErrorContainer>
      )}

      {loading ? (
        <LoadingContainer>
          <LoadingSpinner />
          <LoadingText>Loading proposals...</LoadingText>
        </LoadingContainer>
      ) : proposals.length === 0 ? (
        <EmptyState>
          <EmptyIcon>📋</EmptyIcon>
          <EmptyTitle>No Proposals Yet</EmptyTitle>
          <EmptyMessage>
            {isSignedIn && userSession.isUserSignedIn()
              ? 'Be the first to create a proposal!'
              : 'Connect your wallet to create the first proposal.'}
          </EmptyMessage>
        </EmptyState>
      ) : (
        <ProposalList proposals={proposals} doContractCall={doContractCall} onVoteOrEnd={refreshProposals} />
      )}
    </VotingSystemContainer>
  );
};

export default VotingSystem;
