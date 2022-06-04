import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployContract } from "ethereum-waffle";
import { ethers, network } from "hardhat";

describe("MA DAO", () => {
    let validator: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;
    //let contract: MADAO;
    
    beforeEach(async () => {
        [validator, user1, user2] = await ethers.getSigners();

        const f = await ethers.getContractFactory("MADAO", validator);
        //contract = <MADAO>await f.deploy();

        //await contract.deployed();
    })

    describe("", () => {
        it("should work", async () => {
        });
    });

    describe("", () => {
        it("should work", async () => {
        });
    });
});