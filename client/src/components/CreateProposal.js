import React, { useState } from 'react';
import { stringUtf8CV } from '@stacks/transactions';
import { getContractInfo } from '../utils/votingApi';
import styled from 'styled-components';

const CreateProposalContainer = styled.div`
  background-color: #fff;
  border-radius: 8px;
  padding: 20px;
  margin-bottom: 20px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
`;

const Title = styled.h2`
  color: #333;
  margin-bottom: 15px;
`;

const Input = styled.input`
  width: 100%;
  padding: 10px;
  margin-bottom: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
`;

const Button = styled.button`
  background-color: #4CAF50;
  color: white;
  padding: 10px 15px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 16px;

  &:hover {
    background-color: #45a049;
  }
`;

const CreateProposal = ({ doContractCall, onProposalCreated }) => {
  const [newProposal, setNewProposal] = useState({ title: '', description: '' });
  const { contractAddress, contractName } = getContractInfo();

  const handleCreateProposal = async () => {
    await doContractCall({
      contractAddress,
      contractName,
      functionName: 'create-proposal',
      functionArgs: [stringUtf8CV(newProposal.title), stringUtf8CV(newProposal.description)],
      onFinish: (data) => {
        console.log('Proposal created:', data);
        onProposalCreated();
        setNewProposal({ title: '', description: '' });
      },
      onCancel: () => {
        console.log('Proposal creation cancelled');
      },
    });
  };

  return (
    <CreateProposalContainer>
      <Title>Create Proposal</Title>
      <Input
        type="text"
        placeholder="Title"
        value={newProposal.title}
        onChange={(e) => setNewProposal({ ...newProposal, title: e.target.value })}
      />
      <Input
        type="text"
        placeholder="Description"
        value={newProposal.description}
        onChange={(e) => setNewProposal({ ...newProposal, description: e.target.value })}
      />
      <Button onClick={handleCreateProposal}>Create Proposal</Button>
    </CreateProposalContainer>
  );
};

export default CreateProposal;
