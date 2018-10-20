pragma solidity ^0.4.23;

import "./SafeMath.sol";

contract Auction {

    using SafeMath for uint256;

    enum State { Cancelled, Bidding, Revealing, Paying, Collecting }

    address custodian;
    address seller;

    uint public auctionFee;
    uint public biddingFee;
    uint256 public totalFees;
    State public state;
    uint public startDate;
    uint public revealDate;
    uint public paymentDue;
    uint orphanedPayoutWindow;

    Bid winningBid;
    uint payout;
    uint32 totalBids;

    mapping(address => uint256) usersBids;
    Bid[] bids;

    struct Bid {
        uint amount;
        address account;
    }

    constructor(address _custodian, address _seller, uint256 _biddingFee, uint32 _auctionLengthInDays, uint _paymentWindowInDays, uint _orphanedPayoutWindowInWeeks) public {
        state = State.Bidding;
        custodian = _custodian;
        seller = _seller;
        biddingFee = _biddingFee;
        startDate = now;
        revealDate = startDate + _auctionLengthInDays * 1 days;
        paymentDue = revealDate + _paymentWindowInDays * 1 days;
        orphanedPayoutWindow = paymentDue + _orphanedPayoutWindowInWeeks * 1 weeks;
    }

    function cancel() external {
        require(msg.sender == seller, "Only the Seller can call this method.");

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
        require(state == State.Paying || state == State.Collecting, "This method canot be called in this state.");
        require(msg.sender != winningBid.account, "Only losing usersBids can be refunded.");

        uint amount = usersBids[msg.sender];
        usersBids[msg.sender] = 0;

        if (amount > 0) {
            msg.sender.transfer(amount);
        }
    }

    function placeBid() external payable {
        _transitionIfRequired();

        require(state == State.Bidding, "This method can only be called during the Bidding phase.");
        require(msg.value > biddingFee, "This bid is less than the bidding fee.");
        require(usersBids[msg.sender] == 0, "You can only bid once.");

        uint bidAmount = msg.value - biddingFee;

        usersBids[msg.sender] = bidAmount;
        bids.push(Bid(bidAmount, msg.sender));
        totalFees = totalFees.add(biddingFee);
        totalBids++;
    }

    function _transitionIfRequired() internal {
        if (state == State.Bidding) {
            if (now > revealDate) {
                state = State.Collecting;
            }
        }
    }

    function transitionToState(State _state) external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");
        
        state = _state;
    }

    function transitionState() external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");

        if (state == State.Bidding) {
            state = State.Revealing;
        } else if (state == State.Revealing) {
            state = State.Paying;
        } else if (state == State.Paying) {
            state = State.Collecting;
        }
    }

    function calculateWinningBid() external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");
        require(state == State.Revealing, "This method canot be called in this state.");

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
        require(state == State.Collecting, "This method canot be called in this state.");

        uint amount = payout;
        payout = 0;

        if (amount > 0) {
            msg.sender.transfer(amount);
        }
    }

    function collectFees() external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");
        require(state == State.Collecting, "This method canot be called in this state.");

        uint amount = totalFees;
        totalFees = 0;

        if (amount > 0) {
            msg.sender.transfer(amount);
        }
    }

    function collectOrphanedFunds() external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");
        require(state == State.Collecting, "This method canot be called in this state.");

        // If we are 8 weeks passed the close of the auction, we are allowed to collect funds

        if (now > orphanedPayoutWindow) {
            uint amount = payout;
            payout = 0;

            if (amount > 0) {
                msg.sender.transfer(amount);
            }
        }
    }
}