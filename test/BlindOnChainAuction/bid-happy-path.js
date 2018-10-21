const BlindBid = artifacts.require("BlindBid");
const BlindOnChainAuction = artifacts.require("BlindOnChainAuction");
const catchRevert = require("../exceptions.js").catchRevert;
const expectEvent = require("../expectEvent.js");

contract('Bid Happy Path', async (accounts) => {
    it("should accept bids", async () => {
        const bidInstance = await BlindBid.deployed();

        await bidInstance.placeBid({ value: web3.toWei(5, "ether"), from: accounts[1] });
    });

    it("should unblind bid", async () => {
        const bidInstance = await BlindBid.deployed();
        const auction = await BlindOnChainAuction.deployed();

        bidInstance.watch(function(error, result){
            alert(1);
        });

        const { logs } = await bidInstance.revealBid(auction.address, { from: accounts[0] });
        expectEvent.inLogs(logs, 'BidRevealed');
    });
});