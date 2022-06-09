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

    const proposalId = 0;
    const duration = BigNumber.from(3 * 24 * 60 * 60);// 3 days in seconds

    beforeEach(async () => {
        [chairperson, user1, user2] = await ethers.getSigners();
        voteToken = await deployMockContract(chairperson, IERC20__factory.abi);

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
            await contract.connect(user1).vote(proposalId, true);
        });

        it("should be reverted if voted already", async () => {
            await contract.connect(user1).vote(proposalId, true);
            const tx = contract.connect(user1).vote(proposalId, true);
            await expect(tx).to.be.revertedWith("MADAO: voted already");
        });

        it("should be reverted if voting period ended", async () => {
            await delay(duration, 60);
            const tx = contract.connect(user1).vote(proposalId, true);
            await expect(tx).to.be.revertedWith("MADAO: voting period ended");
        });
    });
});