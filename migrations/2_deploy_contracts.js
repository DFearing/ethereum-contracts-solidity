var OnChainAuction = artifacts.require("./OnChainAuction");
var BlindOnChainAuction = artifacts.require("./BlindOnChainAuction");
var BlindBid = artifacts.require("./BlindBid");

module.exports = function(deployer) {
  deployer.deploy(OnChainAuction, web3.eth.accounts[0], web3.eth.accounts[0], web3.toWei(.025, "ether"), web3.toWei(.0025, "ether"), 7, 2, 12);
  deployer.deploy(BlindOnChainAuction, web3.eth.accounts[0], web3.eth.accounts[0], web3.toWei(.025, "ether"), web3.toWei(.0025, "ether"), 7, 2, 12);
  deployer.deploy(BlindBid, web3.eth.accounts[0], 12, { from: web3.eth.accounts[1] });
};
