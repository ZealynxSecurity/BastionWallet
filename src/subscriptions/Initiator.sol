// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISubExecutor.sol";
import "forge-std/console.sol";

// import "../../lib/solidity_utils/lib.sol";


contract Initiator is Ownable, ReentrancyGuard {
    mapping(address => ISubExecutor.SubStorage) public subscriptionBySubscriber;
    address[] public subscribers;

    function registerSubscription(
        address _subscriber,
        uint256 _amount,
        uint256 _validUntil,
        uint256 _paymentInterval,
        address _erc20Token
    ) public {
        require(_amount > 0, "Subscription amount is 0");
        require(_paymentInterval > 0, "Payment interval is 0");
        require(msg.sender == _subscriber, "Only the subscriber can register a subscription");

        ISubExecutor.SubStorage memory sub = ISubExecutor.SubStorage({
            amount: _amount,
            validUntil: _validUntil,
            validAfter: block.timestamp,
            paymentInterval: _paymentInterval,
            subscriber: _subscriber,
            initiator: address(this),
            erc20TokensValid: _erc20Token == address(0) ? false : true, //@audit
            erc20Token: _erc20Token
        });
        subscriptionBySubscriber[_subscriber] = sub;
        subscribers.push(_subscriber);
    }

    function removeSubscription(address _subscriber) public {
        require(msg.sender == _subscriber, "Only the subscriber can remove a subscription");
        delete subscriptionBySubscriber[_subscriber];
    }

    function getSubscription(address _subscriber) public view returns (ISubExecutor.SubStorage memory) {
        ISubExecutor.SubStorage memory subscription = subscriptionBySubscriber[_subscriber];
        return subscription;
    }

    function getSubscribers() public view returns (address[] memory) {
        return subscribers;
    }

    // Function that calls processPayment from sub executor and initiates a payment
    function initiatePayment(address _subscriber) public nonReentrant {
        ISubExecutor.SubStorage storage subscription = subscriptionBySubscriber[_subscriber];

        console.log("============" );
        console.log("validUntil ",subscription.validUntil);
        console.log("> block.timestamp",block.timestamp );
        console.log("============" );

        console.log("validAfter ",subscription.validAfter );
        console.log("< block.timestamp",block.timestamp );
        console.log("============" );

        console.log("amount > 0? =>",subscription.amount );
        console.log("============" );

        console.log("paymentInterval > 0? =>",subscription.paymentInterval );
        console.log("============" );
        console.log("/////////////////////////////////////////" );

        require(subscription.validUntil > block.timestamp, "Subscription is not active");
        require(subscription.validAfter < block.timestamp, "Subscription is not active");
        require(subscription.amount > 0, "Subscription amount is 0");
        require(subscription.paymentInterval > 0, "Payment interval is 0");

        // uint256 lastPaid = ISubExecutor(subscription.subscriber).getLastPaidTimestamp(address(this));
        // if (lastPaid != 0) {
        //     require(lastPaid + subscription.paymentInterval > block.timestamp, "Payment interval not yet reached");
        // }
        ISubExecutor(subscription.subscriber).processPayment();
    }

    function withdrawETH() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawERC20(address _token) public onlyOwner {
        IERC20 token = IERC20(_token);
        token.transfer(owner(), token.balanceOf(address(this)));
    }

    receive() external payable {}
}
