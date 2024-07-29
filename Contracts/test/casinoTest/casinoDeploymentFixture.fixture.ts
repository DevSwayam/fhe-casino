import type { CoinFlip, USDC, RockPaperScissors } from "../../types";
import { getSigners } from "../signers";
import { ethers } from "hardhat";

export async function casinoContractDeploymentFixture(): Promise<[USDC, CoinFlip, RockPaperScissors]> {

  console.log("------------------------------------------------------------------");
  console.log("Deploying Game Contracts...");

  const signers = await getSigners();
  const usdcContractFactory = await ethers.getContractFactory("USDC");
  const usdcContract = await usdcContractFactory.connect(signers.alice).deploy();
  await usdcContract.waitForDeployment(); 
  const usdcContractAddress = await usdcContract.getAddress();

  const coinFlipFactory = await ethers.getContractFactory("CoinFlip");
  const coinFlipContract = await coinFlipFactory.connect(signers.alice).deploy(usdcContractAddress);
  await coinFlipContract.waitForDeployment();

  const rockPaperScissorFactory = await ethers.getContractFactory("RockPaperScissors");
  const RockPaperScissorsContract = await rockPaperScissorFactory.connect(signers.alice).deploy(usdcContractAddress);
  await RockPaperScissorsContract.waitForDeployment();


  console.log("USDC Contract Address is: ",usdcContractAddress);
  console.log("CoinFlip Contract Address is: ",await coinFlipContract.getAddress());
  console.log("RockPaperScissors Contract Address is: ",await RockPaperScissorsContract.getAddress());
  console.log("All Game Contracts have been deployed");
  return [usdcContract, coinFlipContract, RockPaperScissorsContract]; // Return as a tuple.
}
