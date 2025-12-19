import React from 'react';
import { useConnect } from '@stacks/connect-react';
import { userSession } from '../utils/userSession';
import styled from 'styled-components';

const WalletContainer = styled.div`
  background-color: #fff;
  border-radius: 8px;
  padding: 15px 20px;
  margin-bottom: 20px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: space-between;
  align-items: center;
`;

const WalletInfo = styled.div`
  display: flex;
  flex-direction: column;
`;

const Label = styled.span`
  font-size: 12px;
  color: #666;
  margin-bottom: 4px;
`;

const Address = styled.span`
  font-size: 14px;
  color: #333;
  font-family: monospace;
`;

const Button = styled.button`
  background-color: #5546FF;
  color: white;
  padding: 10px 20px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;

  &:hover {
    background-color: #4235E8;
  }

  &:disabled {
    background-color: #ccc;
    cursor: not-allowed;
  }
`;

const WalletConnect = () => {
  const { doOpenAuth, isSignedIn, authOptions } = useConnect();
  const [userData, setUserData] = React.useState(null);

  React.useEffect(() => {
    if (isSignedIn && userSession.isUserSignedIn()) {
      const data = userSession.loadUserData();
      setUserData(data);
    }
  }, [isSignedIn]);

  const handleSignIn = () => {
    doOpenAuth();
  };

  const handleSignOut = () => {
    userSession.signUserOut();
    setUserData(null);
    window.location.reload();
  };

  const truncateAddress = (address) => {
    if (!address) return '';
    return `${address.substring(0, 8)}...${address.substring(address.length - 6)}`;
  };

  return (
    <WalletContainer>
      {userData ? (
        <>
          <WalletInfo>
            <Label>Connected Wallet</Label>
            <Address title={userData.profile.stxAddress.mainnet}>
              {truncateAddress(userData.profile.stxAddress.mainnet)}
            </Address>
          </WalletInfo>
          <Button onClick={handleSignOut}>Disconnect</Button>
        </>
      ) : (
        <>
          <WalletInfo>
            <Label>Connect your Stacks wallet to interact with proposals</Label>
          </WalletInfo>
          <Button onClick={handleSignIn}>Connect Wallet</Button>
        </>
      )}
    </WalletContainer>
  );
};

export default WalletConnect;
