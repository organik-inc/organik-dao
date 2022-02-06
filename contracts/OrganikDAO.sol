/** /
    ORGANIK DAO
    February 2022
    Deployed by Organik, INC.
/**/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// Organik Contracts v0.0.4 (contracts/OrganikDAO.sol)
contract OrganikDAO is ReentrancyGuard, AccessControl, ERC20 {
    address owner;
    bytes32 public constant FARMER = keccak256("FARMER");
    bytes32 public constant MEMBER = keccak256("MEMBER");
    bytes32 public constant SPONSOR = keccak256("SPONSOR");
    uint32 constant votingPeriodA = 1 days;
    uint32 constant votingPeriodB = 2 days;
    uint32 constant votingPeriodC = 3 days;
    uint256 public proposalsCount = 0;
    uint256 public eventsCount = 0;
    uint256 public bookingsCount = 0;
    constructor () public ERC20 ("OrganikDAO", "ORGANIK") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals()) ) );
        owner = msg.sender;
        // This line will mint 1M coins to the Contract Address.
    }
    // Define all Structs (Keep it simple). Can we map into Moralis DB?
    struct Proposal {
        uint256 id;
        uint256 amount;
        uint256 livePeriod;
        uint256 voteInFavor;
        uint256 voteAgainst;
        string title;
        string desc;
        bool isCompleted;
        bool isPaid;
        address payable receiverAddress;
        address proposer;
        uint256 totalFundRaised;
        Funding[] funders;
        string imageId;
    }
    struct Funding {
        address payer;
        uint256 amount;
        uint256 timestamp;
    }
    // Define mappings (key => value maps)
    mapping(address => uint256) private sponsors;
    mapping(address => uint256) private members;
    mapping(address => uint256) private farmers;
    mapping(uint256 => Proposal) private proposals;
    mapping(address => uint256[]) private votes;
    // Define events (Similar to hooks)
    event NewMember(address indexed fromAddress, uint256 amount);
    event NewProposal(address indexed proposer, uint256 amount);
    event Payment(
        address indexed sponsor,
        address indexed projectAddress,
        uint256 amount
    );
    event NewTransfer(
        address indexed senderAddress,
        address indexed receiverAddress,
        uint256 amount
    );
    event NewBurn(
        address indexed fromAddress,
        uint256 amount
    );
    // Modifiers
    modifier onlyFarmer(string memory message) {
        require(hasRole(FARMER, msg.sender), message);
        _;
    }
    modifier onlyMember(string memory message) {
        require(hasRole(MEMBER, msg.sender), message);
        _;
    }
    modifier onlySponsor(string memory message) {
        require(hasRole(SPONSOR, msg.sender), message);
        _;
    }
    // Contract Custom Functions:
    // create Proposal
    function createProposal(
        string calldata title,
        string calldata desc,
        address receiverAddress,
        uint256 amount,
        string calldata imageId
    ) public payable onlyFarmer("Only farmers can create new proposals.") {
        require(
            msg.value == 5 * 10** uint256(decimals()) ,
            "You need to add exactly 5 MATIC to create a proposal"
        );
        uint256 proposalId = proposalsCount;
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.desc = desc;
        proposal.title = title;
        proposal.receiverAddress = payable(receiverAddress);
        proposal.proposer = payable(msg.sender);
        proposal.amount = amount;
        proposal.livePeriod = block.timestamp + votingPeriodA;
        proposal.isPaid = false;
        proposal.isCompleted = false;
        proposal.imageId = imageId;
        proposalsCount++;
        emit NewProposal(msg.sender, amount);
    }
    // Proposals and Votes.
    function getAllProposals() public view returns (Proposal[] memory) {
        Proposal[] memory tempProposals = new Proposal[](proposalsCount);
        for (uint256 index = 0; index < proposalsCount; index++) {
            tempProposals[index] = proposals[index];
        }
        return tempProposals;
    }
    function getProposal(uint256 proposalId)
        public
        view
        returns (Proposal memory)
    {
        return proposals[proposalId];
    }
    function getVotes()
        public
        view
        onlySponsor("Only Sponsors can call this function.")
        returns (uint256[] memory)
    {
        return votes[msg.sender];
    }
    // Vote on Proposal
    function vote(uint256 proposalId, bool inFavour)
        public
        onlySponsor("Only Sponsors can vote on a proposal.")
    {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.isCompleted || proposal.livePeriod <= block.timestamp) {
            proposal.isCompleted = true;
            revert("Time period of this proposal has ended (1 day).");
        }
        for (uint256 i = 0; i < votes[msg.sender].length; i++) {
            if (proposal.id == votes[msg.sender][i])
                revert("You can only vote once.");
        }
        if (inFavour) proposal.voteInFavor++;
        else proposal.voteAgainst++;
        votes[msg.sender].push(proposalId);
        _mint(msg.sender, 1);
    }
    // Check if sender is Owner
    function isOwner() 
        public
        view
        returns (bool) 
    {
        if(owner == msg.sender){
            return true;
        }else{
            return false;
        }
    }
    // Check highest role for sender
    function getRole()
        public
        view
        returns (string memory)
    {
        if (!hasRole(SPONSOR, msg.sender) && !hasRole(MEMBER, msg.sender) && !hasRole(FARMER, msg.sender)) {
            return "FALSE";
        }else{
            if (!hasRole(SPONSOR, msg.sender)) {
                if(!hasRole(MEMBER, msg.sender)){
                    return "FARMER";
                }else{
                    return "MEMBER";
                }
            }else{
                return "SPONSOR";
            }
        }
    }
    // Get ORGANIK Balances
    function getOrganikBal()
        public
        view
        returns (uint256)
    {
        return balanceOf(msg.sender);
    }
    // Get ORGANIK Total Supply
    function getOrganikSupply()
        public
        view
        returns (uint256)
    {
        return totalSupply();
    }
    // Burn Organik Tokens based in Community Trust
    function burnOrganik(uint256 amount) public virtual {
        emit NewBurn(msg.sender, amount);
        _burn(msg.sender, amount);
    }
    // Transfer Organik Tokens to another Address.
    function sendOrganik(address receiverAddress, uint256 amount) public virtual {
        emit NewTransfer(msg.sender, receiverAddress, amount);
        transfer(receiverAddress, amount);
    }
    // Get MATIC Balance for Sponsor
    function getSponsorBal()
        public
        view
        onlySponsor("Only Sponsors can call this function.")
        returns (uint256)
    {
        return sponsors[msg.sender];
    }
    // Get MATIC Balance for Member
    function getMemberBal()
        public
        view
        onlyMember("Only Members can call this function.")
        returns (uint256)
    {
        return members[msg.sender];
    }
    // Get MATIC Balance for Farmer
    function getFarmerBal()
        public
        view
        onlyFarmer("Only Farmers can call this function.")
        returns (uint256)
    {
        return farmers[msg.sender];
    }
    // Fund proposal with MATIC from Treasury
    function provideFunds(uint256 proposalId, uint256 fundAmount)
        public
        payable
        onlySponsor("Only Sponsors can make payments")
    {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.voteInFavor + proposal.voteAgainst;
        if (proposal.isPaid) revert("Required funds are provided.");
        if (totalVotes <= 3)
            revert("This proposal did not meet the minimum required votes (3).");
        if (proposal.voteInFavor <= proposal.voteAgainst)
            revert("This proposal is not selected for funding.");
        if (proposal.totalFundRaised >= proposal.amount)
            revert("Required funds are already provided.");
        uint256 balance = getSponsorBal();
        if ( balance >= 1 && balance >= fundAmount){
            if (proposal.totalFundRaised >= proposal.amount) {
                // Ignored. Already funded.
            }else{
                // Add funds to Projects.
                proposal.totalFundRaised += fundAmount;
                // Deduct Funds from Sponsor (Map).
                sponsors[msg.sender] -= fundAmount;
                members[msg.sender] -=  fundAmount;
                farmers[msg.sender] -=  fundAmount;
                proposal.funders.push(Funding(msg.sender, fundAmount, block.timestamp));
                if (proposal.totalFundRaised >= proposal.amount) {
                    if(proposal.isCompleted){
                        // Ignored. Already Completed.
                    }else{
                        proposal.isCompleted = true;
                        for (uint j = 0; j < proposal.funders.length; j++) {
                        // Spread Organik Rewards among all funding sponsors.
                        _mint(proposal.funders[j].payer, proposal.funders[j].amount);
                        }
                    }
                }
            }
        }else{
            revert("Sponsor does not have enough funds in Treasury.");
        }
    }
    // Release MATIC from Treasury
    function releaseFunding(uint256 proposalId)
        public
        payable
        onlySponsor("Only Sponsors are allowed to release funds")
    {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.totalFundRaised <= proposal.amount) {
            revert("Required funds are not met. Please provide more funds.");
        }
        proposal.receiverAddress.transfer(proposal.totalFundRaised);
        proposal.isPaid = true;
        proposal.isCompleted = true;
    }
    function _ceil(uint a, uint m) private returns (uint ) {
        return ((a + m - 1) / m) * m;
    }
    // Create STAKEHOLDER
    function createStakeholder() public payable {
        uint256 amount = msg.value;
        if (!hasRole(SPONSOR, msg.sender)) {
            uint256 total = farmers[msg.sender] + amount;
            if (total >= 50 ether) {
                _setupRole(SPONSOR, msg.sender);
                _setupRole(MEMBER, msg.sender);
                _setupRole(FARMER, msg.sender);
                sponsors[msg.sender] = total;
                members[msg.sender] += amount;
                farmers[msg.sender] += amount;
            } else {
                if (!hasRole(MEMBER, msg.sender)) {
                    if (total >= 20 ether) {
                        if (!hasRole(FARMER, msg.sender)) {
                            _setupRole(MEMBER, msg.sender);
                            _setupRole(FARMER, msg.sender);
                        }else{
                            _setupRole(MEMBER, msg.sender);
                        }
                        members[msg.sender] += amount;
                        farmers[msg.sender] += amount;
                    }else{
                        _setupRole(FARMER, msg.sender);
                        farmers[msg.sender] += amount;
                    }
                }else{
                    members[msg.sender] += amount;
                    farmers[msg.sender] += amount;
                }
            }
        } else {
            members[msg.sender] += amount;
            sponsors[msg.sender] += amount;
        }
        // Mint X ORGANIK Tokens
        _mint(msg.sender, amount );
    }
}