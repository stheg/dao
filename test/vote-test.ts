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

    describe("vote", () => {
        it("should work", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user1).vote(proposalId, true);
        });

        it("should increase votes for the proposal", async () => {
            const amount = 1000;
            await contract.connect(user1).deposit(amount);
            await contract.connect(user1).vote(proposalId, true);

            const p = await contract.getProposal(proposalId);
            expect(p.votesFor).eq(amount);
        });

        it("should increase votes against the proposal", async () => {
            const amount = 1000;
            await contract.connect(user1).deposit(amount);
            await contract.connect(user1).vote(proposalId, false);

            const p = await contract.getProposal(proposalId);
            expect(p.votesAgainst).eq(amount);
        });

        it("should be possible to vote in 2+ votings using the same deposit", async () => {
            await contract.addProposal(
                voteToken.address,
                callData,
                "transfer 1000 vote tokens to chairperson second time"
            );
            const secondProposalId = proposalId + 1;

            const amount = 1000;
            await contract.connect(user1).deposit(amount);
            
            await contract.connect(user1).vote(proposalId, true);
            await contract.connect(user1).vote(secondProposalId, false);

            const p1 = await contract.getProposal(proposalId);
            const p2 = await contract.getProposal(secondProposalId);
            expect(p1.votesFor).eq(p2.votesAgainst);
        });
        
        it("should be reverted if no deposit", async () => {
            const tx = contract.connect(user1).vote(proposalId, true);
            await expect(tx).to.be.revertedWith("MADAO: no deposit");
        });

        it("should be reverted if voted already", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user1).vote(proposalId, true);

            const tx = contract.connect(user1).vote(proposalId, true);
            await expect(tx).to.be.revertedWith("MADAO: voted already");
        });

        it("should be reverted if voting period ended", async () => {
            await contract.connect(user1).deposit(1000);
            await delay(duration, 60);

            const tx = contract.connect(user1).vote(proposalId, true);
            await expect(tx).to.be.revertedWith("MADAO: voting period ended");
        });

        it("should be reverted if voting doesn't exist", async () => {
            const tx1 = contract.connect(user1).vote(123, true);
            await expect(tx1).to.be.revertedWith("MADAO: no such voting");

            const tx2 = contract.connect(user1).vote(0, true);
            await expect(tx2).to.be.revertedWith("MADAO: no such voting");
        });
    });
});