import { task } from "hardhat/config";

task("", "")
    .addParam("contract", "Address of the contract")
    .setAction(async (args, hre) => {
        const [owner, user1, user2] = await hre.ethers.getSigners();
        const contract = 
            await hre.ethers.getContractAt("MADAO", args.contract, owner);
        
        const token1 =
            await hre.ethers.getContractAt("ERC20PresetMinterPauser", args.token1, user1);
        
        if (args.approve)
            await token1.approve(contract.address, args.amount);
    });