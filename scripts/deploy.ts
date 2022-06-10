import { ethers } from "hardhat";

async function main() {
    const contractName = "MADAOv1";
    const voteTokenAddress = "";
    const votingDuration = 10 * 60;
    const votesMinimumQuorum = 20;

    if (voteTokenAddress == "") {
        console.error("\r\n !!! vote token isn't defined. !!! \r\n");
        return;
    }

    const [owner] = await ethers.getSigners();
    const factory = await ethers.getContractFactory(contractName, owner);
    const contract = await factory.deploy(
        owner.address, 
        voteTokenAddress, 
        votesMinimumQuorum, 
        votingDuration
    ); 
    await contract.deployed();

    console.log(contractName + " deployed to: " + contract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
