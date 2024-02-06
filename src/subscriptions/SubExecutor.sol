// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../abstract/KernelStorage.sol";
import "../interfaces/IInitiator.sol";

contract SubExecutor is ReentrancyGuard {
    event revokedApproval(address indexed _subscriber);
    event paymentProcessed(address indexed _subscriber, uint256 _amount);
    event subscriptionCreated(address indexed _initiator, address indexed _subscriber, uint256 _amount);
    event subscriptionModified(address indexed _initiator, address indexed _subscriber, uint256 _amount);

    event DebugSubExecutor(uint256 timestamp, uint256 amountChecked);

    // Function to get the wallet kernel storage
    function getKernelStorage() internal pure returns (WalletKernelStorage storage ws) {
        bytes32 storagePosition = bytes32(uint256(keccak256("zerodev.kernel")) - 1);
        assembly {
            ws.slot := storagePosition
        }
    }

    function getOwner() public view returns (address) {
        return getKernelStorage().owner;
    }

    // Modifier to check if the function is called by the entry point, the contract itself or the owner
    modifier onlyFromEntryPointOrOwnerOrSelf() {
        address owner = getKernelStorage().owner;
        address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        require(
            msg.sender == address(entryPoint) || msg.sender == address(this) || msg.sender == owner,
            "account: not from entrypoint or owner or self"
        );
        _;
    }

    function createSubscription(
        address _initiator,
        uint256 _amount,
        uint256 _interval, // in seconds
        uint256 _validUntil, //timestamp
        address _erc20Token
    ) external onlyFromEntryPointOrOwnerOrSelf {
        require(_amount > 0, "Subscription amount is 0");
        getKernelStorage().subscriptions[_initiator] = SubStorage({
            amount: _amount,
            validUntil: _validUntil,
            validAfter: block.timestamp,
            paymentInterval: _interval,
            subscriber: address(this),
            initiator: _initiator,
            erc20Token: _erc20Token,
            erc20TokensValid: _erc20Token == address(0) ? false : true
        });
        IInitiator(_initiator).registerSubscription(address(this), _amount, _validUntil, _interval, _erc20Token);

        emit subscriptionCreated(msg.sender, _initiator, _amount);
    }

    function modifySubscription(
        address _initiator,
        uint256 _amount,
        uint256 _interval,
        uint256 _validUntil,
        address _erc20Token
    ) external onlyFromEntryPointOrOwnerOrSelf {
        getKernelStorage().subscriptions[_initiator] = SubStorage({
            amount: _amount,
            validUntil: _validUntil,
            validAfter: block.timestamp,
            paymentInterval: _interval,
            subscriber: address(this),
            initiator: _initiator,
            erc20Token: _erc20Token,
            erc20TokensValid: _erc20Token == address(0) ? false : true
        });

        IInitiator(_initiator).registerSubscription(address(this), _amount, _validUntil, _interval, _erc20Token);

        emit subscriptionModified(msg.sender, _initiator, _amount);
    }

    function revokeSubscription(address _initiator) external onlyFromEntryPointOrOwnerOrSelf {
        delete getKernelStorage().subscriptions[_initiator];
        IInitiator(_initiator).removeSubscription(address(this));
        emit revokedApproval(_initiator);
    }

    function getSubscription(address _initiator) external view returns (SubStorage memory) {
        return getKernelStorage().subscriptions[_initiator];
    }

    function getPaymentHistory(address _initiator) external view returns (PaymentRecord[] memory) {
        return getKernelStorage().paymentRecords[_initiator];
    }

    function processPayment() external nonReentrant {
        SubStorage storage sub = getKernelStorage().subscriptions[msg.sender];
        emit DebugSubExecutor(block.timestamp,  sub.validAfter);
        emit DebugSubExecutor(block.timestamp,  sub.validUntil);

        require(block.timestamp >= sub.validAfter, "Subscription not yet valid");
        require(block.timestamp <= sub.validUntil, "Subscription expired");
        require(msg.sender == sub.initiator, "Only the initiator can initiate payments");

        //Check when the last payment was done
        PaymentRecord[] storage paymentHistory = getKernelStorage().paymentRecords[msg.sender];
        if (paymentHistory.length > 0) {
            PaymentRecord storage lastPayment = paymentHistory[paymentHistory.length - 1];
            require(block.timestamp >= lastPayment.timestamp + sub.paymentInterval, "Payment interval not yet reached");
        } else {
            require(block.timestamp >= sub.validAfter + sub.paymentInterval, "Payment interval not yet reached");
        }

        getKernelStorage().paymentRecords[msg.sender].push(PaymentRecord(sub.amount, block.timestamp, sub.subscriber));

        //Check whether it's a native payment or ERC20 or ERC721
        if (sub.erc20TokensValid) {
            _processERC20Payment(sub);
        } else {
            _processNativePayment(sub);
        }

        emit paymentProcessed(msg.sender, sub.amount);
    }

    function getLastPaidTimestamp(address _initiator) external view returns (uint256) {
        PaymentRecord[] storage paymentHistory = getKernelStorage().paymentRecords[_initiator];
        if (paymentHistory.length == 0) {
            return 0;
        }
        PaymentRecord storage lastPayment = paymentHistory[paymentHistory.length - 1];
        return lastPayment.timestamp;
    }

    function _processERC20Payment(SubStorage storage sub) internal {
        IERC20 token = IERC20(sub.erc20Token);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= sub.amount, "Insufficient token balance");
        token.transferFrom(address(this), sub.initiator, sub.amount);
    }

    function _processNativePayment(SubStorage storage sub) internal {
        require(address(this).balance >= sub.amount, "Insufficient Ether balance");
        payable(sub.initiator).transfer(sub.amount);
    }
}
