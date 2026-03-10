const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // ============================================================
  // CONFIGURE THESE VALUES BEFORE DEPLOYING
  // ============================================================

  // BDAG token contract address — verify this from blockdag.network
  const BDAG_TOKEN = process.env.BDAG_TOKEN || "0x0000000000000000000000000000000000000000";

  // DEX Router address (Uniswap V2-compatible)
  // Examples:
  //   Uniswap V2 (Ethereum):  0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
  //   PancakeSwap (BSC):       0x10ED43C718714eb63d5aA57B78B54704E256024E
  //   SushiSwap (multi-chain): 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F
  const DEX_ROUTER = process.env.DEX_ROUTER || "0x0000000000000000000000000000000000000000";

  const SELL_PERCENTAGE_BPS = 4000; // 40%
  const SLIPPAGE_BPS = 500; // 5%

  if (BDAG_TOKEN === "0x0000000000000000000000000000000000000000") {
    throw new Error("Set BDAG_TOKEN env var to the BDAG contract address");
  }
  if (DEX_ROUTER === "0x0000000000000000000000000000000000000000") {
    throw new Error("Set DEX_ROUTER env var to the DEX router address");
  }

  console.log("BDAG Token:", BDAG_TOKEN);
  console.log("DEX Router:", DEX_ROUTER);
  console.log("Sell Percentage:", SELL_PERCENTAGE_BPS / 100, "%");
  console.log("Max Slippage:", SLIPPAGE_BPS / 100, "%");

  const AutoTokenSale = await ethers.getContractFactory("AutoTokenSale");
  const contract = await AutoTokenSale.deploy(
    BDAG_TOKEN,
    DEX_ROUTER,
    SELL_PERCENTAGE_BPS,
    SLIPPAGE_BPS
  );

  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log("AutoTokenSale deployed to:", address);

  console.log("\n--- NEXT STEPS ---");
  console.log("1. Approve the contract to spend your BDAG tokens:");
  console.log(`   BDAG.approve("${address}", <amount or type(uint256).max>)`);
  console.log("2. When the airdrop arrives, call:");
  console.log(`   AutoTokenSale.sellAirdrop()`);
  console.log("   This will sell 40% of your BDAG balance for native currency.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
