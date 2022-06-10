import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployMockContract, MockContract } from "@ethereum-waffle/mock-contract";
import { ethers } from "hardhat";
import { MADAO, IERC20__factory } from "../typechain-types";
import { delay } from "../scripts/misc";
import { BigNumber } from "ethers";

describe("MA DAO", () => {
    let chairperson: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;
    let contract: MADAO;
    let voteToken: MockContract;
    let callData: string;

    const proposalId = 1;
    const duration = BigNumber.from(3 * 24 * 60 * 60);// 3 days in seconds

    beforeEach(async () => {
        [chairperson, user1, user2] = await ethers.getSigners();
        voteToken = await deployMockContract(chairperson, IERC20__factory.abi);
        await voteToken.mock.transferFrom.returns(true);
        
        const f = await ethers.getContractFactory("MADAO", chairperson);
        contract = <MADAO>await f.deploy(chairperson.address, voteToken.address, 1000, duration);

        callData = IERC20__factory.createInterface().encodeFunctionData(
            "transferFrom", 
            [contract.address, chairperson.address, 1000]
        );

        await contract.deployed();

        await contract.addProposal(
            voteToken.address,
            callData,
            "transfer 1000 vote tokens to chairperson"
        );
    })

    describe("delegate", () => {
        it("should work", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user1).delegate(user2.address, proposalId);
        });

        it("should use delegated votes in voting", async () => {
            const amount = 1000;
            await contract.connect(user1).deposit(amount);
            await contract.connect(user2).deposit(amount);
            
            await contract.connect(user2).delegate(user1.address, proposalId);
            await contract.connect(user1).vote(proposalId, true);

            const p = await contract.getProposal(proposalId);
            expect(p.votesFor).eq(amount*2);
        });

        it("should be reverted if no deposit", async () => {
            const tx = contract.connect(user1).delegate(user2.address, proposalId);
            await expect(tx).to.be.revertedWith("MADAO: no deposit");
        });

        it("should be reverted if voted already", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user1).vote(proposalId, true);

            const tx = contract.connect(user1).delegate(user2.address, proposalId);
            await expect(tx).to.be.revertedWith("MADAO: voted already");
        });

        it("should be reverted if a delegate voted already", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user2).deposit(1000);
            await contract.connect(user2).vote(proposalId, true);

            const tx = contract.connect(user1).delegate(user2.address, proposalId);
            await expect(tx).to.be.revertedWith("MADAO: delegate voted already");
        });

        it("should be reverted if delegated already", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user1).delegate(chairperson.address, proposalId);

            const tx = contract.connect(user1).delegate(user2.address, proposalId);
            await expect(tx).to.be.revertedWith("MADAO: voted already");
        });

        it("should be reverted if voting doesn't exist", async () => {
            const tx1 = contract.connect(user1).delegate(user2.address, 123);
            await expect(tx1).to.be.revertedWith("MADAO: no such voting");

            const tx2 = contract.connect(user1).delegate(user2.address, 0);
            await expect(tx2).to.be.revertedWith("MADAO: no such voting");
        });
    });
});