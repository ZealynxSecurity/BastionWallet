// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface Initiator {
    // mapping(address => ISubExecutor.SubStorage[]) public subscriptions;

    function registerSubscription(
        address _subscriber,
        uint256 _amount,
        uint256 _validUntil,
        uint256 _paymentInterval,
        address _erc20Token
    ) external;

    // Function that calls processPayment from sub executor and initiates a payment
    function initiatePayment(address _subscriber) external;

    function removeSubscription(address _subscriber) external;
}
