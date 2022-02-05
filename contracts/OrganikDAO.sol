/** /
    ORGANIK DAO
    February 2022
    Deployed by Organik, INC.
/**/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.4/contracts/token/ERC20/ERC20.sol"
// Organik Contracts v0.0.1 (contracts/OrganikDAO.sol)
contract OrganikDAO is ReentrancyGuard, AccessControl, ERC20 {

    constructor () public ERC20 ("OrganikDAO", "ORGANIK") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals()) ) )
        // This line will mint 1M coins to the Contract Address.
    }

    bytes32 public constant FARMER = keccak256("FARMER");
    bytes32 public constant MEMBER = keccak256("MEMBER");
    bytes32 public constant STAKEHOLDER = keccak256("STAKEHOLDER");

    uint32 constant votingPeriodA = 1 day;
    uint32 constant votingPeriodB = 2 days;
    uint32 constant votingPeriodC = 3 days;

    uint256 public proposalsCount = 0;
    uint256 public eventsCount = 0;
    uint256 public bookingsCount = 0;

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
    mapping(address => uint256) private stakeholders;
    mapping(address => uint256) private members;
    mapping(address => uint256) private farmers;
    mapping(uint256 => Proposal) private proposals;
    mapping(address => uint256[]) private votes;

    // Define events (Similar to hooks)
    event NewMember(address indexed fromAddress, uint256 amount);
    event NewProposal(address indexed proposer, uint256 amount);
    event Payment(
        address indexed stakeholder,
        address indexed projectAddress,
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

    modifier onlyStakeholder(string memory message) {
        require(hasRole(STAKEHOLDER, msg.sender), message);
        _;
    }

    // Functions.

    // create Proposal
    function createProposal(
        string calldata title,
        string calldata desc,
        address receiverAddress,
        uint256 amount,
        string calldata imageId
    ) public payable onlyMember("Only members can create new proposal.") {
        require(
            msg.value == 5 * 10**18,
            "You need to add 5 MATIC to create a proposal"
        );
        uint256 proposalId = proposalsCount;
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.desc = desc;
        proposal.title = title;
        proposal.receiverAddress = payable(receiverAddress);
        proposal.proposer = payable(msg.sender);
        proposal.amount = amount;
        proposal.livePeriod = block.timestamp + votingPeriod;
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
        onlyStakeholder("Only Stakeholder can call this function.")
        returns (uint256[] memory)
    {
        return votes[msg.sender];
    }

    // Vote on Proposal
    function vote(uint256 proposalId, bool inFavour)
        public
        onlyStakeholder("Only Stakeholders can vote on a proposal.")
    {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.isCompleted || proposal.livePeriodA <= block.timestamp) {
            proposal.isCompleted = true;
            revert("Time period of this proposal is ended (1 day).");
        }
        for (uint256 i = 0; i < votes[msg.sender].length; i++) {
            if (proposal.id == votes[msg.sender][i])
                revert("You can only vote once.");
        }

        if (inFavour) proposal.voteInFavor++;
        else proposal.voteAgainst++;
        votes[msg.sender].push(proposalId);
        _mint(msg.sender, 1 * (10 ** uint256(decimals()) ) )
    }

    // Get ORGANIK Balances
    function getOrganikBal()
        public
        view
        returns (uint256)
    {
        return balanceOf(msg.sender);
    }

    function getOrganikSupply()
        public
        view
        returns (uint256)
    {
        return totalSupply(msg.sender);
    }

    function burnOrganik(
        uint256 amount)
        public
        view
        returns (uint256)
    {
        return _burn(msg.sender, amount);
    }

    function sendOrganik(
        address receiverAddress,
        uint256 amount)
        public
        view
        returns (uint256)
    {
        return transfer(receiverAddress, amount);
    }

    // Get MATIC Balances
    function getStakeholderBal()
        public
        view
        onlyStakeholder("Only Stakeholder can call this function.")
        returns (uint256)
    {
        return stakeholders[msg.sender];
    }

    function getMemberBal()
        public
        view
        onlyMember("Only Members can call this function.")
        returns (uint256)
    {
        return members[msg.sender];
    }

    function getFarmerBal()
        public
        view
        onlyFarmer("Only Farmers can call this function.")
        returns (uint256)
    {
        return farmers[msg.sender];
    }

    // Fund MATIC into Treasury
    function provideFunds(uint256 proposalId, uint256 fundAmount)
        public
        payable
        onlyStakeholder("Only Stakeholders can make payments")
    {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.voteInFavor + proposal.voteAgainst;
        if (proposal.isPaid) revert("Required funds are provided.");
        if (totalVotes <= 3)
            revert("This proposal did not meet the minimum required votes (3).");
        if (proposal.voteInFavor <= proposal.voteAgainst)
            revert("This proposal is not selected for funding.");
        if (proposal.totalFundRaised >= proposal.amount)
            revert("Required funds are provided.");
        proposal.totalFundRaised += fundAmount;
        proposal.funders.push(Funding(msg.sender, fundAmount, block.timestamp));
        if (proposal.totalFundRaised >= proposal.amount) {
            proposal.isCompleted = true;
            _mint(proposal.receiverAddress, proposal.totalFundRaised * (10 ** uint256(decimals()) ) )
        }
        _mint(msg.sender, fundAmount * (10 ** uint256(decimals()) ) )
    }

    // Release MATIC from Treasury
    function releaseFunding(uint256 proposalId)
        public
        payable
        onlyStakeholder("Only Stakeholders are allowed to release funds")
    {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.totalFundRaised <= proposal.amount) {
            revert("Required funds are not met. Please provide more funds.");
        }
        proposal.receiverAddress.transfer(proposal.totalFundRaised);
        proposal.isPaid = true;
        proposal.isCompleted = true;
    }

    // Create STAKEHOLDER
    function createStakeholder() public payable {
        uint256 amount = msg.value;
        if (!hasRole(STAKEHOLDER, msg.sender)) {
            uint256 total = members[msg.sender] + amount;
            if (total >= 20 ether) {
                _setupRole(STAKEHOLDER, msg.sender);
                _setupRole(MEMBER, msg.sender);
                stakeholders[msg.sender] = total;
                members[msg.sender] += amount;
                farmers[msg.sender] += amount;
            } else {
                if (!hasRole(MEMBER, msg.sender)) {
                    if (total >= 2 ether) {
                        _setupRole(MEMBER, msg.sender);
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
            stakeholders[msg.sender] += amount;
        }
        // Mint X ORGANIK Tokens
        _mint(msg.sender, amount * (10 ** uint256(decimals()) ) )
    }
    

}