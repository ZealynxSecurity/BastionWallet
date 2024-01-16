// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISubExecutor {
    event preApproved(address indexed _subscriber, uint256 _amount);
    event revokedApproval(address indexed _subscriber);
    event paymentProcessed(address indexed _subscriber, uint256 _amount);

    struct SubStorage {
        uint256 amount;
        uint256 validUntil;
        uint256 validAfter;
        uint256 paymentInterval; // In days
        address subscriber;
        address initiator;
        bool erc20TokensValid;
        address erc20Token;
    }

    struct PaymentRecord {
        uint256 amount;
        uint256 timestamp;
        address payee;
    }

    function preApprove(
        address _payee,
        uint256 _amount,
        uint256 _paymentInterval,
        uint256 _paymentLimit,
        address _erc20TokenAddress
    ) external;

    function createSubscription(
        address _initiator,
        uint256 _amount,
        uint256 _interval, // in seconds
        uint256 _validUntil, //timestamp
        uint256 _paymentLimit,
        address _erc20Token
    ) external;

    function modifySubscription(
        address _initiator,
        uint256 _amount,
        uint256 _interval,
        uint256 _validUntil,
        uint256 _paymentLimit,
        address _erc20Token
    ) external;

    function revokeSubscription(address _initiator) external;

    function getSubscriptions(address _initiator) external view returns (SubStorage memory);

    function getPaymentHistory(address _initiator) external view returns (PaymentRecord[] memory);

    function processPayment() external;

    function withdrawERC20Tokens(address _tokenAddress) external;

    function getLastPaidTimestamp(address _initiator) external view returns (uint256);
}
