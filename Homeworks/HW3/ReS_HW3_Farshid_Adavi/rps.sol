pragma solidity >=0.8.2 <0.9.0;

contract RockPaperScissors
{
  // Variables:

    // hard-code the addresses
    address payable public alice = payable (0xdD870fA1b7C4700F2BD7f44238821C26f7392148);
    address payable public bob = payable (0x583031D1113aD414F02576BD6afaBfb302140225);

    // constant values
    uint constant public depositAmount = 1 ether;
    uint constant public rewardAmount = 2 ether;
    uint constant public time_interval = 10; // Time interval between steps; Based on the number of blocks
    uint constant public waiting_time = 50; // Waiting time for second player register; Based on the number of blocks

    // 
    uint public aliceDeposit = 0 ether; 
    uint public bobDeposit = 0 ether;

    // It will be set as soon as both players register.
    // Note: Registration is possible with the payment of exactly 1 Ethereum.
    uint public start_game_block_number;

    // It will be true as soon as start_game_block_number be set
    bool public gameStart = false;

    // to avoid locking money of the first registerd player.
    // When the second player does not register.
    uint public first_register_block_number;
    bool public gameEnd = false;


    // Use to quickly determine the winner
    bool public isEnoghToPickWinner = false;

    //
    bool public winnerPicked = false;
    
    // used to the result of the game.
    enum Result { None, Equal, AliceWon, BobWon }
    Result result = Result.None;
    // used to select players.
    enum Move { None, Rock, Paper, Scissors }
    mapping(address => Move) public moves;
    
    // At first, players commit the hash of their choice.
    // hash(move, nonce)
    mapping(address => bytes32) public committed_moves;
    
    // Flags
    mapping(address => bool) public commit_flag;
    mapping(address => bool) public reveal_flag;

    // Determines the amount of money for each player when withdrawing.
    mapping(address => uint) public moneys;



    // Two below functions are only for testing and should be deleted in the main contract.
    function change_alices_address_easily_for_testing(address payable _alice) public 
    {
        alice = _alice;
    }
    function change_bobs_address_easily_for_testing(address payable _bob) public 
    {
        bob = _bob;
    }

    constructor()
    {
        first_register_block_number=block.number;
        start_game_block_number=block.number;
    }

    
    // Alice and Bob need to register and pay 1 Ethereum to participate in the competition.
    function only_alice_and_bob_can_register() public payable 
    {
        require(block.number < (first_register_block_number + waiting_time) - (time_interval + time_interval),"Game timed out");
        require((msg.sender == alice && aliceDeposit == 0) || 
                (msg.sender == bob && bobDeposit == 0),
                "only Alice and Bob can register");
        require(msg.value == depositAmount,"Deposit amount muste be exactly 1 Ether");

        if(msg.sender == alice)
            aliceDeposit = depositAmount;
        else
            bobDeposit = depositAmount;

        moneys[msg.sender] = 0 ether;
        moves[msg.sender] = Move.None;
        commit_flag[msg.sender] = false;
        reveal_flag[msg.sender] = false;
        
        

        if(aliceDeposit==depositAmount && bobDeposit==depositAmount)
        {
            start_game_block_number = block.number; 
            gameStart = true;
        }
        else 
            first_register_block_number = block.number;
    }



    // // An extra register function to start game between each two random players.
    // uint numberOfPlayer;
    // function register() public payable 
    // {
    //     require(block.number < first_register_block_number + waiting_time - (2 * time_interval));
    //     require(numberOfPlayer<2,"Game is full, please try another session");
    //     require(msg.value == depositAmount,"depositAmount muste be exactly 1 Ether");
    //     numberOfPlayer += 1;
    //     if(numberOfPlayer==1)
    //     {
    //         alice = msg.sender; // Alice is a fake name for first player
    //         first_register_block_number = block.number;
        
    //     else if(numberOfPlayer==2)
    //     {
    //         bob = msg.sender; // Bob is a fake name for second player
    //         start_game_block_number = block.number; 
    //         gameStart = true;
    //     }
    // }

    
    // Commit and then reveal to prevent frontrunning attack.
    // player must choose a nonce in length of 256 (256 characters).
    // then send sha256(move, _nonce).
    function commit(bytes32 h) public payable 
    {
        require(msg.sender == alice || msg.sender == bob,"Only Alice and Bob can commit");
        require(gameStart,"Game has not started");
        require(block.number < start_game_block_number + time_interval,"Commit timed out");
        require(!commit_flag[msg.sender],"You have already committed");
        commit_flag[msg.sender]=true;
        committed_moves[msg.sender]=h;
    }

    // There is no overlap between commit and reveal time interval.
    // Also, it will not be accept reveal of a player that didn't commit.
    // So no one can make a frontrunning attack.
    // We will continue to see that not responding at any stage after registration is equivalent to loss and loss of money.
    // So we don't have non response either.
    function reveal(Move move, string memory _nonce) public
    {
        require(msg.sender == alice || msg.sender == bob,"Only Alice and Bob can reveal.");
        require(gameStart,"Game has not started.");
        require(block.number > start_game_block_number + time_interval,"Reveal time has not started.");
        require(block.number < start_game_block_number + 2 * time_interval,"Reveal timed out.");
        require(commit_flag[msg.sender],"You haven't committed and there's no point in revealing.");
        require(!reveal_flag[msg.sender],"You have already revealed.");
        require(bytes(_nonce).length == 256, "Invalid input, Nonce should be 256 characters.");
        require(move != Move.None, "Invalid input, Selecting None is not allowed.");
        require(sha256(bytes(string(abi.encodePacked(move, _nonce))))==committed_moves[msg.sender], 
                "Invalid input, your nonce and choice is not compatible with your commit in the previous step.");

        reveal_flag[msg.sender]=true;
        moves[msg.sender]=move;
        
        if(moves[alice]!=Move.None && moves[bob]!=Move.None)
            isEnoghToPickWinner = true;
            pickWinner();
    }

    // Determining the winner is separated from the payment.
    // All possible states are considered in this function.
    function pickWinner() public 
    {
        require(!winnerPicked && !gameEnd,"The winner has been determined. Check the result.");
        require(block.number > start_game_block_number + 2 * time_interval ||
                 isEnoghToPickWinner ||
                 block.number > first_register_block_number + waiting_time,
                 "You can't call this function in this block number.");
        // Case 1: Both players have successfully registered.
        if(gameStart) 
        {   // Case 1.1: Both players have successfully committed and revealed without cheating.
            if(reveal_flag[alice] && reveal_flag[bob]) //
            {
                // Case 1.1.1: In this case, Alice is the winner.
                if(
                (moves[alice]==Move.Scissors && moves[bob]==Move.Paper) ||
                (moves[alice]==Move.Paper && moves[bob]==Move.Rock) ||
                (moves[alice]==Move.Rock && moves[bob]==Move.Scissors)
                ) {
                    moneys[alice] = rewardAmount;
                    result = Result.AliceWon;
                }
                // Case 1.1.2: In this case, Bob is the winner.
                else if(
                    (moves[bob]==Move.Scissors && moves[alice]==Move.Paper) ||
                    (moves[bob]==Move.Paper && moves[alice]==Move.Rock) ||
                    (moves[bob]==Move.Rock && moves[alice]==Move.Scissors)
                ) {
                    moneys[bob] = rewardAmount;
                    result = Result.BobWon;
                }
                // Case 1.1.3: In this case, the game is tied.
                else 
                {
                    moneys[alice] = depositAmount;
                    moneys[bob] = depositAmount;
                    result = Result.Equal;
                }
            }
            // Case 1.2: Just Alice have successfully committed and revealed without cheating.
            // And Bob non-responding in commit or reveal or maby both, so Alice is the winner.
            else if((reveal_flag[alice] && !reveal_flag[bob]))
            {
                moneys[alice] = rewardAmount;
                result = Result.AliceWon;
            }
            // Case 1.3: Just Bob have successfully committed and revealed without cheating.
            // And Alice non-responding in commit or reveal or maby both, so Bob is the winner.
            else if((!reveal_flag[alice] && reveal_flag[bob]))
            {
                moneys[bob] = rewardAmount;
                result = Result.BobWon;
            }
            // Case 1.4: None of Alice and Bob have successfully committed and revealed without cheating.
            // And Alice and Bob non-responding in commit or reveal or maby both, so the game is tied.

            else 
            {
                moneys[alice] = depositAmount;
                moneys[bob] = depositAmount;
                result = Result.Equal;
            }
            winnerPicked = true;
        }
        // Case 2: Just one player have successfully registered.
        // We do not have winners or losers.
        // We only announce the end of the game so that the player who registered can withdraw his money.
        else if(block.number > first_register_block_number + waiting_time)
        {
            moneys[alice] = aliceDeposit;
            moneys[bob] = bobDeposit;
        }
        gameEnd = true;
        
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
        require(gameEnd, "The game is not over.");
        require(msg.sender==alice || msg.sender==bob, "You are not Alice or Bob");

        if(msg.sender == alice)
        {
            require(moneys[alice] != 0 ether,"You have no money!");
            uint amount_payable = moneys[alice];
            moneys[alice] = 0 ether;
            (bool sent, bytes memory data) = alice.call{value: amount_payable}("");
            require(sent);
        }
        else if(msg.sender == bob)
        {
            require(moneys[bob] != 0 ether,"You have no money!");
            uint amount_payable = moneys[bob];
            moneys[alice] = 0 ether;
            (bool sent, bytes memory data) = bob.call{value: amount_payable}("");
            require(sent);
        }
        withdraw_is_busy = false;
    }
}