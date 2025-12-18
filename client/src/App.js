import React from 'react';
import { Connect } from '@stacks/connect-react';
import VotingSystem from './components/VotingSystem';
import styled from 'styled-components';

const AppContainer = styled.div`
  font-family: Arial, sans-serif;
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
`;

const App = () => {
  const appDetails = {
    name: 'Decentralized Voting System',
    icon: './logo.png',
  };

  return (
    <Connect authOptions={{ appDetails }}>
      <AppContainer>
        <VotingSystem />
      </AppContainer>
    </Connect>
  );
};

export default App;
