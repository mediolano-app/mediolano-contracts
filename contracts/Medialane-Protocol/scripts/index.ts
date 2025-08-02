import * as dotenv from "dotenv";

// Import the scripts
import { run as runErc20ForErc721 } from "./erc_20_for_erc721";
import { run as runErc721ForErc20 } from "./erc_721_for_erc20";

// Load environment variables from .env file
dotenv.config();

/**
 * Main script execution.
 */
async function main() {
  console.log("Starting script...");

  console.log("Running ERC20 for ERC721 script...");
  await runErc20ForErc721();
  console.log("Finished ERC20 for ERC721 script.");

  console.log("Running ERC721 for ERC20 script...");
  await runErc721ForErc20();
  console.log("Finished ERC721 for ERC20 script.");

  console.log("Script finished...");
}

// Entry point
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error occurred:", error);
    process.exit(1);
  });
