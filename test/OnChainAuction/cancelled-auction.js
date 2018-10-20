let Auction = artifacts.require("OnChainAuction");
let catchRevert = require("../exceptions.js").catchRevert;

contract('Cancelled Auction', async (accounts) => {
    it("should refund bids and fees", async () => {
        const instance = await Auction.deployed();
        await instance.initiate({ value: await instance.auctionFee(), from: accounts[0] });
        const beforeBid = web3.eth.getBalance(accounts[1]);
        const bidReceipt = await instance.placeBid({ value: web3.toWei(1, "ether"), from: accounts[1] });
        const bidTxt = await web3.eth.getTransaction(bidReceipt.tx);
        const bidCost = bidTxt.gasPrice.mul(bidReceipt.receipt.gasUsed);
        await instance.cancel({ from: accounts[0] });
        const refundReceipt = await instance.getRefundFromCancelledAuction({ from: accounts[1] });
        const feesAfterRefund = await instance.totalFees();
        const refundTx = await web3.eth.getTransaction(refundReceipt.tx);
        const refundCost = refundTx.gasPrice.mul(refundReceipt.receipt.gasUsed);
        const afterRefund = web3.eth.getBalance(accounts[1]);
        const totalWithFees = afterRefund.add(refundCost).add(bidCost);

        assert.equal(beforeBid.valueOf(), totalWithFees.valueOf());
        assert.equal(feesAfterRefund.valueOf(), await instance.auctionFee());
    });

    it("should revert bids", async () => {
        const instance = await Auction.deployed();
        await catchRevert(instance.placeBid({ value: await instance.biddingFee(), from: accounts[1] }));
    });
});