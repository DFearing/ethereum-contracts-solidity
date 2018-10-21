let BlindBid = artifacts.require("BlindBid");
let BlindOnChainAuction = artifacts.require("BlindOnChainAuction");
let catchRevert = require("../exceptions.js").catchRevert;

contract('Bid Happy Path', async (accounts) => {
    it("should accept transfer as a bid", async () => {
        const bidInstance = await BlindBid.deployed();
        const auction = await BlindOnChainAuction.deployed();

        await bidInstance.sendTransaction({ value: web3.toWei(5, "ether"), from: accounts[1] });
        //instance.sendTransaction({ value: web3.toWei(5, "ether"), from: accounts[2] });

        //console.log(auction.address);

        await bidInstance.unblindBid(auction.address, { from: accounts[1] });


        //console.log(await auction.bids({ from: accounts[1] }));
   
    });
});