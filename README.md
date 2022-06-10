# MA DAO

Here is the first version of the MADAO voting contract (without delegate func): https://rinkeby.etherscan.io/address/0x0A8d47EAa94FAfD347203F5bf613953B26ECe704#code

Here is the second version with delegate functionality: https://rinkeby.etherscan.io/address/0x7fA90544E76bF25F5D3a07F195923bc4340eC8BB

Both use MADv2 tokens (https://rinkeby.etherscan.io/token/0x1A13F7fB13BCa03FF646702C6Af9D699729A0C1d) as vote tokens.
10 minutes for voting, 20 votes is the minimum number of votes.

All this options are set up in the contract's constructor.

The next tasks can be used to communicate with a deployed MADAO contract:
```
  accounts              Prints the list of accounts
  add-proposal          Starts a new voting for the specified proposal
  delegate              Allows to delegate deposited votes
  deposit               Transfers vote-tokens to the contract to use them in votings
  finish                Allows to finish a voting
  vote                  Adds a new vote from a voter for or against a proposal
  withdraw              Requests vote-tokens back from the contract
```
