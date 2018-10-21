pragma solidity ^0.4.23;

import "./SafeMath.sol";

/**
 * @title BlindOnChainAuction
 * @author Dan Fearing
 * @dev A blind auction system with bids committed to the chain via another contract, but not linked until the reveal state.
 */
contract BlindOnChainAuction {
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

    mapping(address => uint256) usersBids;
    Bid[] public bids;

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

    function unblindBid(uint amount) external payable {
        //require(state == State.Revealing, "This method can only be called during the Revealing state.");

        usersBids[msg.sender] = amount;
        bids.push(Bid(amount, msg.sender));
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

        // Skip paying state in this contract
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
            if (address(this).balance > 0) {
                msg.sender.transfer(address(this).balance);
            }
        }
    }
}