pragma solidity ^0.4.23;

import "./SafeMath.sol";
import "./BlindOnChainAuction.sol";

/**
 * @title BlindBid
 * @author Dan Fearing
 * @dev 
 */
contract BlindBid {
    using SafeMath for uint;

    enum State { Bidding, Revealing, Paying }

    BlindOnChainAuction auction;
    address custodian;
    address owner;
    uint orphanedFundsWindow;
    uint public fees;
    uint public bid;
    State public state;

    constructor(address _custodian, uint8 _orphanedFundsWindowInWeeks) public {
        custodian = _custodian;
        owner = msg.sender;
        state = State.Bidding;
        orphanedFundsWindow = _orphanedFundsWindowInWeeks * 1 weeks;
    }

    function() external payable { 

    }

    function placeBid() external payable {
        require(msg.sender == owner, "Only the Owner can perform this action.");

        bid = msg.value;
    }

    function unblindBid(address _auction) external {
        require(msg.sender == owner, "Only the Custodian can perform this action.");
        require(state == State.Bidding, "Fees cannot be collected in this state.");

        state = State.Revealing;
        auction = BlindOnChainAuction(_auction);
        fees = auction.biddingFee();
        bid = bid - fees;

        auction.unblindBid(bid);
    }

    function transferWinningBid() external {
        require(msg.sender == owner, "Only the Owner can perform this action.");
        require(state == State.Revealing, "Fees cannot be collected in this state.");

        state = State.Paying;

        if (bid > 0) {
            bid = 0;
            address(auction).transfer(bid);
        }
    }

    function collectFees() external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");
        require(state == State.Paying, "Fees cannot be collected in this state.");

        if (fees > 0) {
            fees = 0;
            msg.sender.transfer(fees);
        }
    }

    function collectOrphanedFunds() external {
        require(msg.sender == custodian, "Only the Custodian can call this method.");
        require(state == State.Paying, "Orphaned fees cannot be collected in this state.");

        if (now > orphanedFundsWindow) {
            msg.sender.transfer(address(this).balance);
        }
    }

    // function refundLosingBid() external {
    //     require(state == State.Paying || state == State.Collecting, "Can't refund a losing bid in this state.");
    //     require(msg.sender != winningBid.account, "Only losing usersBids can be refunded.");

    //     uint amount = usersBids[msg.sender];
    //     usersBids[msg.sender] = 0;

    //     if (amount > 0) {
    //         msg.sender.transfer(amount);
    //     }
    // }

    // function getRefundFromCancelledAuction() external {
    //     require(state == State.Cancelled, "This method can only be called if the auction has been cancelled.");

    //     uint amount = usersBids[msg.sender];
    //     usersBids[msg.sender] = 0;

    //     if (amount > 0) {
    //         totalFees = totalFees.sub(biddingFee);
    //         msg.sender.transfer(amount + biddingFee);
    //     }
    // }
}