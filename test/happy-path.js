let Auction = artifacts.require("auction");
let catchRevert = require("./exceptions.js").catchRevert;

contract('Happy Path', async (accounts) => {
    it("should require a fee greater than the auction fee", async () => {
        const instance = await Auction.deployed();
        await catchRevert(instance.initiate({ value: await instance.auctionFee() - 1, from: accounts[0] }));
    });

    it("should initiate", async () => {
        const instance = await Auction.deployed();
        await instance.initiate({ value: await instance.auctionFee(), from: accounts[0] });
        assert.equal((await instance.totalFees()).toNumber(), (await instance.auctionFee()).toNumber());
    });

    it("should require a bid greater than the bidding fee", async () => {
        const instance = await Auction.deployed();
        await catchRevert(instance.placeBid({ value: await instance.biddingFee(), from: accounts[1] }));
    });

    it("should accept bids", async () => {
        const instance = await Auction.deployed();
        await instance.placeBid({ value: web3.toWei(1, "ether"), from: accounts[1] });
        assert.equal((await instance.totalFees()).toNumber(), (await instance.biddingFee()).toNumber() + (await instance.auctionFee()).toNumber());
        await instance.placeBid({ value: web3.toWei(2, "ether"), from: accounts[9] });
        assert.equal((await instance.totalFees()).valueOf(), (await instance.biddingFee()).toNumber() * 2 + (await instance.auctionFee()).toNumber());
    });

    it("should reject additional bids", async () => {
        const instance = await Auction.deployed();
        await catchRevert(instance.placeBid({ value: web3.toWei(1, "ether"), from: accounts[1] }));
    });

    it("should refund losing bids minus fees", async () => {
        const instance = await Auction.deployed();
        const beforeBid = web3.fromWei(web3.eth.getBalance(accounts[2]));
       
        const bidReceipt = await instance.placeBid({ value: web3.toWei(1, "ether"), from: accounts[2] });
        const bidTxt = await web3.eth.getTransaction(bidReceipt.tx);
        const bidCost = web3.fromWei(bidTxt.gasPrice.mul(bidReceipt.receipt.gasUsed));
        const biddingFee = await instance.biddingFee();

        await instance.transitionToState(3, { from: accounts[0] });
        await instance.calculateWinningBid({ from: accounts[0] });

        const feesBeforeRefund = await instance.totalFees();
        const refundReceipt = await instance.refundLosingBid({ from: accounts[2] });
        const feesAfterRefund = await instance.totalFees();
        const refundTx = await web3.eth.getTransaction(refundReceipt.tx);
        const refundCost = web3.fromWei(refundTx.gasPrice.mul(refundReceipt.receipt.gasUsed));
        const afterRefund = web3.fromWei(web3.eth.getBalance(accounts[2]));
        const afterRefundWithFees = afterRefund.add(refundCost).add(bidCost).add(web3.fromWei(biddingFee));
    
        assert.equal(beforeBid.valueOf(), afterRefundWithFees.valueOf());
        assert.equal(feesBeforeRefund.valueOf(), feesAfterRefund.valueOf());
    });

    it("should not refund twice", async () => {
        const instance = await Auction.deployed();
        const beforeRefund = web3.fromWei(web3.eth.getBalance(accounts[2]));
        const feesBeforeRefund = await instance.totalFees();
        const refundReceipt = await instance.refundLosingBid({ from: accounts[2] });
        const feesAfterRefund = await instance.totalFees();
        const refundTx = await web3.eth.getTransaction(refundReceipt.tx);
        const refundCost = web3.fromWei(refundTx.gasPrice.mul(refundReceipt.receipt.gasUsed));
        const afterRefund = web3.fromWei(web3.eth.getBalance(accounts[2]));
        const afterRefundWithFees = afterRefund.add(refundCost);

        assert.equal(beforeRefund.valueOf(), afterRefundWithFees.valueOf());
        assert.equal(feesBeforeRefund.valueOf(), feesAfterRefund.valueOf());
    });

    it("should not allow non seller withdraws", async () => {
        const instance = await Auction.deployed();
        await catchRevert(instance.collectPayout({ from: accounts[1] }));
    });

    it("should withdraw payout", async () => {
        const instance = await Auction.deployed();
        const beforePayout = web3.fromWei(web3.eth.getBalance(accounts[0]));

        const payoutReceipt = await instance.collectPayout({ from: accounts[0] });
        const payoutTx = await web3.eth.getTransaction(payoutReceipt.tx);

        const payoutCost = web3.fromWei(payoutTx.gasPrice.mul(payoutReceipt.receipt.gasUsed));
        const afterPayout = web3.fromWei(web3.eth.getBalance(accounts[0]));
        const afterPayoutWithFees = afterPayout.add(payoutCost);

        const biddingFee = web3.fromWei(await instance.biddingFee());

        assert.equal(afterPayoutWithFees.valueOf(), beforePayout.toNumber() + 2 - biddingFee);
    });

    it("should not withdraw additional payout", async () => {
        const instance = await Auction.deployed();
        const beforePayout = web3.fromWei(web3.eth.getBalance(accounts[0]));

        const payoutReceipt = await instance.collectPayout({ from: accounts[0] });
        const payoutTx = await web3.eth.getTransaction(payoutReceipt.tx);

        const payoutCost = web3.fromWei(payoutTx.gasPrice.mul(payoutReceipt.receipt.gasUsed));
        const afterPayout = web3.fromWei(web3.eth.getBalance(accounts[0]));
        const afterPayoutWithFees = afterPayout.add(payoutCost);

        const biddingFee = web3.fromWei(await instance.biddingFee());

        assert.equal(afterPayoutWithFees.valueOf(), beforePayout.toNumber());
    });
});