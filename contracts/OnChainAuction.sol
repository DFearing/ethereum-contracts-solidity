pragma solidity ^0.4.23;

import "./SafeMath.sol";

/**
 * @title OnChainAuction
 * @author Dan Fearing
 * @dev A simple auction system with bids committed to the chain. DO NOT USE! Bids are not blind and therefore anyone can easily outbid you at the last second.
 */
contract OnChainAuction {
    using SafeMath for uint;

    enum State { Uninitialized, Cancelled, Bidding, Revealing, Collecting }

    struct Bid {
        uint amount;
        address account;
    }

    address custodian;
    address seller;

    uint public auctionFee;
    uint public biddingFee;
    uint public totalFees;
    State public state;
    uint public startDate;
    uint public revealDate;
    uint public paymentDue;

    Bid winningBid;
    uint orphanedPayoutWindow;
    uint payout;

    mapping(address => uint) usersBids;
    Bid[] bids;

    constructor(address _custodian, address _seller, uint _biddingFee, uint _auctionFee, uint8 _auctionLengthInDays, uint8 _paymentWindowInDays, uint8 _orphanedPayoutWindowInWeeks) public {
        state = State.Uninitialized;
        custodian = _custodian;
        seller = _seller;
        biddingFee = _biddingFee;
        auctionFee = _auctionFee;
        startDate = now;
        revealDate = startDate + _auctionLengthInDays * 1 days;
        paymentDue = revealDate + _paymentWindowInDays * 1 days;
        orphanedPayoutWindow = paymentDue + _orphanedPayoutWindowInWeeks * 1 weeks;
    }

    function initiate() external payable {
        require(state == State.Uninitialized, "Initiate has already been called.");
        require(msg.sender == seller, "Only the Seller can call this method.");
        require(msg.value >= auctionFee);

        state = State.Bidding;
        totalFees = totalFees.add(auctionFee);
    }

    function cancel() external {
        require(msg.sender == seller, "Only the Seller can call this method.");
        require(state != State.Collecting, "Cannot cancel an auction in the Collection state.");

        state = State.Cancelled;
    }

    function getRefundFromCancelledAuction() external {
        require(state == State.Cancelled, "This method can only be called if the auction has been cancelled.");

        uint amount = usersBids[msg.sender];
        usersBids[msg.sender] = 0;

        if (amount > 0) {
            totalFees = totalFees.sub(biddingFee);
            msg.sender.transfer(amount + biddingFee);
        }
    }

    function refundLosingBid() external {
        require(state == State.Collecting, "Can't refund a losing bid in this state.");
        require(msg.sender != winningBid.account, "Only losing usersBids can be refunded.");

        uint amount = usersBids[msg.sender];
        usersBids[msg.sender] = 0;

        if (amount > 0) {
            msg.sender.transfer(amount);
        }
    }

    function placeBid() external payable {
        _transitionIfRequired();

        require(state == State.Bidding, "This method can only be called during the Bidding state.");
        require(msg.value > biddingFee, "This bid is less than the bidding fee.");
        require(usersBids[msg.sender] == 0, "You can only bid once.");

        uint bidAmount = msg.value - biddingFee;

        usersBids[msg.sender] = bidAmount;
        bids.push(Bid(bidAmount, msg.sender));
        totalFees = totalFees.add(biddingFee);
    }

    function _transitionIfRequired() internal {
        if (state == State.Bidding) {
            if (now > revealDate) {
                state = State.Revealing;
            }
        }
    }

    function transitionToState(State _state) external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");
        
        state = _state;
    }

    function calculateWinningBid() external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");
        require(state == State.Revealing, "Winning bidder cannot be calculated in this state.");

        Bid storage topBid = bids[0];

        for (uint i = 1; i < bids.length; i++) {
            if (bids[i].amount > topBid.amount) {
                topBid = bids[i];
            }
        }

        winningBid = topBid;
        payout = winningBid.amount;
        state = State.Collecting;
    }

    function collectPayout() external {
        require(msg.sender == seller, "Only the Seller can call this method.");
        require(state == State.Collecting, "Payout cannot be collected in this state.");

        uint amount = payout;
        payout = 0;

        if (amount > 0) {
            msg.sender.transfer(amount);
        }
    }

    function collectFees() external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");
        require(state == State.Collecting, "Fees cannot be collected in this state.");

        uint amount = totalFees;
        totalFees = 0;

        if (amount > 0) {
            msg.sender.transfer(amount);
        }
    }

    function collectOrphanedFunds() external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");
        require(state == State.Collecting, "Orphaned fees cannot be collected in this state.");

        if (now > orphanedPayoutWindow) {
            msg.sender.transfer(address(this).balance);
        }
    }
}