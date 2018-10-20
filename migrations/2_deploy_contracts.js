var Auction = artifacts.require("./auction.sol");

module.exports = function(deployer) {
  deployer.deploy(Auction, web3.eth.accounts[0], web3.eth.accounts[0], web3.toWei(.0025, "ether"), 7, 2, 12);
};
