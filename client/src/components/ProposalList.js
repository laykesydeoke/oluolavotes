import React from 'react';
import Proposal from './Proposal';
import styled from 'styled-components';

const ProposalListContainer = styled.div`
  background-color: #fff;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
`;

const Title = styled.h2`
  color: #333;
  margin-bottom: 15px;
`;

const ProposalList = ({ proposals, doContractCall, onVoteOrEnd }) => {
  return (
    <ProposalListContainer>
      <Title>Proposals</Title>
      {proposals.map((proposal) => (
        <Proposal
          key={proposal.proposalId}
          proposal={proposal}
          doContractCall={doContractCall}
          onVoteOrEnd={onVoteOrEnd}
        />
      ))}
    </ProposalListContainer>
  );
};

export default ProposalList;
