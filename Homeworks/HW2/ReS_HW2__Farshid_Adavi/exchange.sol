pragma solidity >=0.7.0 <0.9.0;

contract EXChange {
    address payable alice = payable(0xdD870fA1b7C4700F2BD7f44238821C26f7392148);
    address payable bob = payable(0x583031D1113aD414F02576BD6afaBfb302140225);
    bytes32 public hashNonce;
    bytes32 public nonce;
    uint256 init_block_number;
    uint256 alice_balance;
    uint256 bob_balance;
    // 120 H = 120 * 60 * 60 s
    // each block = 12 s
    // 120H = 120 * 60 * 5 block = 36,000 block
    // 72H = 72 * 60 * 5 block = 21,600 block
    uint256 get_ETH_back_after_n_block = 36000;
    uint256 bob_has_time_as_n_block_to_call_set_nonce_by_bob = 21600;
    constructor(address bob_, bytes32 hashNonce_, uint256 n) payable 
    {
        require(msg.value == 20 ether);
        alice_balance = 20 ether;
        alice = payable(msg.sender);
        bob = payable(bob_);
        hashNonce = hashNonce_;
        init_block_number = block.number;
        get_ETH_back_after_n_block = n; // for example alice set 21,600 block
    }

    function set_nonce_by_bob(bytes32 nonce_) public
    {
        require(block.number > init_block_number + bob_has_time_as_n_block_to_call_set_nonce_by_bob);
        require(msg.sender == bob);
        require(keccak256(abi.encodePacked(nonce_)) == hashNonce);
        nonce = nonce_;
        alice_balance = 0;
        bob_balance = 20 ether;
    }

    function get_nonce_by_alice() public view returns (bytes32) 
    {
        require(msg.sender == alice);
        return nonce;
    }

    function withdraw() public
    {
        require((msg.sender==alice &&  block.number > init_block_number + get_ETH_back_after_n_block) ||
                (msg.sender==bob));

        if(msg.sender == alice)
        {
            uint256 temp = alice_balance;
            alice_balance = 0;
            (bool sent, bytes memory data1) = bob.call{value: temp}("");
            require(sent);
        }
        else
        {
            uint256 temp = bob_balance;
            bob_balance = 0;
            (bool sent, bytes memory data1) = bob.call{value: temp}("");
            require(sent);
        }
    }

    
}