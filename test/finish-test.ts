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

    describe("finish", () => {
        it("should be cancelled", async () => {
            await delay(duration, 60);

            await contract.connect(user1).finish(proposalId);

            const p = await contract.getProposal(proposalId);
            expect(p.status).eq(3);//cancelled
        });

        it("should be rejected", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user1).vote(proposalId, false);

            await delay(duration, 60);

            await contract.connect(user1).finish(proposalId);

            const p = await contract.getProposal(proposalId);
            expect(p.status).eq(2);
        });

        it("should be finished", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user1).vote(proposalId, true);

            await delay(duration, 60);

            await contract.connect(user1).finish(proposalId);

            const p = await contract.getProposal(proposalId);
            expect(p.status).eq(1);
        });

        it("should be rejected if callData reverts", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user1).vote(proposalId, true);

            await delay(duration, 60);

            await voteToken.mock.transferFrom.reverts();
            const tx = contract.connect(user1).finish(proposalId);

            await expect(tx).to.be.revertedWith("MADAO: recipient call error");
        });

        it("should be rejected if called second time for the same proposal", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user1).vote(proposalId, true);

            await delay(duration, 60);

            await contract.connect(user1).finish(proposalId);
            const tx = contract.connect(user1).finish(proposalId);

            await expect(tx).to.be.revertedWith("MADAO: handled already");
        });

        it("should be rejected if voting is in process", async () => {
            await contract.connect(user1).deposit(1000);
            await contract.connect(user1).vote(proposalId, true);

            const tx = contract.connect(user1).finish(proposalId);

            await expect(tx).to.be.revertedWith("MADAO: voting is in process");
        });

        it("should be reverted if voting doesn't exist", async () => {
            const tx1 = contract.connect(user1).finish(123);
            await expect(tx1).to.be.revertedWith("MADAO: no such voting");

            const tx2 = contract.connect(user1).finish(0);
            await expect(tx2).to.be.revertedWith("MADAO: no such voting");
        });
    });
});