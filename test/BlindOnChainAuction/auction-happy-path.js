const BlindBid = artifacts.require("BlindBid");
const BlindOnChainAuction = artifacts.require("BlindOnChainAuction");
const catchRevert = require("../exceptions.js").catchRevert;
const expectEvent = require("../expectEvent.js");

contract('Auction Happy Path', async (accounts) => {
    // it("should accept bids", async () => {
    //     const bidInstance = await BlindBid.deployed();

    //     await bidInstance.placeBid({ value: web3.toWei(5, "ether"), from: accounts[1] });
    // });

    it("should unblind bid", async () => {
        const auction = await BlindOnChainAuction.deployed();

        await auction.transitionToState(3, { from: accounts[0] });

        const { logs } = await auction.revealBid(auction.address, { from: accounts[0] });
        expectEvent.inLogs(logs, 'BidRevealed');
    });

    it("should calculate winning bid", async () => {
        const auction = await BlindOnChainAuction.deployed();

        const { logs } = await auction.calculateWinningBid({ from: accounts[0] });
        expectEvent.inLogs(logs, 'WinnerRevealed');
    });
});