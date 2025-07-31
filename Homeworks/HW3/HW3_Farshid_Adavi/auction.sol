pragma solidity >=0.8.2 <0.9.0;

contract RockPaperScissors
{
  // Variables:

    // hard-code the address of auctioneer.
    address payable public auctioneer = payable (0xdD870fA1b7C4700F2BD7f44238821C26f7392148);

    // constant values
    uint constant public commit_time_interval = 24 * 300; // Time to register based on the number of blocks.
    uint constant public reveal_time_interval = 4 * 300; // Time to reveal based on the number of blocks.


    // It will be set in contract constructor function.
    uint public start_auction_block_number;

    //
    uint public number_of_bidders = 0;
    uint public number_of_reveals = 0;

    // Just set by auctioneer.
    uint public default_price = 1 ether; // default is 1 Ether.
    function set_default_price(uint price) public 
    {
        require(msg.sender == auctioneer);
        default_price = price;
    }


    // Use to quickly determine the winner.
    bool public isEnoghToPickWinner = false;

    // Use to enable withdraw function.
    bool public winnerPicked = false;

    // winner of auction.
    address public bigest_bid_address = address(0);

    // At first, bidders commit the hash of their bid.
    // hash(bid, nonce)
    mapping(address => bytes32) public committed_bids;

    // Determines the amount of bid for each bidders when revealing.
    mapping(address => uint) public bids;    



    constructor()
    {
        start_auction_block_number=block.number;
        bids[bigest_bid_address] = 0;
    }

    // Two below functions are only for testing and should be deleted in the main contract.
    function change_auctioneer_address_easily_for_testing(address payable _auctioneer) public 
    {
        auctioneer = _auctioneer;
    }


    

    
    // bidders need to register and pay default_price to auctioneer.
    // Commit and then reveal to prevent frontrunning attack.
    // bidders must choose a nonce in length of 256 (256 characters).
    // then send sha256(bid, nonce).
    function registerAndCommit(bytes32 h) public payable 
    {
        require(block.number <= start_auction_block_number + commit_time_interval, "Register timed out");
        require(committed_bids[msg.sender] == 0, "You have already committed");
        require(msg.value == default_price,"Deposit amount muste be exactly default_price");

        committed_bids[msg.sender]=h;
        number_of_bidders += 1;
    }


    // There is no overlap between commit and reveal time interval.
    // So no one can make a frontrunning attack.
    // Also, withdraw will not be possible for bidders that didn't reveal.
    // So we don't have non response either. We must choose the default price wisely.
    // If it is too big, applicants may not participate. If it is small, someone may register with 
    // several addresses and reveal the winner in only the lowest bid along with smaller bids.
    // In fact, if we can estimate the maximum value of this product for others.
    // Half of this estimate can be a good option. Because if he registers with more than one address,
    // as soon as one of the bids is not revealed and the winner's address is revealed, we will reach the expected amount.
    function reveal(uint bid, string memory _nonce) public payable
    {
        require(committed_bids[msg.sender] != 0,"You are not registerd in auction.");
        require(block.number > start_auction_block_number + commit_time_interval,"Reveal time has not started.");
        require(block.number <= start_auction_block_number + commit_time_interval + reveal_time_interval,"Reveal timed out.");
        require(bids[msg.sender] == 0,"You have already revealed.");
        require(bytes(_nonce).length == 256, "Invalid input, Nonce should be 256 characters.");
        require(bid >= 0, "Invalid input, bid >= 0 allowed.");
        require(sha256(bytes(string(abi.encodePacked(bid, _nonce))))==committed_bids[msg.sender], 
                "Invalid input, your nonce or price is not compatible with your commit in the previous step.");

        if(bid > default_price)
            require(msg.value == bid-default_price,"Deposit amount muste be exactly equal to your bid - default_price");
        bids[msg.sender]=bid;
        number_of_reveals += 1;

        if(bids[msg.sender]>bids[bigest_bid_address])
            bigest_bid_address = msg.sender;

        if(number_of_reveals == number_of_bidders)
            isEnoghToPickWinner = true;
            pickWinner();
    }

    // The winner is determined in the reveal function.
    // Here we only check the terms of the end of the auction so that those who did not win can withdraw their money.
    function pickWinner() public 
    {
        require(!winnerPicked ,"The winner has been determined. Check the result.");
        require(block.number > start_auction_block_number + commit_time_interval + reveal_time_interval ||
                 isEnoghToPickWinner, "You can't call this function in this block number.");

                
        winnerPicked = true;
    }


    // In this withdraw function:
        // extort money or force to recive:
            // No one can force other player to recive money and she only takes her own money and
            // no one can act as a malicious and try to extort in withdraw function, because each player 
            // just recive his money.
        // re-entrancy:
            // No one can make re-entrancy because his moneys be 0 befor call fallback functions.
            // Also withdraw function is locked when called and cannot be re-entrancy by one address.
            // In addition to preventing re-entrancy, this lock prevents any disturbance that may occur
            // in two calls with different addresses.
        // bribing miner:
            // No one can bribing miner becuse eache playe's money is fixed.
        // over-flow:
            // No one can attack by over-flow because we withdraw hole money in one transaction.

    bool public withdraw_is_busy = false;
    function withdraw() public
    {
        require(!withdraw_is_busy, "Withdraw is busy, try some later.");
        withdraw_is_busy = true;
        require(winnerPicked, "The auction is not over.");
        require(msg.sender!=bigest_bid_address, "You won and you can't withdraw money");
        require(bids[msg.sender]!=0, "You can't withdraw money, maby didn't revel or register.");

        uint amount_payable = bids[msg.sender];
        bids[msg.sender]=0;

        (bool sent, bytes memory data) = address(msg.sender).call{value: amount_payable}("");
        require(sent);
        withdraw_is_busy = false;
    }
}