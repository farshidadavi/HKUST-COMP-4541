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
    constructor(uint16 election_number_) payable //44946 gas
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
    }
    mapping(address => Voter) public voters;

    // The total number of registered ballots.
    uint16 public total_ballots = 0;
    // Calling the registration function for the first time costs about 50,000 gas and the next times
    // about 16,000 gas for each address. 

    uint32 public t = 2; //48 * 300
    // Prevent exceeding total_ballots from the limit by re-entering.
    bool register_is_busy = false;

    function register(bytes32 blurred_ballot) public payable //56130 39030 gas
    {
        require(!register_is_busy, "register is busy, try some later.");
        register_is_busy = true;
        // 10 day for register(deadline t1)
        require(block.number <= initial_block_number + 5 * t); 
        // manager icnome.
        require(msg.value == 1 ether);
        // prevent overflow in Allowed bollets number.
        require(total_ballots < 2**16 - 1);

        // Blurred ballot registration. In the course, we learned blind signature based on RSA.
        // But since public key and private key are very large numbers, powering with these numbers is very expensive,
        // they are obsolete, and in Ethereum and even in Bitcoin, we have keys based on elliptic curves cryptography. 
        // As a result, Blind Signature is also based on ECC(Elliptic-curve cryptography).
        voters[msg.sender].blurred_ballots[blurred_ballot].awaiting_signature = true;
        voters[msg.sender].weight += 1;
        total_ballots += 1;
        register_is_busy = false;
    }

    
    uint16 public total_signed_ballots = 0;
    bool public all_Signatures_are_ready= false;

    function Signing(address voter_address, bytes32 blurred_ballot, bytes memory signed_blurred_ballot) public //104k
    {
        // Only election manager can signs the ballots.
        require(msg.sender == election_manager_address); 
        // start after register time.
        require(block.number > initial_block_number + 5 * t); 
        // 2 day for Signing.
        require(block.number <= initial_block_number + 7 * t); 
        // verify Signature. Currently this function is not working. Description in PDF file.
        // require(verify_blind_Signature(blurred_ballot,signed_blurred_ballot,address(msg.sender))); 
        // Only existing blurred ballots are waiting for signature.
        require(voters[voter_address].blurred_ballots[blurred_ballot].awaiting_signature); 
        // set signed blurred ballot. blurred_ballot**d(d is manager dncryption key)

        voters[voter_address].blurred_ballots[blurred_ballot].signed_blurred_ballot = signed_blurred_ballot; 
        total_signed_ballots += 1;
        if(total_ballots == total_signed_ballots)
            all_Signatures_are_ready = true;
    }

    // PART 2:

    function stop_election() public // 10k
    {
        // after signing time.
        require(block.number > initial_block_number + 7 * t);
        // all ballots were not signed in signing time.
        require(!all_Signatures_are_ready && !should_be_false);
        should_be_false = true;
    }

    struct ballot
    {
        bytes32 hash_ballot;
        // This two flags use for control commit and reveal.
        bool commited_flag; 
        bool revealed_flag;
    }
    mapping(address => ballot) public ballots;
    
    function commit(bytes32 hash_ballot, bytes memory signed_hash_ballot) public //53k
    {
        // If should_be_false flag is true means the election stopet.
        require(!should_be_false, "election stoped! There was a problem in signing ballots. You can take the paid expenses plus the gas consumed and wait for the official announcement of the manager.");
        // all ballots were should be signed in previus.
        // In fact, there is a state where all the ballots are not signed and it is time to commit.
        // But no one has called stop_election yet.
        require(all_Signatures_are_ready);
        // start after Signing time.
        require(block.number > initial_block_number + 7 * t);
        // 2 day for committing.
        require(block.number <= initial_block_number + 9 * t);

        require(!ballots[msg.sender].commited_flag,"You have already committed");
        // verify Signature.
        // require(verify_blind_Signature(hash_ballot, signed_hash_ballot, election_manager_address)); 

        ballots[msg.sender].commited_flag = true;
        ballots[msg.sender].hash_ballot = hash_ballot;
    }

    mapping(uint16 => uint16) Votes_of_candidates;
    uint16 public first_candida = 0;
    uint16 public number_of_vote_of_first_candida = 0;

    function reveal(uint16 k_,  uint256 _nonce) public //49k
    {
        // start after commit time.
        require(block.number > initial_block_number + 9 * t); 
        // 2 day for revealing.
        require(block.number <= initial_block_number + 11 * t); 

        require(ballots[msg.sender].commited_flag,"You haven't commit.");
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
                
                uint amount_payable = 0.1 ether * total_ballots + 35 ether;
                total_ballots = 0;
                
                (bool sent, bytes memory data) = msg.sender.call{value: amount_payable}("");
                require(sent);
            }
        }
        else 
        {
            if(msg.sender != election_manager_address)
            {
                require(voters[msg.sender].weight != 0,"You have no money!");

                uint amount_payable = 1 ether * voters[msg.sender].weight + 50000 * 10 gwei;
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

        withdraw_is_busy = false;
    }


    using ECDSA for bytes32;
    function verify_blind_Signature(
        bytes32 horiginalText,
        bytes memory signature,
        address publicKey
    ) public returns (bool) {
        address recoveredSigner = horiginalText.recover(signature);
        bool isValid = address(recoveredSigner) == address(publicKey);

        return isValid;
    } 
}