const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Artfi test case", function () {
    before("deploy contract", async function() {
        const [owner, user1, user2] = await ethers.getSigners();

        this.alice = user1;
        this.bob = user2;
        this.owner = owner;

        const MockToken = await ethers.getContractFactory("MockToken");
        this.mockToken = await MockToken.deploy();
        await this.mockToken.deployed();

        const ArtfiNFT = await ethers.getContractFactory("ArtfiNFT");
        this.artfiNFT = await ArtfiNFT.deploy();
        await this.artfiNFT.deployed();

        const ArtfiWhitelist = await ethers.getContractFactory("ArtfiWhitelist");
        this.artfiWhitelist = await ArtfiWhitelist.deploy(
            this.artfiNFT.address,
            owner.address
        );
        await this.artfiWhitelist.deployed();

        // add mocktoken
        this.artfiWhitelist.connect(owner).updateToken(this.mockToken.address, true);

        this.mockToken.connect(this.bob).mint(this.bob.address, ethers.utils.parseEther("1000"));
        this.mockToken.connect(this.bob).approve(this.artfiWhitelist.address, ethers.utils.parseEther("1000"));

        console.log(`Owner address: ${owner.address}`);
        console.log(`ArtfiNFT address: ${this.artfiNFT.address}`);
        console.log(`ArtfiWhitelist address: ${this.artfiWhitelist.address}`);
    });

    describe("Start test", function () {
        it("check verify", async function () {
            const signFraction = {
                name: 'ARTFI',
                version: '1.0.0',
                chainId: '31337',
                verifyingContract: this.artfiWhitelist.address
            };
            
            const signTypes = {
                Fraction: [
                  {name: 'walletAddress', type: 'address'},
                  {name: 'fractionInfo', type: 'string'},
                  {name: 'price', type: 'uint256'},
                ],
            };

            const signature = await this.owner._signTypedData(signFraction, signTypes, {
                walletAddress: this.bob.address,
                fractionInfo: "1,3,5",
                price: ethers.utils.parseUnits("100")
            });

            const whitelister = await this.artfiWhitelist.verify1(
                this.bob.address,
                ethers.utils.parseUnits("100"),
                '1,3,5',
                signature
            )
            const realWhitelister = await this.artfiWhitelist.whitelister();
            expect(whitelister).to.eq(realWhitelister);

            await this.artfiWhitelist.connect(this.bob).doWhitelist(
                this.mockToken.address,
                ethers.utils.parseUnits("100"),
                ethers.utils.hexZeroPad(ethers.utils.hexlify(1), 32),
                '1,3,5',
                signature
            )
            const balance = await this.mockToken.balanceOf(this.artfiWhitelist.address);
            expect(parseInt(ethers.utils.formatEther(balance))).to.eq(100)
        });
    });
});
