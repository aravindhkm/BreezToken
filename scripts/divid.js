const hre = require("hardhat");

async function main() {

  let iterableMappingContract = "0x27bb3cfdf7EfFdEfdFC9Fc6f60845bC548873CDF";
  let breeZToken = "0x6980967276fdfE1dEC8d30cF8092d0A4f70E13C8";
  let dividend  = "0x9cF64764fF3ed91CCB461660e6Dc5a7D8570ec90";
  let reward = "0x3db4FDa1B480105DAE1D26aDe2F75548bB505744";


  let poolContract;


  // const mapping = await hre.ethers.getContractFactory("IterableMapping");
  // const IterableMapping = await mapping.deploy();
  // await IterableMapping.deployed();
  // iterableMappingContract = IterableMapping.address;
  // console.log("IterableMapping deployed to:", IterableMapping.address); 
   await hre.run("verify:verify", {
    address: iterableMappingContract,
    constructorArguments: [],
  });

  // const distributor = await hre.ethers.getContractFactory("RewardDistributor", {
  //   libraries: {
  //     IterableMapping: iterableMappingContract
  //   }});
  // const distributorInstance = await distributor.deploy();
  // await distributorInstance.deployed();
  // distributorContract = distributorInstance.address;
  // console.log("distributorInstance deployed to:", distributorInstance.address); 
   await hre.run("verify:verify", {
    address: breeZToken,
    constructorArguments: [reward],
        libraries: {
        IterableMapping: iterableMappingContract
      },
  });


  await hre.run("verify:verify", {
    address: dividend,
    constructorArguments: [reward],
  });



}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
