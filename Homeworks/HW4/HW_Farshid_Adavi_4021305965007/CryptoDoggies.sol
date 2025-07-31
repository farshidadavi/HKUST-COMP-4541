pragma solidity >=0.7.0 <0.9.0;

contract CryptoDoggies
{
    address payable developer; //the address of the developer of this contract
    uint16[] doggies; //a list of all of our current doggies
    mapping(uint16 => address) owner; //maps each doggy to its owner

    mapping(address => uint) account_balance; // maps each address to withdrawable balance.
    mapping(address => uint) account_sum_Non_withdrawable; // maps each address to non withdrawable balance.
    mapping(address => bool) intra_account_transfer; // atomic action on non withdrawable balance.
    mapping(uint16 => bool) lock_on_doggy; // atomic action on doggy.

    mapping(uint16 => uint16) currentMate; //current mate of this doggy (decided by its owner)
    mapping(uint16 => uint) price; //the price set by the current owner (assuming they are willing to sell the doggy)

    //The following are hard-coded fees
    uint64 creationFee = 1 ether;
    uint64 breedingFee = 1 ether;
    uint64 sellingFee = 0.1 ether;
    uint64 buyingFee = 0.1 ether;

    event newDoggyEvent(uint16 doggy, address owner); //an event that shows a new doggy was created
    event transferDoggyEvent(uint16 doggy, address old_owner, address new_owner); //an event that is triggered when a doggy is transfered


    constructor()
    {
        developer = payable(msg.sender);
        account_balance[developer] = 0;
    }


    //creates a random uint16 that can be used e.g. as the DNA of a doggy
    function random_uint16() private view returns (uint16)
    {
        uint random = uint(blockhash(block.number))^tx.gasprice;
        uint16 ans = uint16(random % 2**16);
        return ans;
    }


    // New added.
    uint last_birthBlock; 
    uint max_paidCreationFee_MostRecentBlock;
    uint max_paidCreationFee_CurentBlock; // CurentBlock that are generate by miner to put on block chain
    bool after_1000_block = false; // simple flag
    uint64 ten_percent_of_creationFee = creationFee/10; // discourage the developer from continuing to create the doggies

    //creates a new doggy
    bool creation_busy;
    function createNewDoggy() public payable
    {   
        require(!creation_busy); //make sure the createNewDoggy is not busy
        creation_busy = true; //turn on flag

        //make sure the fee that is paid for creating this doggy is enough
        // case 1: most recent block out of range 1000 past block.
        if  (
            block.number >= last_birthBlock + 1000 ||               // first transaction of block
            (after_1000_block && block.number == last_birthBlock)   // other transaction of block
            )
        {
            // first transaction of the block that invoking createNewDoggy() can satisfy this condition.
            if(block.number > last_birthBlock)
            {
                after_1000_block = true; // This flag may hold true before this line, where it is set 
                    // to true by the most recent block that had the same conditions as the current block.
                
                last_birthBlock = block.number; // After set new value for last_birthBlock, 
                    // other transaction in curent block that invoking createNewDoggy() go to else statement.
                require(msg.value >= creationFee); 
                max_paidCreationFee_CurentBlock = msg.value;
            }
            else // other transaction in curent block that invoking createNewDoggy()
            {
                require(msg.value >= creationFee);
                if(msg.value > max_paidCreationFee_CurentBlock)
                    max_paidCreationFee_CurentBlock = msg.value;
            }
        }
            
        // case 2: most recent block in range 1000 past block.
        else if(block.number < last_birthBlock + 1000)  
        {
            // first transaction of the block that invoking createNewDoggy() can satisfy this condition.
            if(block.number > last_birthBlock)
            {
                after_1000_block = false; // This flag may hold false before this line, where it is set 
                    // to false by the first block after which there was no sequence of 1000 blocks in 
                    // the blockchain where createNewDoggy did not generate any doggy.
                    
                last_birthBlock = block.number; // After set new value for last_birthBlock, 
                    // other transaction in curent block that invoking createNewDoggy() go to else statement.
                
                max_paidCreationFee_MostRecentBlock = max_paidCreationFee_CurentBlock; // In this line value of
                    // max_paidCreationFee_CurentBlock gives us the maximum of the paidCreationFee
                    // that was paid in the most recent block.
                require(msg.value * 100 >= max_paidCreationFee_MostRecentBlock * 101);
                max_paidCreationFee_CurentBlock = msg.value;
            }
            else 
            {
                require(msg.value * 100 >= max_paidCreationFee_MostRecentBlock * 101);
                if(msg.value > max_paidCreationFee_CurentBlock)
                    max_paidCreationFee_CurentBlock = msg.value;
            }
        }

        //create a random doggy
        uint16 new_doggy = random_uint16();

        //Avoiding the creation of repeated doggy
        require(owner[new_doggy] == address(0));
        //Avoiding the creation of doggy by genetic code 0.
        require(new_doggy != 0);


        //add it to the list of doggies and put it under the control of the caller of this function
        doggies.push(new_doggy);
        owner[new_doggy] = msg.sender;

        account_balance[developer] += ten_percent_of_creationFee; // Payment of creationFee to the developer

        emit newDoggyEvent(new_doggy, owner[new_doggy]);

        creation_busy = false; //turn off flag
    }


    uint64 ten_percent_of_breedingFee = breedingFee/10; // discourage the developer from continuing to breeding the doggies.
    //This function breeds two new doggies (puppies) from a pair of previously existing doggies. The owners of both doggies must call this function.
    function breedDoggy(uint16 my_doggy, uint16 other_doggy) public payable
    {   
        require(msg.value == breedingFee);      // Sufficient breeding fee.
        require(owner[my_doggy] == msg.sender); // right owner.
        require(currentMate[my_doggy] == 0);    // If the doggy has a mate, the breeding fee should not be paid again.
                                                // He can use cancel_breedDoggy_or_cheang_Mate.

        require(price[my_doggy] == 0);          // Doggy should not be on the sale list.

        require(!intra_account_transfer[msg.sender]);   // This account is not changing anywhere else
        intra_account_transfer[msg.sender] = true;      // We will lock this account until the end of the operation.

            account_sum_Non_withdrawable[msg.sender] += breedingFee; // breedingFee will be added
                                                                     // to the non-withdrawal account balance.

            currentMate[my_doggy] = other_doggy; //this records that the breeding is approved by the current owner.
            
            if(currentMate[other_doggy] == my_doggy) // checks if the other owner has already approved the breeding
            {
                require(!lock_on_doggy[my_doggy]);      // my_doggy is not changing mate or cancel_breedDoggy.
                lock_on_doggy[my_doggy] = true;         // We will lock this my_doggy until the end of the breedDoggy.
                require(!lock_on_doggy[other_doggy]);   // other_doggy is not changing mate or cancel_breedDoggy.
                lock_on_doggy[other_doggy] = true;      // We will lock this other_doggy until the end of the breedDoggy.

                    require(!intra_account_transfer[owner[other_doggy]]); // This account is not changing anywhere else
                    intra_account_transfer[owner[other_doggy]] = true; // We will lock this account until the end of the operation.

                        account_sum_Non_withdrawable[msg.sender] -= breedingFee; 
                        account_sum_Non_withdrawable[owner[other_doggy]] -= breedingFee;

                        account_balance[developer] += ten_percent_of_breedingFee;// Payment of breedingFee to the developer
                        account_balance[developer] += ten_percent_of_breedingFee;// Payment of breedingFee to the developer



                        //create two offspring puppies
                        uint16 puppy1 = random_offspring(my_doggy, other_doggy);
                        require(puppy1 != 0); // Avoiding the creation of doggy by genetic code 0.
                        require(owner[puppy1] == address(0)); //Avoiding the creation of repeated doggy

                        uint16 puppy2 = random_offspring(my_doggy, other_doggy);
                        require(puppy2 != 0); // Avoiding the creation of doggy by genetic code 0.
                        require(owner[puppy2] == address(0)); //Avoiding the creation of repeated doggy

                        require(puppy1 != puppy2); //Avoiding the Identical doggy

                        doggies.push(puppy1);
                        doggies.push(puppy2);
                        owner[puppy1] = owner[my_doggy];
                        owner[puppy2] = owner[other_doggy];                        

                    intra_account_transfer[owner[other_doggy]] = false;

                currentMate[my_doggy] = 0;
                currentMate[other_doggy] = 0;

                lock_on_doggy[my_doggy] = false;
                lock_on_doggy[other_doggy] = false;

                emit newDoggyEvent(puppy1, owner[puppy1]);
                emit newDoggyEvent(puppy2, owner[puppy2]);
            }

        intra_account_transfer[msg.sender] = false;    
    }

    //This function breeds two new doggies (puppies) from a pair of previously existing doggies. The owners of both doggies must call this function.
    function cancel_breedDoggy_or_cheang_Mate(uint16 my_doggy, uint16 other_doggy) public
    {
        require(owner[my_doggy] == msg.sender); // right owner.
        require(currentMate[my_doggy] != 0);    // If the doggy has a mate, can call cancel_breedDoggy_or_cheang_Mate.  

        require(!lock_on_doggy[my_doggy]);      // my_doggy is not breeding now.
        lock_on_doggy[my_doggy] = true;         // We will lock my_doggy until the end of cancel or cheang_Mate.

            currentMate[my_doggy] = other_doggy; // cheang_Mate

            if(other_doggy == 0) // if other_doggy is 0 means canceling.
            {
                require(!intra_account_transfer[msg.sender]);
                intra_account_transfer[msg.sender] = true;

                    account_sum_Non_withdrawable[msg.sender] -= breedingFee; 
                    account_balance[msg.sender] += breedingFee; 

                intra_account_transfer[msg.sender] = false;
            }

        lock_on_doggy[my_doggy] = false;
    }

    //creates a random offspring of two doggies
    function random_offspring(uint16 doggy1, uint16 doggy2) private view returns(uint16)
    {   
        // we use r to decide which bits of the DNA should come from doggy1 
        // and not r to decide which bits of the DNA should come from doggy2
        uint16 r;

        uint16 i;
        uint16 j;

        uint16 r16 = random_uint16() % 16;
        r += uint16(2) ** r16; // r16th bit set as 1. 

        uint16 r15 = random_uint16() % 15;
        i = 0;
        j = 0;
        // check {0th, 1th, ..., r15th} bits in r, whichever is 1 is not among the candidates.
        // We count the number of 1 and put it in j.
        // So actually the r15th bit among the remaining candidates is (r15+j)th bit among all bits of r.
        while(i <= r15)                      // check {0th, 1th, ..., r15th}
        {
            if((r / uint16(2) ** i) %2 == 1) // count the number of 1 and put it in j.
                j += 1;
        }
        r += uint16(2) ** (r15 + j); // r15th bit among the remaining candidates choosen. 
        
        uint16 r14 = random_uint16() % 14;
        // check {0th, 1th, ..., r14th} bits in r, whichever is 1 is not among the candidates.
        // We count the number of 1 and put it in j.
        // So actually the r14th bit among the remaining candidates is (r14+j)th bit among all bits of r.
        i = 0;
        j = 0;
        while(i <= r14)                      // check {0th, 1th, ..., r14th}
        {
            if((r / uint16(2) ** i) %2 == 1) // count the number of 1 and put it in j.
                j += 1;
        }
        r += uint16(2) ** (r14 + j); // r14th bit among the remaining candidates choosen.

        uint16 r13 = random_uint16() % 13;
        // check {0th, 1th, ..., r13th} bits in r, whichever is 1 is not among the candidates.
        // We count the number of 1 and put it in j.
        // So actually the r13th bit among the remaining candidates is (r13+j)th bit among all bits of r.
        i = 0;
        j = 0;
        while(i <= r13)                      // check {0th, 1th, ..., r13th}
        {
            if((r / uint16(2) ** i) %2 == 1) // count the number of 1 and put it in j.
                j += 1;
        }
        r += uint16(2) ** (r13 + j); // r13th bit among the remaining candidates choosen.

        uint16 r12 = random_uint16() % 12;
        // check {0th, 1th, ..., r12th} bits in r, whichever is 1 is not among the candidates.
        // We count the number of 1 and put it in j.
        // So actually the r12th bit among the remaining candidates is (r12+j)th bit among all bits of r.
        i = 0;
        j = 0;
        while(i <= r12)                      // check {0th, 1th, ..., r12th}
        {
            if((r / uint16(2) ** i) %2 == 1) // count the number of 1 and put it in j.
                j += 1;
        }
        r += uint16(2) ** (r12 + j); // r12th bit among the remaining candidates choosen.

        uint16 r11 = random_uint16() % 11;
        // check {0th, 1th, ..., r11th} bits in r, whichever is 1 is not among the candidates.
        // We count the number of 1 and put it in j.
        // So actually the r11th bit among the remaining candidates is (r11+j)th bit among all bits of r.
        i = 0;
        j = 0;
        while(i <= r11)                      // check {0th, 1th, ..., r11th}
        {
            if((r / uint16(2) ** i) %2 == 1) // count the number of 1 and put it in j.
                j += 1;
        }
        r += uint16(2) ** (r11 + j); // r11th bit among the remaining candidates choosen.

        uint16 r10 = random_uint16() % 10;
        // check {0th, 1th, ..., r10th} bits in r, whichever is 1 is not among the candidates.
        // We count the number of 1 and put it in j.
        // So actually the r10th bit among the remaining candidates is (r10+j)th bit among all bits of r.
        i = 0;
        j = 0;
        while(i <= r10)                      // check {0th, 1th, ..., r10th}
        {
            if((r / uint16(2) ** i) %2 == 1) // count the number of 1 and put it in j.
                j += 1;
        }
        r += uint16(2) ** (r10 + j); // r10th bit among the remaining candidates choosen.

        uint16 r9 = random_uint16() % 9;
        // check {0th, 1th, ..., r9th} bits in r, whichever is 1 is not among the candidates.
        // We count the number of 1 and put it in j.
        // So actually the r9th bit among the remaining candidates is (r9+j)th bit among all bits of r.
        i = 0;
        j = 0;
        while(i <= r9)                      // check {0th, 1th, ..., r9th}
        {
            if((r / uint16(2) ** i) %2 == 1) // count the number of 1 and put it in j.
                j += 1;
        }
        r += uint16(2) ** (r9 + j); // r9th bit among the remaining candidates choosen.

        // Now use r to decide which bits of the DNA should come from doggy1
        uint16 offspring = r & doggy1;
        // r                            = 1110111000000011
        // doggy1                       = 1011101111111101
        // r & doggy1                   = 1010101000000001

        // And use ~r to decide which bits of the DNA should come from doggy2 and create final offspring.
        offspring += (~r) & doggy2;
        // ~r                           = 0001000111111100
        // doggy2                       = 1010101010101010
        // ~r & doggy2                  = 0000000010101000

        // r & doggy1                   = 1010101000000001
        // ~r & doggy2                  = 0000000010101000
        // offspring                    = 1010101010101001
        
        return offspring;
    }

    //puts up a doggy for sale
    function sellDoggy(uint16 my_doggy, uint asking_price) public payable
    {
        require(owner[my_doggy] == msg.sender); // right owner.
        require(price[my_doggy] == 0);          // Doggy should not be on the sale list.
        require(currentMate[my_doggy] == 0);    // Avoid of loosing breeding fee. and wrong owner of puppy.

        require(!lock_on_doggy[my_doggy]);
        lock_on_doggy[my_doggy] = true; // set lock until selling be finished or canceled.

            require(!intra_account_transfer[msg.sender]);
            intra_account_transfer[msg.sender] = true;

                require(msg.value == sellingFee);
                require(asking_price > 0); // avoid of over flow go to selling list.
                price[my_doggy] = asking_price;
                account_sum_Non_withdrawable[msg.sender] += sellingFee; 

            intra_account_transfer[msg.sender] = false;
        
    }

    //cancel or sale or cheang price
    function cancel_sale_or_cheang_price(uint16 my_doggy, uint asking_price) public 
    {
        require(owner[my_doggy] == msg.sender); // right owner.
        require(price[my_doggy] > 0);           // Doggy should be on the sale list.
        require(asking_price >= 0);             // avoid over floo in bye

        require(!intra_account_transfer[msg.sender]);
        intra_account_transfer[msg.sender] = true;

            price[my_doggy] = asking_price;
            if(asking_price == 0) // means cancel selling.
            {
                account_sum_Non_withdrawable[msg.sender] -= sellingFee;
                account_balance[msg.sender] += sellingFee;
                lock_on_doggy[my_doggy] = false;
            }
        
        intra_account_transfer[msg.sender] = false;
    }
    //buy a doggy that was previously put up for sale by its owner
    function buyDoggy(uint16 doggy) public payable
    {
        require(price[doggy] > 0);                       // check that the doggy is put up for sale by its owner
        require(msg.value == price[doggy] + buyingFee);  // check that the right value is paid

        require(!intra_account_transfer[owner[doggy]]);  
        intra_account_transfer[owner[doggy]] = true;

            address previous_owner = owner[doggy];

            account_sum_Non_withdrawable [previous_owner] -= sellingFee;
            account_balance[developer] += sellingFee; // pay sellingFee to developer

            account_balance[previous_owner] += (msg.value - buyingFee); // pay price to previous_owner
            account_balance[developer] += buyingFee; // pay buyingFee to developer

            owner[doggy] = msg.sender; // update the owner of the doggy
            emit transferDoggyEvent(doggy, previous_owner, owner[doggy]);

        intra_account_transfer[previous_owner] = false;
    }


    //after the sale goes through, the seller can call this function to get their money
    // function receiveMoney(uint16 my_former_doggy) public
    bool public receiveMoney_is_busy = false;
    function receiveMoney() public
    {
        require(account_balance[msg.sender] > 0);
        require(!receiveMoney_is_busy, "receiveMoney is busy, try later.");
        receiveMoney_is_busy = true;

            address payable recipient = payable(msg.sender);
            uint payable_amount = account_balance[msg.sender]; 
            account_balance[msg.sender] -= payable_amount; // Simultaneously, a dog can be sold,
                // and the proceeds deposited into its account. It's advisable not to set it to zero.
                // However, there's no cause for concern, as funds are solely deposited into this account,
                // and deduction only occurs at this particular stage.
            (bool sent, bytes memory data) = recipient.call{value: payable_amount}(""); //pay the sale value to the previous owner
            require(sent);
            
        receiveMoney_is_busy = false;
    }
}
