const { ethers } = require("hardhat");

async function main() {
    const [owner] = await ethers.getSigners();
    const whitelister = "0x556EF0b2a6c59b3151fFc1e90fa057dF75EB43d3";

    const MockToken = await ethers.getContractFactory("MockToken");
    const mockToken = await MockToken.deploy();
    await mockToken.deployed();

    const ArtfiNFT = await ethers.getContractFactory("ArtfiNFT");
    const artfiNFT = await ArtfiNFT.deploy();
    await artfiNFT.deployed();

    const ArtfiWhitelist = await ethers.getContractFactory("ArtfiWhitelist");
    const artfiWhitelist = await ArtfiWhitelist.deploy(
        artfiNFT.address,
        whitelister
    );
    await artfiWhitelist.deployed();

    // add mocktoken
    artfiWhitelist.connect(owner).updateToken(this.mockToken.address, true);

    console.log(`MockToken: ${mockToken.address}`)
    console.log(`ArtfiNFT: ${artfiNFT.address}`)
    console.log(`ArtfiWhitelist: ${artfiWhitelist.address}`)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
