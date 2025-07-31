pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Voting {
    // PART 0:
    // An error occurred by the election manager and election faild.
    bool public should_be_false = false;

    // The election manager is the person who signs the ballots and also verifies the signatures. 
    // He is trusted and known by voters and he accepts the responsibility of holding election.  
    // Of course, if until the end of the voting she will be honest and dose the job well as well , he will earn a good money.
    address payable public election_manager_address;
    address payable public court_address;
    // The election number that prevents replay attack by old signed ballots.
    uint16 public election_number;
    uint256 public initial_block_number;

    // This contract has the ability to hold an election worth about 200 million US dollars.
    // 2**16 ballots. 1 eth(about 3000 USD) per ballot.
    // Calling the registration function for the first time costs about 50,000 gas and the next times about 16,000 gas for each address. 
    // Base fee is currently 5 gwei and the average Priority fee is 2 gwei. We consider each unit of gas to be 10 gwei.
    // 2**16 * 50000 * 10 gwei = 32.768 eth.
    // 2 ether for first person that can finde and error or fraud and change should_be_false to true.
    // we receive 32.768 + 2 Ether from the manager as a guarantee for compensation in case of fraud or error.
    constructor(uint16 election_number_) payable 
    {
        // about 35 eth guarantee for compensation in case of fraud or error by election manager.
        // 2**16 * 50000 * 10 gwei + 2 ether equal about 35 eth.
         require(msg.value == 35 ether);
        // we should hard-code this address. but now we set that in constructor in order to easily change in testing time.
        election_manager_address = payable (msg.sender);
        // set initial_block_number.
        initial_block_number = block.number;
        // set new number to prevents replay attack by old signed ballots that this manager signed in former elections.
        election_number = election_number_;
    }


    // PART 1:
    struct signed_blurred_ballots
    {
        // signed_blurred_ballots. "singnature"
        bytes signed_blurred_ballot;
        // Only existing blurred ballots are waiting for signature.
        // We check the validity of the selection by counting the number of votes signed by the manager.
        // It must be equal to the number of total registered ballots .
        // Therefore, it is important to avoid registering a signature and an invalid ballot.
        bool awaiting_signature;
    }
    struct Voter
    {
        // How many times has this voter registered.
        uint16 weight;
        // blurred_ballots to signed_blurred_ballots.
        mapping(bytes32 => signed_blurred_ballots) blurred_ballots;
        bytes32[] blurred_ballots_list;
    }
    mapping(address => Voter) voters;

    // The total number of registered ballots.
    uint16 public total_ballots = 0;
    // Calling the registration function for the first time costs about 50,000 gas and the next times
    // about 36,000 gas for each address. 

    uint32 public t = 48 * 300; //2 day
    // Prevent exceeding total_ballots from the limit by re-entering.
    bool register_is_busy = false;
    
    function register(bytes32 blurred_ballot_) public payable 
    {
        require(!register_is_busy, "register is busy, try some later.");
        register_is_busy = true;
        // 10 day for register(deadline t1)
        require(block.number <= initial_block_number + 5 * t); 
        // manager icnome.
        require(msg.value == 1 ether);
        // prevent overflow in Allowed bollets number.
        require(total_ballots < 2**16 - 1);

        // Blurred ballot registration. ballot * r**e (r is selected by voter)
        voters[msg.sender].blurred_ballots[blurred_ballot_].awaiting_signature = true;
        voters[msg.sender].weight += 1;
        voters[msg.sender].blurred_ballots_list.push(blurred_ballot_);
        total_ballots += 1;
        register_is_busy = false;
    }

    uint16 public total_signed_ballots = 0;
    bool public all_Signatures_are_ready= false;

    function Signing(address voter_address, bytes32 blurred_ballot, bytes memory signed_blurred_ballot) public 
    {
        // Only election manager can signs the ballots.
        require(msg.sender == election_manager_address); 
        // start after register time.
        require(block.number > initial_block_number + 5 * t); 
        // 2 day for Signing.
        require(block.number <= initial_block_number + 6 * t); 
        // Only existing blurred ballots are waiting for signature.
        require(voters[voter_address].blurred_ballots[blurred_ballot].awaiting_signature); 
        
        // set signed blurred ballot. blurred_ballot**d(d is manager dncryption key)
        voters[voter_address].blurred_ballots[blurred_ballot].signed_blurred_ballot = signed_blurred_ballot; 
        total_signed_ballots += 1;
        if(total_ballots == total_signed_ballots)
            all_Signatures_are_ready = true;
    }

    bool all_ballots_were_signed_ = false;
    uint256 manager_second_depose;
    function all_ballots_were_signed() public payable
    {
        // Only election manager can signs the ballots.
        require(msg.sender == election_manager_address);
        // after register time.
        require(block.number > initial_block_number + 5 * t);
        // 2 day for Signing.
        require(block.number <= initial_block_number + 6 * t);
        // The manager should increase the amount of the deposit to guarantee the gas consumption at the time of commitment.
        // If he approves a committee whose signature is not valid, it means that the manager has cheated and the election is cancelled.
        if(total_ballots * 50000 * 10 * 2 gwei > 35000000000 gwei)//prevent overflow
        {
            require(msg.value == total_ballots * 50000 * 10 * 2 gwei - 35000000000 gwei);
            manager_second_depose = total_ballots * 50000 * 10 * 2 gwei - 35000000000 gwei;
        }

        // just call one time.
        require(!all_ballots_were_signed_);
        all_ballots_were_signed_ = true;
    }

    // PART 2:
    bool stop_flag1 = false;
    function stop_election() public 
    {
        // after signing time.
        require(block.number > initial_block_number + 6 * t);
        // all ballots were not signed in it's time.
        require(!all_ballots_were_signed_);
        stop_flag1 = true;
        should_be_false = true;
    }

    address payable Plaintiff;
    bool need_court_judgment_flag = false;
    function there_is_something_wrong_with_my_ballots()public payable 
    {
        // only after all ballots were signed.
        require(all_ballots_were_signed_);
        // find one false signature is enogh.
        require(!should_be_false);
        // 2 day for objection to false signature.
        require(block.number <= initial_block_number + 7 * t);
        // To prevent unnecessary protests with the intention of disrupting work.
        // If you have protested without reason. You will pay the damages for the re-arrangement.
        // At this stage, the result of the election has not been determined and there is no point in protesting.
        if(total_ballots * 50000 * 10 gwei > voters[msg.sender].weight * 1000000000 gwei)//prevent overflow
            require(msg.value == total_ballots * 50000 * 10 gwei - voters[msg.sender].weight * 1000000000 gwei);

        should_be_false = true;
        need_court_judgment_flag = true;
        Plaintiff = payable (msg.sender);
    }

    struct ballot
    {
        bytes32 hash_ballot;
        bytes signed_hash_ballot;
        bool validity;
        bool commited_flag;
        bool revealed_flag;
    }
    mapping(address => ballot) public ballots;
    
    function commit(bytes32 hash_ballot_, bytes memory signed_hash_ballot_) public //53k gas
    {
        // only after all ballots were signed.
        require(all_ballots_were_signed_);
        // find one false signature is enogh to stop all election.
        require(!should_be_false);


        // start after check_sign time.
        require(block.number > initial_block_number + 7 * t); 
        // 2 day for committing.
        require(block.number <= initial_block_number + 8 * t); 

        require(!ballots[msg.sender].commited_flag,"You have already committed");
        ballots[msg.sender].commited_flag = true;
        ballots[msg.sender].hash_ballot = hash_ballot_;
        ballots[msg.sender].signed_hash_ballot = signed_hash_ballot_;
    }
    uint16 number_of_verified_ballots = 0;
    function verify_committed_ballots_signature_by_manager(address committed_address_, bool validity_) public 
    {
        // Only election manager can signs the ballots.
        require(msg.sender == election_manager_address); 
        // only after all ballots were signed.
        require(all_ballots_were_signed_);
        // find one false signature is enogh to stop all election.
        require(!should_be_false);
        // start after committing time.
        require(block.number > initial_block_number + 8 * t); 
        // 2 day for verify.
        require(block.number <= initial_block_number + 9 * t); 

        // set signed blurred ballot. blurred_ballot**d(d is manager dncryption key)
        ballots[committed_address_].validity = validity_;
        number_of_verified_ballots += 1;
    }

    bool all_ballots_were_verified_ = false;

    function all_ballots_were_verified() public
    {
        // Only election manager can signs the ballots.
        require(msg.sender == election_manager_address);
        // only after all ballots were signed.
        require(all_ballots_were_signed_);
        // find one false signature is enogh to stop all election.
        require(!should_be_false);
        // start after committing time.
        require(block.number > initial_block_number + 8 * t); 
        // 2 day for verify.
        require(block.number <= initial_block_number + 9 * t); 

        // just call one time.
        require(!all_ballots_were_verified_);

        // just call one time.
        require(!all_ballots_were_verified_);
        all_ballots_were_verified_ = true;
    }

    // PART 3:
    bool stop_flag2 = false;
    function stop_election2() public 
    {
        // only after all ballots were signed.
        require(all_ballots_were_signed_);
        // find one false signature is enogh to stop all election.
        require(!should_be_false);
        // after verify time.
        require(block.number > initial_block_number + 9 * t);
        // all ballots were not verify in it's time.
        require(!all_ballots_were_verified_);

        // some extra ballots verify in it's time.
        require(number_of_verified_ballots > total_ballots);
        
        should_be_false = true;
        stop_flag2 = true;
    }

    function there_is_something_wrong_with_verified_ballots()public payable 
    {
        // only after all ballots were veryfied.
        require(all_ballots_were_verified_);
        // find one false signature is enogh.
        require(!should_be_false);
        // after verify time.
        require(block.number > initial_block_number + 9 * t);
        // 2 day for objection to false signature.
        require(block.number <= initial_block_number + 10 * t);

        // To prevent unnecessary protests with the intention of disrupting work.
        // If you have protested without reason. You will pay the damages for the re-arrangement.
        // At this stage, the result of the election has not been determined and there is no point in protesting.
        if(total_ballots * 50000 * 10 *2 gwei > voters[msg.sender].weight * 1000000000 gwei)//prevent overflow
            require(msg.value == total_ballots * 50000 * 10 * 2 gwei - voters[msg.sender].weight * 1000000000 gwei);
        should_be_false = true;
        need_court_judgment_flag = true;
        Plaintiff = payable (msg.sender);
    }

    mapping(uint16 => uint16) Votes_of_candidates;
    uint16 public first_candida = 0;
    uint16 public number_of_vote_of_first_candida = 0;

    function reveal(uint16 k_,  uint256 _nonce) public
    {
        // only after all ballots were veryfied.
        require(all_ballots_were_verified_);
        // find one false signature is enogh.
        require(!should_be_false);
        // start after verify_sign time.
        require(block.number > initial_block_number + 10 * t); 
        // 2 day for revealing.
        require(block.number <= initial_block_number + 11 * t);  

        require(ballots[msg.sender].commited_flag,"You haven't committe so You can't reveal.");
        require(ballots[msg.sender].validity,"Your committe signature did not veryfied.");
        require(!ballots[msg.sender].revealed_flag,"You have already revealed.");

        require(sha256(bytes(string(abi.encodePacked(election_number, k_ ,_nonce))))==ballots[msg.sender].hash_ballot, 
                "Invalid input, your nonce, choice and election_number is not compatible with your commit in the previous step.");

        ballots[msg.sender].revealed_flag = true;

        Votes_of_candidates[k_] += 1;
        if(Votes_of_candidates[k_] > number_of_vote_of_first_candida)
            first_candida = k_;
    }
    
    bool public winnerPicked = false;
    event winner(string, uint16);
    bool public end_of_ellection = false;

    function pickWinner() public
    {
        require(!should_be_false);
        require(!winnerPicked);
        // start after reveal time.
        require(block.number > initial_block_number + 11 * t);
        
        winnerPicked = true;
        end_of_ellection = true;
        emit winner("winner ID: ",first_candida);
    }

    bool public withdraw_is_busy = false;
    function withdraw() public //40k
    {   
        require(!withdraw_is_busy, "Withdraw is busy, try some later.");
        withdraw_is_busy = true;
        require(end_of_ellection || should_be_false, "The election is not over.");
        
        // ellection ended as well
        if(end_of_ellection)
        {
            if(msg.sender != election_manager_address)
            {
                require(voters[msg.sender].weight != 0,"You have no money!");

                uint amount_payable = 0.9 ether * voters[msg.sender].weight;
                voters[msg.sender].weight = 0;
                
                (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                require(sent);
            }
            else
            {
                require(total_ballots != 0,"You have no money!");
                
                uint amount_payable = 0.1 ether * total_ballots + 35 ether + manager_second_depose * 1 gwei;
                total_ballots = 0;
                
                (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                require(sent);
            }
        }
        else if(stop_flag1 || stop_flag2)
        {
            if(stop_flag1)
            {
                if(msg.sender != election_manager_address)
                {
                    require(voters[msg.sender].weight != 0,"You have no money!");

                    uint amount_payable = (1 ether + 50000 * 10 gwei) * voters[msg.sender].weight;
                    voters[msg.sender].weight = 0;
                    
                    (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                    require(sent);
                }
                else
                {
                    require(total_ballots != 0,"You have no money!");
                    
                    uint amount_payable = 35 ether - 50000 * 10 gwei * total_ballots;
                    total_ballots = 0;
                    
                    (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                    require(sent);
                }
            }
            else if(stop_flag2)
            {
                if(msg.sender != election_manager_address)
                {
                    require(voters[msg.sender].weight != 0,"You have no money!");

                    uint amount_payable = (1 ether + 50000 * 10 * 2 gwei) * voters[msg.sender].weight;
                    voters[msg.sender].weight = 0;
                    
                    (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                    require(sent);
                }
                else
                {
                    require(total_ballots != 0,"You have no money!");
                    
                    uint amount_payable = 35 ether + manager_second_depose * 1 gwei - 50000 * 10 * 2 gwei * total_ballots;
                    total_ballots = 0;
                    
                    (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                    require(sent);
                }
            }
                
        }

        else
        {
            if(all_ballots_were_verified_)
            {
                if((msg.sender != election_manager_address && msg.sender != Plaintiff)&&msg.sender != court_address)
                {
                    require(voters[msg.sender].weight != 0,"You have no money!");

                    uint amount_payable = (1 ether + 50000 * 10 *2 gwei) * voters[msg.sender].weight;
                    voters[msg.sender].weight = 0;
                    
                    (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                    require(sent);
                }
                else if(msg.sender == court_address)
                {
                    require(total_ballots != 0,"You have no money!");
                    
                    uint amount_payable = 35 ether - 50000 * 10 * 2 gwei * total_ballots;
                    if(total_ballots * 50000 * 10 *2 gwei > voters[Plaintiff].weight * 1000000000 gwei)//prevent overflow
                        amount_payable += total_ballots * 50000 * 10 *2 gwei;
                    else 
                        amount_payable += voters[Plaintiff].weight * 1000000000 gwei;
                    total_ballots = 0;
                    voters[Plaintiff].weight = 0;
                    (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                    require(sent);
                }
            }
            else 
            {
                if((msg.sender != election_manager_address && msg.sender != Plaintiff)&&msg.sender != court_address)
                {
                    require(voters[msg.sender].weight != 0,"You have no money!");

                    uint amount_payable = (1 ether + 50000 * 10 * 1 gwei) * voters[msg.sender].weight;
                    voters[msg.sender].weight = 0;
                    
                    (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                    require(sent);
                }
                else if(msg.sender == court_address)
                {
                    require(total_ballots != 0,"You have no money!");
                    
                    uint amount_payable = 35 ether - 50000 * 10 * 1 gwei * total_ballots;
                    if(total_ballots * 50000 * 10 * 1 gwei > voters[Plaintiff].weight * 1000000000 gwei)//prevent overflow
                        amount_payable += total_ballots * 50000 * 10 * 1 gwei;
                    else 
                        amount_payable += voters[Plaintiff].weight * 1000000000 gwei;
                    total_ballots = 0;
                    voters[Plaintiff].weight = 0;
                    (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                    require(sent);
                }
            }
                
        }

        withdraw_is_busy = false;
    }
}