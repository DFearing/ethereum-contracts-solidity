const BlindBid = artifacts.require("BlindBid");
const BlindOnChainAuction = artifacts.require("BlindOnChainAuction");
const catchRevert = require("../exceptions.js").catchRevert;
const expectEvent = require("../expectEvent.js");

contract('Auction Happy Path', async (accounts) => {
    // it("auction should initiate", async () => {
    //     const bidInstance = await BlindBid.deployed();

    //     await bidInstance.initiate({ value: web3.toWei(1, "ether"), from: accounts[1] });
    // });

    it("bid should accept bids", async () => {
        const bidInstance = await BlindBid.deployed();

        await bidInstance.placeBid({ value: web3.toWei(5, "ether"), from: accounts[1] });
    });

    it("auction should transition to revealing", async () => {
        const auction = await BlindOnChainAuction.deployed();
        await auction.transitionToState(3, { from: accounts[0] });
    });

    it("bid should reveal bid", async () => {
        const bidInstance = await BlindBid.deployed();
        const auction = await BlindOnChainAuction.deployed();

        await bidInstance.revealBidToAuction(auction.address, { from: accounts[0] });
        const bidAmount = await bidInstance.bid({ from: accounts[0] });
        const fee = await auction.biddingFee({ from: accounts[0] });

        assert.equal(bidAmount.toNumber(), web3.toWei(5, "ether") - fee);
    });

    it("auction should reveal bid", async () => {
        const auction = await BlindOnChainAuction.deployed();
        const bidInstance = await BlindBid.deployed();
        const fee = await auction.biddingFee({ from: accounts[0] });

        const { logs } = await auction.recordBid(web3.toWei(5, "ether") - fee, accounts[1], bidInstance.address, { from: accounts[0] });
        expectEvent.inLogs(logs, 'BidRevealed', { bidder: accounts[1] });
    });

    it("auction should calculate winning bid", async () => {
        const auction = await BlindOnChainAuction.deployed();

        const { logs } = await auction.calculateWinningBid({ from: accounts[0] });
        expectEvent.inLogs(logs, 'WinnerRevealed', { winner: accounts[1] });
    });
});