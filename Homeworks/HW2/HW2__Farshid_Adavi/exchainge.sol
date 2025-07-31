// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

const ethers = require('ethers');

async function signMessage(privateKey, message) {
    const wallet = new ethers.Wallet(privateKey);
    const signature = await wallet.signMessage(message);
    return signature;
}

contract EthSwap {
    bytes32 private signed_passphrase;
    bytes32 private passphrase;
    address payable public bob;
    address public alice;
    uint256 public deadline;

    constructor(bytes32 _signed_passphrase,bytes32 _passphrase,bytes32 _redeemscript,bytes32 _lockingscript, address payable _bob, uint256 _duration) payable {
        signed_passphrase = _signed_passphrase;
        passphrase = _passphrase;
        redeemscript: _redeemscript;
        lockingscript: _lockingscript;
        alice = msg.sender;
        bob = _bob;
        deadline = block.timestamp + _duration;
    }

    function claim(string memory X_Private_key,string memory TRX_Hash) external {
        require(keccak256(signMessage(X_Private_key, passphrase)) == signed_passphrase, "Wrong passphrase");
        require(msg.sender == bob, "Sender must be Bob");
        bob.transfer(address(this).balance);
    }

    function refund() external {
        require(block.timestamp >= deadline, "Too early for refund");
        require(msg.sender == alice, "Sender must be Alice");
        payable(alice).transfer(address(this).balance);
    }
}