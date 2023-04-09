# Auto-Compounding Vault Project

In this project, we will build a smart contract that will allow users to deposit and withdraw funds from a vault. 
The vault will automatically compound the interest generated from the deposited funds and allow users to withdraw 
their principal and interest at any time.
<br>
The funds are invested in Lido and Curve Staking Pools.
<br>
For the convenience of testing I have made a custom version of Lido and Curve Staking contracts.
The rewards generated from the staking pools linearly increase over time.


```shell
npx hardhat test
```
