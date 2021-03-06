pragma solidity >=0.5.0 <0.6.0;

import "./supportingLibraries/SafeMath.sol";
import "./supportingContracts/Stoppable.sol";

/**
* @title Bounty Dapp v1.0
* @author Shebin John
* @notice You can use this contract to start, close, and participate in a Bounty
* @dev All functions are currently working without any errors
*/
contract bountydAppv1 is Stoppable{

    using SafeMath for uint256;

    enum resolverIndicator {
        Invalid, Valid /// @dev By default is Invalid. Validated by the owner
    }

    enum statusIndicator {
        Open, Disputed, Closed /// @dev By default in Open. Disputed/Closed by the hunter/user
    }

    enum acceptanceIndicator {
        Pending, Accepted, Rejected /// @dev By default in Pending. Accepted/Rejected by the user
    }

    enum disputeIndicator {
        No, Yes, Done /// @dev By default in No. Once disputed can't be disputed again, thus "Done"
    }

    struct BountyDetails {
        uint256 amount; /// @dev For storing the amount of money paid for Bounty
        uint256 deadline; /// @dev For storing the deadline of Bounty, if it equals to zero, means no deadline
        uint256 acceptedSolutionID; /// @dev For storing which solution was accepted for this bounty
        statusIndicator status; /// @dev To store whether the bounty is Open or Closed
        address bountyCreator; /// @dev To store the bounty initiator's address
        string description; /// @dev To store the details of the bounty to be done
    }

    struct SolutionDetails {
        uint256 bountyID; /// @dev To store which bounty's solution is this
        uint256 linkedSolution; /// @dev If earlier solution rejected and the bounty is still open, this helps to link to previous solution
        acceptanceIndicator acceptanceStatus; /// @dev To store the status of the solution
        disputeIndicator disputeStatus; /// @dev To store the status of the dispute
        address bountyHunter; /// @dev To store the bounty hunter's address
        string solution; /// @dev To store the details of the solution to the bounty
        string comment; /// @dev To store the comment from bounty creator is rejected
    }

    uint256 public bountyID;
    uint256 public solutionID;
    uint256 public noOfResolvers; /// @dev This is to store the no of valid resolvers only
    uint256 public totalNoOfResolvers; /// @dev This is to store the no of resolvers in the resolvers array
    uint256 public majority; /// @dev This is to store the majority of resolvers
    address[] public resolvers; /// @dev These stores the dispute revolvers addresses. Currently hardcorded at the time of instantiation.
    uint256[] public disputeQueue;

    mapping (address => uint256) public balances; /// @dev To store the balances of users
    mapping (address => resolverIndicator) public resolverStatus; /// @dev Indicate whether a resolver is valid or not
    mapping (uint256 => BountyDetails) public bounties; /// @dev To store the bounty based on bountyID
    mapping (uint256 => SolutionDetails) public solutions; /// @dev To store the solution based on solutionID
    mapping (address => uint256[]) public addressToBountyList; /// @dev To store the bounties created by a single user
    mapping (address => uint256[]) public addressToSolutionList; /// @dev To store the solutions created by a single user
    mapping (uint256 => uint256[]) public bountyToSolutionList; /// @dev To store all the solutionIDs of submitted solution in a single bounty
    mapping (uint256 => uint256[10]) public disputeQueueVotes;
    mapping (uint256 => uint256[10]) public disputeQueueSigner;

    event ResolverAdded(address indexed resolverCreator, address indexed resolver);
    event ResolverUpdated(address indexed resolverUpdater, address indexed resolver, resolverIndicator indexed status);
    event BountyCreated(uint256 indexed bountyID, address indexed bountyCreator, uint256 value);
    event SolutionCreated(uint256 indexed bountyID, uint256 indexed solutionID, address indexed solutionCreator);
    event SolutionRejected(uint256 indexed bountyID, uint256 indexed solutionID);
    event DisputeRaised(uint256 indexed bountyID, uint256 indexed solutionID);
    event DisputeSolved(uint256 indexed bountyID, uint256 indexed solutionID);
    event BountyClosedWithWinner(uint256 indexed bountyID, address indexed bountyCloser, address indexed bountyWinner);
    event BountyClosedWithoutWinner(uint256 indexed bountyID, address indexed bountyCloser);
    event Deposit(address indexed from, uint256 value);
    event Withdrawed(address indexed to, uint256 value);

    constructor(bool initialRunState) public Stoppable(initialRunState) {
    }

    /**
    *   @notice This function helps to add a new resolver
    *   @dev Takes the address of the resolver and adds it to the resolver array
    *   @param _resolver The address of the resolver
    *   @return success or failure
    */
    function addResolver(address _resolver) public onlyOwner onlyIfRunning returns(bool){

        require(resolverStatus[_resolver] == resolverIndicator.Invalid, "Already a Valid Resolver");
        uint256 _totalNoOfResolvers = totalNoOfResolvers;
        uint256 _index = _totalNoOfResolvers;
        for(uint256 i = 0; i < _totalNoOfResolvers; i++){
            if(resolvers[i] == _resolver){
                _index = i;
            }
        }
        require(_index == _totalNoOfResolvers, "Resolver previously added by Owner, use updateResolver()");

        resolvers.push(_resolver);
        resolverStatus[_resolver] = resolverIndicator.Valid;
        totalNoOfResolvers = _totalNoOfResolvers.add(1);
        uint256 _noOfResolvers = noOfResolvers.add(1);
        noOfResolvers = _noOfResolvers;
        majority = (_noOfResolvers.div(2)).add(1);

        emit ResolverAdded(msg.sender, _resolver);

        return true;

    }

    /**
    *   @notice This function helps to update a resolver status
    *   @dev Takes the address of the resolver and updates it's status along with majority and noOfResolvers
    *   @param _resolver The address of the resolver
    *   @param _status The status of the resolver
    *   @return success or failure
    */
    function updateResolver(address _resolver, resolverIndicator _status) public onlyOwner onlyIfRunning returns(bool){

        uint256 _totalNoOfResolvers = totalNoOfResolvers;
        uint256 _index = _totalNoOfResolvers;
        for(uint256 i = 0; i < _totalNoOfResolvers; i++){
            if(resolvers[i] == _resolver){
                _index = i;
            }
        }
        require(_index != _totalNoOfResolvers, "Resolver not previously added by Owner"); /// @dev To check concerned resolver is in Queue or not

        uint256 _noOfResolvers = 0;
        if(_status == resolverIndicator.Valid){
            require(resolverStatus[_resolver] == resolverIndicator.Invalid, "The resolver is already valid");
            resolverStatus[_resolver] = resolverIndicator.Valid;
            _noOfResolvers = noOfResolvers.add(1);
            noOfResolvers = _noOfResolvers;
        }
        else{
            require(resolverStatus[_resolver] == resolverIndicator.Valid, "The resolver is already Invalid");
            resolverStatus[_resolver] = resolverIndicator.Invalid;
            _noOfResolvers = noOfResolvers.sub(1);
            noOfResolvers = _noOfResolvers;
        }

        majority = (_noOfResolvers.div(2)).add(1);

        emit ResolverUpdated(msg.sender, _resolver, _status);

        return true;

    }

    /**
    *   @notice This function helps to create a unique bounty ID
    *   @dev Takes no inputs and returns unique bountyID recently created
    *   @return bountyID in uint256, which defines the newly created bounty's ID
    */
    function createBountyID() internal returns(uint256){

        uint256 _bountyID = bountyID.add(1);
        bountyID = _bountyID;
        return _bountyID;

    }

    /**
    *   @notice This function helps to create a bounty
    *   @dev Takes the necessary inputs and returns the bountyID recently created
    *   @param _amount The amount which will be given to complete the bounty
    *   @param _deadline The time until which the bounty will be live. Zero means forever
    *   @param _description The detail about the bounty to be completed
    *   @return bountyID in uint256, which defines the newly created bounty's ID
    */
    function createBounty(uint256 _amount, uint256 _deadline, string memory _description) public payable onlyIfRunning returns(uint256){

        deposit(); /// @dev to handle any deposits

        uint256 balance = balances[msg.sender]; /// @dev Decrease storage read operations
        require(_amount <= balance, "Not enough balance to create Bounty");
        if(_deadline > 0){
            require(_deadline > now, "Deadline specified is already passed");
        }

        balances[msg.sender] = balance.sub(_amount);

        uint256 _bountyID = createBountyID();

        bounties[_bountyID].amount = _amount;
        bounties[_bountyID].deadline = _deadline;
        bounties[_bountyID].bountyCreator = msg.sender;
        bounties[_bountyID].description = _description;

        addressToBountyList[msg.sender].push(_bountyID);

        emit BountyCreated(_bountyID, msg.sender, _amount);

        return _bountyID;

    }

    /**
    *   @notice This function helps to deposit money into the contract
    *   @dev Only people with enough balance will be able to create bounty
    */
    function deposit() internal {

        if(msg.value > 1){
            balances[msg.sender] = balances[msg.sender].add(msg.value);
        }

        emit Deposit(msg.sender, msg.value);

    }


    /**
    *   @notice This function helps to get the length of the Bounty submitted by a single user
    *   @dev Takes no inputs and returns length of Bounty Queue
    *   @return bounty queue length in uint256
    */
    function addressToBountyListLength() public view returns(uint256){

        return addressToBountyList[msg.sender].length;

    }

    /**
    *   @notice This function helps to get the length of the Solutions submitted to a single bounty
    *   @dev Takes the bounty ID as input and returns length of Solutions submitted
    *   @return solution queue length in uint256
    */
    function bountyToSolutionListLength(uint256 _bountyID) public view returns(uint256){

        return bountyToSolutionList[_bountyID].length;

    }

    /**
    *   @notice This function helps to create a unique solution ID
    *   @dev Takes no inputs and returns unique solutionID recently created
    *   @return solutionID in uint256, which defines the newly created solution's ID
    */
    function createSolutionID() internal returns(uint256){

        uint256 _solutionID = solutionID.add(1);
        solutionID = _solutionID;
        return _solutionID;

    }

    /**
    *   @notice This function helps to create a solution
    *   @dev Takes the necessary inputs and returns the solutionID recently created
    *   @param _bountyID The ID of bounty whose solution is created
    *   @param _linkedSolution The ID of earlier solution which is linked to this solution
    *   @param _solution The detail about the solution for the bounty
    *   @return solutionID in uint256, which defines the newly created solution's ID
    */
    function addSolution(uint256 _bountyID, uint256 _linkedSolution, string memory _solution) public onlyIfRunning returns(uint256){

        require(bounties[_bountyID].status == statusIndicator.Open, "Solution can only be submitted to Open Bounties");

        uint256 _deadline = bounties[_bountyID].deadline;
        if(_deadline > 0){ /// @dev If it is zero, then there is no deadline.
            require(_deadline > now, "Bounty Deadline has Reached!");
        }

        uint256 _solutionID = createSolutionID();

        solutions[_solutionID].bountyID = _bountyID;
        if(_linkedSolution == 0){
            solutions[_solutionID].linkedSolution = _solutionID;
        }
        else{
            solutions[_solutionID].linkedSolution = _linkedSolution;
        }
        solutions[_solutionID].bountyHunter = msg.sender;
        solutions[_solutionID].solution = _solution;

        bountyToSolutionList[_bountyID].push(_solutionID);
        addressToSolutionList[msg.sender].push(_solutionID);

        emit SolutionCreated(_bountyID, _solutionID, msg.sender);

        return _solutionID;

    }

    /**
    *   @notice This function helps to get the length of the Solution submitted by a single user
    *   @dev Takes no inputs and returns length of Solution Queue
    *   @return solution queue length in uint256
    */
    function addressToSolutionListLength() public view returns(uint256){

        return addressToSolutionList[msg.sender].length;

    }

    /**
    *   @notice This function helps to accept a solution for a bounty
    *   @dev Takes the necessary inputs and updates the state of a bounty
    *   @param _solutionID The ID of solution which is accepted
    *   @return status in bool
    */
    function acceptSolution(uint256 _solutionID) public onlyIfRunning returns(bool){

        uint256 _bountyID = solutions[_solutionID].bountyID;
        require(bounties[_bountyID].bountyCreator == msg.sender, "Only Bounty Creator can accept a solution with this function");
        require(bounties[_bountyID].acceptedSolutionID == 0, "A solution already accepted");
        require(bounties[_bountyID].status == statusIndicator.Open, "Only Open bounties can accept a solution");

        bounties[_bountyID].acceptedSolutionID = _solutionID;
        bounties[_bountyID].status = statusIndicator.Closed;
        solutions[_solutionID].acceptanceStatus = acceptanceIndicator.Accepted;

        address _bountyHunter = solutions[_solutionID].bountyHunter;

        emit BountyClosedWithWinner(_bountyID, msg.sender, _bountyHunter);

        balances[_bountyHunter] = balances[_bountyHunter].add(bounties[_bountyID].amount);

        return true;

    }

    /**
    *   @notice This function helps to reject a solution for a bounty
    *   @dev Takes the necessary inputs and updates the state of a solution
    *   @param _solutionID The ID of solution which is rejected
    *   @param _comment Any comment from the bounty poster about the solution
    *   @return status in bool
    */
    function rejectSolution(uint256 _solutionID, string memory _comment) public onlyIfRunning returns(bool){

        uint256 _bountyID = solutions[_solutionID].bountyID;
        require(bounties[_bountyID].bountyCreator == msg.sender, "Only bounty creator can reject a solution");
        require(solutions[_solutionID].acceptanceStatus == acceptanceIndicator.Pending, "Only pending solutions can be rejected.");

        solutions[_solutionID].acceptanceStatus = acceptanceIndicator.Rejected;
        solutions[_solutionID].comment = _comment;

        emit SolutionRejected(_bountyID, _solutionID);

        return true;

    }

    /**
    *   @notice This function helps to get the length of the Dispute Queue
    *   @dev Takes no inputs and returns length of Dispute Queue
    *   @return dispute queue length in uint256
    */
    function disputeQueueLength() public view returns(uint256){

        return disputeQueue.length;

    }

    /**
    *   @notice This function helps to raise a dispute for a solution which was rejected
    *   @dev Takes the necessary inputs and starts a dispute process for a solution
    *   @param _solutionID The ID of solution which was rejected
    *   @return status in bool
    */
    function raiseDispute(uint256 _solutionID) public onlyIfRunning returns(bool){

        uint256 _bountyID = solutions[_solutionID].bountyID;
        require(solutions[_solutionID].bountyHunter == msg.sender, "Only bounty hunter can raise a dispute for their rejected solution");
        require(solutions[_solutionID].disputeStatus == disputeIndicator.No, "Dispute is ongoing or completed already");
        require(bounties[_bountyID].acceptedSolutionID == 0, "Amount already won by someone else");
        require(bounties[_bountyID].status == statusIndicator.Open, "Only open bounties can be disputed");

        disputeQueue.push(_solutionID);

        bounties[_bountyID].status = statusIndicator.Disputed;
        solutions[_solutionID].disputeStatus = disputeIndicator.Yes;

        emit DisputeRaised(_bountyID, _solutionID);

        return true;

    }

    /**
    *   @notice This function helps to check a dispute on solution raised by a hunter which was rejected
    *   @dev For the dispute to be solved a majority is formed from approved resolvers
    *   @param _vote The vote given by the resolver
    *   @param _disputeIndex The index of the disputed solution
    *   @return status in bool
    */
    function solveDispute(uint256 _disputeIndex, uint256 _vote) public onlyIfRunning returns(bool){

        uint256 _solutionID = disputeQueue[_disputeIndex];

        require(resolverStatus[msg.sender] == resolverIndicator.Valid, "Only a Valid resolver can call this function");
        uint256 _totalNoOfResolvers = totalNoOfResolvers;
        uint256 _index = _totalNoOfResolvers;
        for(uint256 i = 0; i < _totalNoOfResolvers; i++){
            if(resolvers[i] == msg.sender){
                _index = i;
            }
        }
        require(_index != _totalNoOfResolvers, "Only a resolver can call this function");
        require(disputeQueueSigner[_solutionID][_index] == 0, "Already Signed");
        require(_vote == 0 || _vote == 1, "Either rejected or acccepted");
        require(solutions[_solutionID].disputeStatus == disputeIndicator.Yes, "Dispute solved already");

        disputeQueueVotes[_solutionID][_index] = _vote;
        disputeQueueSigner[_solutionID][_index] = 1;

        uint256 allSigned;
        for(uint256 i = 0; i < disputeQueueSigner[_solutionID].length; i++) {
            allSigned = allSigned.add(disputeQueueSigner[_solutionID][i]);
        }
        if(allSigned >= majority){

            uint256 result;
            for(uint256 i = 0; i < disputeQueueVotes[_solutionID].length; i++) {
                result = result.add(disputeQueueVotes[_solutionID][i]);
            }

            uint256 _bountyID = solutions[_solutionID].bountyID;

            if(result >= majority){

                bounties[_bountyID].acceptedSolutionID = _solutionID;
                bounties[_bountyID].status = statusIndicator.Closed;
                solutions[_solutionID].acceptanceStatus = acceptanceIndicator.Accepted;
                solutions[_solutionID].disputeStatus = disputeIndicator.Done;

                address _bountyHunter = solutions[_solutionID].bountyHunter;

                emit BountyClosedWithWinner(_bountyID, msg.sender, _bountyHunter);

                balances[_bountyHunter] = balances[_bountyHunter].add(bounties[_bountyID].amount);
                emit DisputeSolved(_bountyID, _solutionID);

            }
            else if (allSigned == noOfResolvers) {

                bounties[_bountyID].status = statusIndicator.Open;
                solutions[_solutionID].disputeStatus = disputeIndicator.Done;
                emit DisputeSolved(_bountyID, _solutionID);

            }

        }

        return true;

    }

    /**
    *   @notice This function helps to close a bounty without accepting any solution
    *   @dev Could be called by bounty maker to close it without a solution or internal call from acceptSolution function
    *   @param _bountyID The ID of bounty which is to be closed
    *   @return status in bool
    */
    function closeBounty(uint256 _bountyID) public onlyIfRunning returns(bool){

        require(bounties[_bountyID].bountyCreator == msg.sender, "Only Bounty Creator can close its bounty");
        require(bounties[_bountyID].status == statusIndicator.Open, "Only open bounties can be closed.");
        require(bounties[_bountyID].deadline < now, "Only bounties whose deadline has been passed can be closed.");

        bounties[_bountyID].status = statusIndicator.Closed;

        emit BountyClosedWithoutWinner(_bountyID, msg.sender);

        balances[msg.sender] = balances[msg.sender].add(bounties[_bountyID].amount);

        return true;
    }

    /**
    *   @notice This function helps to withdraw money from the contract
    *   @dev Only people with balance not tied to any bounty will be able to withdraw
    *   @param _amount The amount to withdraw
    *   @return status in bool
    */
    function withdraw(uint256 _amount) public onlyIfRunning returns(bool status){

        require(_amount > 0, "Zero cant be withdrawn");

        uint256 balance = balances[msg.sender];
        // require(balance >= amount, "Withdraw amount requested higher than balance");
        // Commented because the next line will revert if amount is a value greater than balance

        balances[msg.sender] = balance.sub(_amount);

        emit Withdrawed(msg.sender, _amount);

        msg.sender.transfer(_amount);
        return true;

    }

}