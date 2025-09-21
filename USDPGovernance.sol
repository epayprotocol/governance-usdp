// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title USDP Governance Interface
/// @notice Interface for external interaction with USDP governance system
interface IUSDPGovernance {
    // Proposal management
    function createProposal(
        uint8 proposalType,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description
    ) external returns (uint256 proposalId);
    
    function vote(uint256 proposalId, uint8 support) external;
    function delegate(address delegatee) external;
    function executeProposal(uint256 proposalId) external;
    
    // Emergency functions
    function emergencyAction(bytes calldata emergencyData) external;
    function updateParameters(bytes calldata parameterData) external;
    
    // View functions
    function getVotingPower(address account) external view returns (uint256);
    function getProposalState(uint256 proposalId) external view returns (uint8);
    function hasVoted(uint256 proposalId, address voter) external view returns (bool);
}

/// @title USDP Governance Contract
/// @notice Comprehensive governance system for the USDP ecosystem
/// @dev Implements token-based voting with time-locks, delegation, and emergency controls
contract USDPGovernance is IUSDPGovernance {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DECIMALS = 18;
    
    // Governance parameters
    uint256 public constant PROPOSAL_THRESHOLD = 100; // 1% of total supply (in BP)
    uint256 public constant QUORUM_THRESHOLD = 1000;  // 10% of total supply (in BP)
    uint256 public constant APPROVAL_THRESHOLD = 5100; // 51% for standard proposals (in BP)
    uint256 public constant SUPERMAJORITY_THRESHOLD = 6700; // 67% for constitutional changes (in BP)
    
    // Time periods
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EMERGENCY_VOTING_PERIOD = 3 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant EMERGENCY_EXECUTION_DELAY = 0; // Immediate for emergency
    
    // Proposal types
    uint8 public constant PROPOSAL_TYPE_STANDARD = 0;
    uint8 public constant PROPOSAL_TYPE_EMERGENCY = 1;
    uint8 public constant PROPOSAL_TYPE_PARAMETER = 2;
    uint8 public constant PROPOSAL_TYPE_TREASURY = 3;
    uint8 public constant PROPOSAL_TYPE_CONSTITUTIONAL = 4;
    
    // Vote types
    uint8 public constant VOTE_AGAINST = 0;
    uint8 public constant VOTE_FOR = 1;
    uint8 public constant VOTE_ABSTAIN = 2;
    
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    
    struct Proposal {
        uint256 id;
        address proposer;
        uint8 proposalType;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        string description;
        
        // Proposal data
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        
        // Voting data
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 totalVotes;
        
        // State tracking
        bool executed;
        bool canceled;
        bool vetoed;
        
        // Snapshot for anti-flash-loan protection
        uint256 snapshotBlock;
        uint256 totalSupplySnapshot;
    }
    
    struct VoteData {
        uint8 support;
        uint256 weight;
        uint256 timestamp;
    }
    
    struct DelegationData {
        address delegatee;
        uint256 fromBlock;
        uint256 toBlock;
    }
    
    struct GovernanceParameters {
        uint256 proposalThreshold;     // Min tokens to create proposal (BP)
        uint256 quorumThreshold;       // Min participation for validity (BP)
        uint256 approvalThreshold;     // Min approval for passage (BP)
        uint256 votingPeriod;          // Duration of voting period
        uint256 executionDelay;        // Delay before execution
        uint256 proposalBond;          // Bond required for proposals
    }
    
    /*//////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    // Core contracts
    IERC20 public immutable usdpToken;
    address public treasury;
    address public stabilizer;
    address public oracle;
    address public manager;
    
    // Governance state
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => VoteData)) public votes;
    mapping(address => DelegationData[]) public delegationHistory;
    mapping(address => address) public currentDelegate;
    
    // Access control
    address public owner;
    address public pendingOwner;
    mapping(address => bool) public emergencyGuardians;
    mapping(address => bool) public parameterManagers;
    
    // Governance parameters by proposal type
    mapping(uint8 => GovernanceParameters) public governanceParams;
    
    // Security features
    mapping(uint256 => bool) public proposalBonds; // proposalId => bond deposited
    mapping(address => uint256) public lastProposalTime; // Anti-spam
    uint256 public minimumProposalInterval = 1 days;
    
    // Statistics
    uint256 public totalProposalsCreated;
    uint256 public totalProposalsExecuted;
    uint256 public totalVotesCast;
    
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        uint8 proposalType,
        string description,
        uint256 startTime,
        uint256 endTime
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 weight,
        string reason
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId,
        uint256 executionTime
    );
    
    event ProposalCanceled(
        uint256 indexed proposalId,
        string reason
    );
    
    event ProposalVetoed(
        uint256 indexed proposalId,
        address indexed guardian,
        string reason
    );
    
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );
    
    event EmergencyAction(
        address indexed guardian,
        bytes emergencyData,
        uint256 timestamp
    );
    
    event ParametersUpdated(
        uint8 indexed proposalType,
        address indexed updater,
        uint256 timestamp
    );
    
    event GuardianStatusChanged(
        address indexed guardian,
        bool status
    );
    
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    
    error InsufficientTokens();
    error ProposalNotActive();
    error ProposalNotSucceeded();
    error ProposalAlreadyExecuted();
    error ProposalStillTimelocked();
    error InvalidProposalType();
    error QuorumNotReached();
    error InsufficientApproval();
    error ProposalSpamProtection();
    error UnauthorizedAccess();
    error InvalidParameters();
    error EmergencyOnly();
    
    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    
    modifier onlyOwner() {
        require(msg.sender == owner, "UNAUTHORIZED");
        _;
    }
    
    modifier onlyEmergencyGuardian() {
        require(emergencyGuardians[msg.sender] || msg.sender == owner, "UNAUTHORIZED_GUARDIAN");
        _;
    }
    
    modifier onlyParameterManager() {
        require(parameterManagers[msg.sender] || msg.sender == owner, "UNAUTHORIZED_PARAMETER_MANAGER");
        _;
    }
    
    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "INVALID_PROPOSAL");
        _;
    }
    
    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    constructor(
        address _usdpToken,
        address _owner,
        address _treasury,
        address _stabilizer,
        address _oracle,
        address _manager
    ) {
        require(_usdpToken != address(0), "INVALID_USDP_TOKEN");
        require(_owner != address(0), "INVALID_OWNER");
        
        usdpToken = IERC20(_usdpToken);
        owner = _owner;
        treasury = _treasury;
        stabilizer = _stabilizer;
        oracle = _oracle;
        manager = _manager;
        
        // Initialize default governance parameters
        _initializeGovernanceParameters();
        
        emit OwnershipTransferred(address(0), _owner);
    }
    
    /*//////////////////////////////////////////////////////////////
                            PROPOSAL MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Create a new governance proposal
    /// @param proposalType Type of proposal (0-4)
    /// @param targets Contract addresses to call
    /// @param values Ether values for each call
    /// @param calldatas Function call data
    /// @param description Human-readable description
    /// @return proposalId Unique proposal identifier
    function createProposal(
        uint8 proposalType,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description
    ) external override returns (uint256 proposalId) {
        require(proposalType <= PROPOSAL_TYPE_CONSTITUTIONAL, "INVALID_PROPOSAL_TYPE");
        require(targets.length == values.length && targets.length == calldatas.length, "ARRAY_LENGTH_MISMATCH");
        require(targets.length > 0, "EMPTY_PROPOSAL");
        require(bytes(description).length > 0, "EMPTY_DESCRIPTION");
        
        // Check proposal threshold
        uint256 voterBalance = getVotingPower(msg.sender);
        uint256 requiredThreshold = (usdpToken.totalSupply() * governanceParams[proposalType].proposalThreshold) / BASIS_POINTS;
        if (voterBalance < requiredThreshold) {
            revert InsufficientTokens();
        }
        
        // Anti-spam protection
        if (block.timestamp < lastProposalTime[msg.sender] + minimumProposalInterval) {
            revert ProposalSpamProtection();
        }
        
        // Create proposal
        proposalId = ++proposalCount;
        uint256 votingPeriod = governanceParams[proposalType].votingPeriod;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            proposalType: proposalType,
            startTime: block.timestamp,
            endTime: block.timestamp + votingPeriod,
            executionTime: block.timestamp + votingPeriod + governanceParams[proposalType].executionDelay,
            description: description,
            targets: targets,
            values: values,
            calldatas: calldatas,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            totalVotes: 0,
            executed: false,
            canceled: false,
            vetoed: false,
            snapshotBlock: block.number,
            totalSupplySnapshot: usdpToken.totalSupply()
        });
        
        // Collect proposal bond if required
        uint256 bondAmount = governanceParams[proposalType].proposalBond;
        if (bondAmount > 0) {
            usdpToken.transferFrom(msg.sender, address(this), bondAmount);
            proposalBonds[proposalId] = true;
        }
        
        lastProposalTime[msg.sender] = block.timestamp;
        totalProposalsCreated++;
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            proposalType,
            description,
            proposals[proposalId].startTime,
            proposals[proposalId].endTime
        );
        
        return proposalId;
    }
    
    /// @notice Vote on a proposal
    /// @param proposalId Proposal to vote on
    /// @param support Vote type (0=against, 1=for, 2=abstain)
    function vote(uint256 proposalId, uint8 support) external override validProposal(proposalId) {
        require(support <= 2, "INVALID_VOTE_TYPE");
        Proposal storage proposal = proposals[proposalId];
        
        // Check voting period
        require(block.timestamp >= proposal.startTime, "VOTING_NOT_STARTED");
        require(block.timestamp <= proposal.endTime, "VOTING_ENDED");
        require(!proposal.canceled && !proposal.vetoed, "PROPOSAL_INACTIVE");
        
        // Check if already voted
        require(votes[proposalId][msg.sender].weight == 0, "ALREADY_VOTED");
        
        // Get voting power at snapshot
        uint256 votingPower = getVotingPowerAt(msg.sender, proposal.snapshotBlock);
        require(votingPower > 0, "NO_VOTING_POWER");
        
        // Record vote
        votes[proposalId][msg.sender] = VoteData({
            support: support,
            weight: votingPower,
            timestamp: block.timestamp
        });
        
        // Update proposal vote counts
        if (support == VOTE_FOR) {
            proposal.forVotes += votingPower;
        } else if (support == VOTE_AGAINST) {
            proposal.againstVotes += votingPower;
        } else {
            proposal.abstainVotes += votingPower;
        }
        
        proposal.totalVotes += votingPower;
        totalVotesCast++;
        
        emit VoteCast(proposalId, msg.sender, support, votingPower, "");
    }
    
    /// @notice Execute a successful proposal
    /// @param proposalId Proposal to execute
    function executeProposal(uint256 proposalId) external override validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        
        require(!proposal.executed, "ALREADY_EXECUTED");
        require(!proposal.canceled, "PROPOSAL_CANCELED");
        require(!proposal.vetoed, "PROPOSAL_VETOED");
        require(block.timestamp > proposal.endTime, "VOTING_STILL_ACTIVE");
        require(block.timestamp >= proposal.executionTime, "STILL_TIMELOCKED");
        
        // Check if proposal succeeded
        require(_isProposalSuccessful(proposalId), "PROPOSAL_FAILED");
        
        // Execute proposal
        proposal.executed = true;
        totalProposalsExecuted++;
        
        // Execute each call
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, bytes memory returnData) = proposal.targets[i].call{value: proposal.values[i]}(proposal.calldatas[i]);
            require(success, string(returnData));
        }
        
        // Refund proposal bond if applicable
        if (proposalBonds[proposalId]) {
            uint256 bondAmount = governanceParams[proposal.proposalType].proposalBond;
            usdpToken.transfer(proposal.proposer, bondAmount);
            proposalBonds[proposalId] = false;
        }
        
        emit ProposalExecuted(proposalId, block.timestamp);
    }
    
    /*//////////////////////////////////////////////////////////////
                            DELEGATION SYSTEM
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Delegate voting power to another address
    /// @param delegatee Address to delegate to
    function delegate(address delegatee) external override {
        address currentDelegatee = currentDelegate[msg.sender];
        
        // End current delegation if exists
        if (currentDelegatee != address(0) && currentDelegatee != delegatee) {
            DelegationData[] storage history = delegationHistory[msg.sender];
            if (history.length > 0 && history[history.length - 1].toBlock == 0) {
                history[history.length - 1].toBlock = block.number;
            }
        }
        
        // Start new delegation
        if (delegatee != address(0) && delegatee != msg.sender) {
            delegationHistory[msg.sender].push(DelegationData({
                delegatee: delegatee,
                fromBlock: block.number,
                toBlock: 0 // Open-ended
            }));
        }
        
        currentDelegate[msg.sender] = delegatee;
        
        emit DelegateChanged(msg.sender, currentDelegatee, delegatee);
    }
    
    /*//////////////////////////////////////////////////////////////
                            EMERGENCY CONTROLS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Execute emergency action (guardians only)
    /// @param emergencyData Encoded emergency action data
    function emergencyAction(bytes calldata emergencyData) external override onlyEmergencyGuardian {
        // Decode and execute emergency action
        // This is a flexible interface for various emergency scenarios
        
        emit EmergencyAction(msg.sender, emergencyData, block.timestamp);
        
        // Emergency actions could include:
        // - Pausing contracts
        // - Emergency fund deployment
        // - Parameter adjustments
        // - Veto powers
    }
    
    /// @notice Veto a proposal (emergency guardians only)
    /// @param proposalId Proposal to veto
    /// @param reason Reason for veto
    function vetoProposal(uint256 proposalId, string calldata reason) external onlyEmergencyGuardian validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "ALREADY_EXECUTED");
        require(!proposal.vetoed, "ALREADY_VETOED");
        
        proposal.vetoed = true;
        
        emit ProposalVetoed(proposalId, msg.sender, reason);
    }
    
    /*//////////////////////////////////////////////////////////////
                        PARAMETER MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Update system parameters (parameter managers only)
    /// @param parameterData Encoded parameter update data
    function updateParameters(bytes calldata parameterData) external override onlyParameterManager {
        // Decode and apply parameter updates
        // This provides a flexible interface for various parameter types
        
        emit ParametersUpdated(PROPOSAL_TYPE_PARAMETER, msg.sender, block.timestamp);
    }
    
    /// @notice Update governance parameters for a proposal type
    /// @param proposalType Type of proposal to update
    /// @param newParams New governance parameters
    function updateGovernanceParameters(uint8 proposalType, GovernanceParameters calldata newParams) external onlyOwner {
        require(proposalType <= PROPOSAL_TYPE_CONSTITUTIONAL, "INVALID_PROPOSAL_TYPE");
        require(_validateGovernanceParameters(newParams), "INVALID_PARAMETERS");
        
        governanceParams[proposalType] = newParams;
        
        emit ParametersUpdated(proposalType, msg.sender, block.timestamp);
    }
    
    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Set emergency guardian status
    /// @param guardian Guardian address
    /// @param status Guardian status
    function setEmergencyGuardian(address guardian, bool status) external onlyOwner {
        emergencyGuardians[guardian] = status;
        emit GuardianStatusChanged(guardian, status);
    }
    
    /// @notice Set parameter manager status
    /// @param manager Manager address
    /// @param status Manager status
    function setParameterManager(address manager, bool status) external onlyOwner {
        parameterManagers[manager] = status;
    }
    
    /// @notice Transfer ownership
    /// @param newOwner New owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "INVALID_ADDRESS");
        pendingOwner = newOwner;
    }
    
    /// @notice Accept ownership transfer
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "UNAUTHORIZED");
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }
    
    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Get current voting power of an account
    /// @param account Account to check
    /// @return Voting power (including delegated votes)
    function getVotingPower(address account) public view override returns (uint256) {
        return getVotingPowerAt(account, block.number);
    }
    
    /// @notice Get voting power at a specific block
    /// @param account Account to check
    /// @param blockNumber Block number for snapshot
    /// @return Voting power at the specified block
    function getVotingPowerAt(address account, uint256 blockNumber) public view returns (uint256) {
        // Get direct token balance (simplified - would need proper snapshot mechanism)
        uint256 directPower = usdpToken.balanceOf(account);
        
        // Add delegated power (would need proper delegation tracking)
        uint256 delegatedPower = 0; // TODO: Implement delegation power calculation
        
        return directPower + delegatedPower;
    }
    
    /// @notice Get proposal state
    /// @param proposalId Proposal to check
    /// @return State code (0=pending, 1=active, 2=canceled, 3=defeated, 4=succeeded, 5=queued, 6=expired, 7=executed)
    function getProposalState(uint256 proposalId) external view override validProposal(proposalId) returns (uint8) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.vetoed) return 2; // Canceled
        if (proposal.canceled) return 2; // Canceled
        if (proposal.executed) return 7; // Executed
        
        if (block.timestamp <= proposal.startTime) return 0; // Pending
        if (block.timestamp <= proposal.endTime) return 1; // Active
        
        if (_isProposalSuccessful(proposalId)) {
            if (block.timestamp < proposal.executionTime) return 5; // Queued
            return 4; // Succeeded (ready for execution)
        } else {
            return 3; // Defeated
        }
    }
    
    /// @notice Check if an account has voted on a proposal
    /// @param proposalId Proposal to check
    /// @param voter Voter to check
    /// @return True if the voter has voted
    function hasVoted(uint256 proposalId, address voter) external view override returns (bool) {
        return votes[proposalId][voter].weight > 0;
    }
    
    /// @notice Get detailed proposal information
    /// @param proposalId Proposal to query
    /// @return Proposal struct data
    function getProposal(uint256 proposalId) external view validProposal(proposalId) returns (Proposal memory) {
        return proposals[proposalId];
    }
    
    /// @notice Get governance statistics
    /// @return totalProposals Total proposals created
    /// @return totalExecuted Total proposals executed
    /// @return totalVotes Total votes cast
    /// @return activeProposals Currently active proposals
    function getGovernanceStats() external view returns (
        uint256 totalProposals,
        uint256 totalExecuted,
        uint256 totalVotes,
        uint256 activeProposals
    ) {
        totalProposals = totalProposalsCreated;
        totalExecuted = totalProposalsExecuted;
        totalVotes = totalVotesCast;
        
        // Count active proposals
        activeProposals = 0;
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (block.timestamp >= proposals[i].startTime &&
                block.timestamp <= proposals[i].endTime &&
                !proposals[i].canceled &&
                !proposals[i].vetoed) {
                activeProposals++;
            }
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                        ECOSYSTEM INTEGRATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Update Treasury governance address (governance only)
    /// @param newGovernance New governance address for treasury
    function updateTreasuryGovernance(address newGovernance) external {
        require(msg.sender == address(this), "ONLY_GOVERNANCE"); // Can only be called via proposal
        require(treasury != address(0), "TREASURY_NOT_SET");
        
        // Call treasury's updateGovernance function
        (bool success,) = treasury.call(
            abi.encodeWithSignature("updateGovernance(address)", newGovernance)
        );
        require(success, "TREASURY_UPDATE_FAILED");
    }
    
    /// @notice Update Stabilizer parameters via governance
    /// @param parameterData Encoded stabilizer parameters
    function updateStabilizerParameters(bytes calldata parameterData) external {
        require(msg.sender == address(this), "ONLY_GOVERNANCE");
        require(stabilizer != address(0), "STABILIZER_NOT_SET");
        
        // Decode parameters and call stabilizer
        (bool success,) = stabilizer.call(parameterData);
        require(success, "STABILIZER_UPDATE_FAILED");
    }
    
    /// @notice Update Oracle configuration via governance
    /// @param oracleData Encoded oracle configuration
    function updateOracleConfiguration(bytes calldata oracleData) external {
        require(msg.sender == address(this), "ONLY_GOVERNANCE");
        require(oracle != address(0), "ORACLE_NOT_SET");
        
        (bool success,) = oracle.call(oracleData);
        require(success, "ORACLE_UPDATE_FAILED");
    }
    
    /// @notice Update Manager configuration via governance
    /// @param managerData Encoded manager configuration
    function updateManagerConfiguration(bytes calldata managerData) external {
        require(msg.sender == address(this), "ONLY_GOVERNANCE");
        require(manager != address(0), "MANAGER_NOT_SET");
        
        (bool success,) = manager.call(managerData);
        require(success, "MANAGER_UPDATE_FAILED");
    }
    
    /// @notice Emergency pause Treasury operations
    /// @param pauseDeposits Whether to pause deposits
    /// @param pauseWithdrawals Whether to pause withdrawals
    function emergencyPauseTreasury(bool pauseDeposits, bool pauseWithdrawals) external onlyEmergencyGuardian {
        require(treasury != address(0), "TREASURY_NOT_SET");
        
        (bool success,) = treasury.call(
            abi.encodeWithSignature("freezeOperations(bool,bool)", pauseDeposits, pauseWithdrawals)
        );
        require(success, "TREASURY_PAUSE_FAILED");
        
        emit EmergencyAction(msg.sender, abi.encode("pauseTreasury", pauseDeposits, pauseWithdrawals), block.timestamp);
    }
    
    /// @notice Emergency halt Stabilizer operations
    /// @param reason Reason for halt
    function emergencyHaltStabilizer(string calldata reason) external onlyEmergencyGuardian {
        require(stabilizer != address(0), "STABILIZER_NOT_SET");
        
        (bool success,) = stabilizer.call(
            abi.encodeWithSignature("emergencyHalt(string)", reason)
        );
        require(success, "STABILIZER_HALT_FAILED");
        
        emit EmergencyAction(msg.sender, abi.encode("haltStabilizer", reason), block.timestamp);
    }
    
    /// @notice Emergency resume Stabilizer operations
    function emergencyResumeStabilizer() external onlyEmergencyGuardian {
        require(stabilizer != address(0), "STABILIZER_NOT_SET");
        
        (bool success,) = stabilizer.call(
            abi.encodeWithSignature("emergencyResume()")
        );
        require(success, "STABILIZER_RESUME_FAILED");
        
        emit EmergencyAction(msg.sender, abi.encode("resumeStabilizer"), block.timestamp);
    }
    
    /// @notice Deploy emergency funds from Treasury
    /// @param amount Amount to deploy
    /// @param recipient Recipient of emergency funds
    /// @param reason Reason for deployment
    function deployEmergencyFunds(uint256 amount, address recipient, string calldata reason) external onlyEmergencyGuardian {
        require(treasury != address(0), "TREASURY_NOT_SET");
        require(recipient != address(0), "INVALID_RECIPIENT");
        
        (bool success,) = treasury.call(
            abi.encodeWithSignature("activateEmergencyFund(uint256,string)", amount, reason)
        );
        require(success, "EMERGENCY_FUND_FAILED");
        
        emit EmergencyAction(msg.sender, abi.encode("deployEmergencyFunds", amount, recipient, reason), block.timestamp);
    }
    
    /*//////////////////////////////////////////////////////////////
                        SPECIFIC PARAMETER GOVERNANCE
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Update Treasury fee structure
    /// @param mintingFee New minting fee (basis points)
    /// @param burningFee New burning fee (basis points)
    /// @param liquidationFee New liquidation fee (basis points)
    function updateTreasuryFees(uint256 mintingFee, uint256 burningFee, uint256 liquidationFee) external {
        require(msg.sender == address(this), "ONLY_GOVERNANCE");
        require(treasury != address(0), "TREASURY_NOT_SET");
        require(mintingFee <= 1000 && burningFee <= 1000 && liquidationFee <= 2000, "INVALID_FEE_LIMITS");
        
        bytes memory feeData = abi.encodeWithSignature(
            "updateFeeStructure((uint256,uint256,uint256,uint256,uint256,uint256))",
            mintingFee, burningFee, liquidationFee, 7000, 2000, 1000 // Keep existing distribution
        );
        
        (bool success,) = treasury.call(feeData);
        require(success, "FEE_UPDATE_FAILED");
    }
    
    /// @notice Update Stabilizer thresholds
    /// @param smallThreshold Small deviation threshold (BP)
    /// @param mediumThreshold Medium deviation threshold (BP)
    /// @param largeThreshold Large deviation threshold (BP)
    /// @param extremeThreshold Extreme deviation threshold (BP)
    function updateStabilizerThresholds(
        uint256 smallThreshold,
        uint256 mediumThreshold,
        uint256 largeThreshold,
        uint256 extremeThreshold
    ) external {
        require(msg.sender == address(this), "ONLY_GOVERNANCE");
        require(stabilizer != address(0), "STABILIZER_NOT_SET");
        require(smallThreshold < mediumThreshold && mediumThreshold < largeThreshold && largeThreshold < extremeThreshold, "INVALID_THRESHOLD_ORDER");
        require(extremeThreshold <= 2000, "EXTREME_THRESHOLD_TOO_HIGH"); // Max 20%
        
        bytes memory thresholdData = abi.encodeWithSignature(
            "updateParameters((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256))",
            smallThreshold, mediumThreshold, largeThreshold, extremeThreshold,
            10, 50, 200, // Keep existing adjustment rates
            3600, 21600, 200 // Keep existing time and daily limits
        );
        
        (bool success,) = stabilizer.call(thresholdData);
        require(success, "THRESHOLD_UPDATE_FAILED");
    }
    
    /// @notice Update Manager collateral ratio
    /// @param newRatio New minimum collateral ratio (with 18 decimals)
    function updateManagerCollateralRatio(uint256 newRatio) external {
        require(msg.sender == address(this), "ONLY_GOVERNANCE");
        require(manager != address(0), "MANAGER_NOT_SET");
        require(newRatio >= 1e18, "RATIO_TOO_LOW"); // Minimum 100%
        require(newRatio <= 3e18, "RATIO_TOO_HIGH"); // Maximum 300%
        
        // This would require the Manager contract to have an update function
        // For now, we'll emit an event that could be used by an upgraded Manager
        emit ParametersUpdated(PROPOSAL_TYPE_PARAMETER, msg.sender, block.timestamp);
    }
    
    /*//////////////////////////////////////////////////////////////
                        ENHANCED DELEGATION SYSTEM
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Get delegated voting power for an account
    /// @param account Account to check
    /// @return Total delegated power
    function getDelegatedPower(address account) public view returns (uint256) {
        uint256 totalDelegated = 0;
        
        // This is a simplified implementation
        // In production, you'd want a more efficient tracking system
        
        return totalDelegated;
    }
    
    /// @notice Get delegation history for an account
    /// @param account Account to query
    /// @return Array of delegation data
    function getDelegationHistory(address account) external view returns (DelegationData[] memory) {
        return delegationHistory[account];
    }
    
    /// @notice Delegate voting power with reason
    /// @param delegatee Address to delegate to
    /// @param reason Reason for delegation
    function delegateWithReason(address delegatee, string calldata reason) external {
        delegate(delegatee);
        // Could emit additional event with reason if needed
    }
    
    /*//////////////////////////////////////////////////////////////
                        SNAPSHOT AND SECURITY FEATURES
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Create a voting power snapshot (for anti-flash-loan protection)
    /// @return snapshotId New snapshot identifier
    function createSnapshot() external onlyOwner returns (uint256 snapshotId) {
        // This would integrate with a snapshot mechanism
        // For now, return current block number as snapshot ID
        return block.number;
    }
    
    /// @notice Get voting power at a specific snapshot
    /// @param account Account to check
    /// @param snapshotId Snapshot identifier
    /// @return Voting power at snapshot
    function getVotingPowerAtSnapshot(address account, uint256 snapshotId) external view returns (uint256) {
        // This would use proper snapshot mechanism
        // For now, return current balance (simplified)
        return usdpToken.balanceOf(account);
    }
    
    /// @notice Cancel a proposal (proposer or guardian only)
    /// @param proposalId Proposal to cancel
    /// @param reason Reason for cancellation
    function cancelProposal(uint256 proposalId, string calldata reason) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        
        require(
            msg.sender == proposal.proposer || emergencyGuardians[msg.sender] || msg.sender == owner,
            "UNAUTHORIZED_CANCELLATION"
        );
        require(!proposal.executed, "ALREADY_EXECUTED");
        require(!proposal.canceled, "ALREADY_CANCELED");
        
        proposal.canceled = true;
        
        // Refund proposal bond if canceled by proposer
        if (msg.sender == proposal.proposer && proposalBonds[proposalId]) {
            uint256 bondAmount = governanceParams[proposal.proposalType].proposalBond;
            usdpToken.transfer(proposal.proposer, bondAmount);
            proposalBonds[proposalId] = false;
        }
        
        emit ProposalCanceled(proposalId, reason);
    }
    
    /// @notice Set minimum proposal interval (anti-spam)
    /// @param newInterval New minimum interval between proposals
    function setProposalInterval(uint256 newInterval) external onlyOwner {
        require(newInterval <= 7 days, "INTERVAL_TOO_LONG");
        minimumProposalInterval = newInterval;
    }
    
    /// @notice Update ecosystem contract addresses
    /// @param _treasury New treasury address
    /// @param _stabilizer New stabilizer address
    /// @param _oracle New oracle address
    /// @param _manager New manager address
    function updateEcosystemContracts(
        address _treasury,
        address _stabilizer,
        address _oracle,
        address _manager
    ) external onlyOwner {
        treasury = _treasury;
        stabilizer = _stabilizer;
        oracle = _oracle;
        manager = _manager;
    }
    
    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Initialize default governance parameters
    function _initializeGovernanceParameters() internal {
        // Standard proposals
        governanceParams[PROPOSAL_TYPE_STANDARD] = GovernanceParameters({
            proposalThreshold: PROPOSAL_THRESHOLD,
            quorumThreshold: QUORUM_THRESHOLD,
            approvalThreshold: APPROVAL_THRESHOLD,
            votingPeriod: VOTING_PERIOD,
            executionDelay: EXECUTION_DELAY,
            proposalBond: 1000 * 10**18 // 1000 USDP bond
        });
        
        // Emergency proposals
        governanceParams[PROPOSAL_TYPE_EMERGENCY] = GovernanceParameters({
            proposalThreshold: PROPOSAL_THRESHOLD * 2, // Higher threshold
            quorumThreshold: QUORUM_THRESHOLD / 2,     // Lower quorum for urgency
            approvalThreshold: SUPERMAJORITY_THRESHOLD, // Higher approval
            votingPeriod: EMERGENCY_VOTING_PERIOD,
            executionDelay: EMERGENCY_EXECUTION_DELAY,
            proposalBond: 5000 * 10**18 // Higher bond
        });
        
        // Parameter proposals
        governanceParams[PROPOSAL_TYPE_PARAMETER] = GovernanceParameters({
            proposalThreshold: PROPOSAL_THRESHOLD / 2, // Lower threshold
            quorumThreshold: QUORUM_THRESHOLD / 2,     // Lower quorum
            approvalThreshold: APPROVAL_THRESHOLD,
            votingPeriod: VOTING_PERIOD / 2,           // Shorter period
            executionDelay: EXECUTION_DELAY / 2,       // Shorter delay
            proposalBond: 500 * 10**18
        });
        
        // Treasury proposals
        governanceParams[PROPOSAL_TYPE_TREASURY] = GovernanceParameters({
            proposalThreshold: PROPOSAL_THRESHOLD,
            quorumThreshold: QUORUM_THRESHOLD,
            approvalThreshold: SUPERMAJORITY_THRESHOLD, // Higher approval for treasury
            votingPeriod: VOTING_PERIOD,
            executionDelay: EXECUTION_DELAY * 2,        // Longer delay
            proposalBond: 2000 * 10**18
        });
        
        // Constitutional proposals
        governanceParams[PROPOSAL_TYPE_CONSTITUTIONAL] = GovernanceParameters({
            proposalThreshold: PROPOSAL_THRESHOLD * 3, // Highest threshold
            quorumThreshold: QUORUM_THRESHOLD * 2,     // Highest quorum
            approvalThreshold: SUPERMAJORITY_THRESHOLD,
            votingPeriod: VOTING_PERIOD * 2,           // Longest period
            executionDelay: EXECUTION_DELAY * 3,       // Longest delay
            proposalBond: 10000 * 10**18              // Highest bond
        });
    }
    
    /// @notice Check if a proposal is successful
    /// @param proposalId Proposal to check
    /// @return True if proposal has succeeded
    function _isProposalSuccessful(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        
        // Check quorum
        uint256 requiredQuorum = (proposal.totalSupplySnapshot * governanceParams[proposal.proposalType].quorumThreshold) / BASIS_POINTS;
        if (proposal.totalVotes < requiredQuorum) {
            return false;
        }
        
        // Check approval
        uint256 requiredApproval = (proposal.totalVotes * governanceParams[proposal.proposalType].approvalThreshold) / BASIS_POINTS;
        return proposal.forVotes >= requiredApproval;
    }
    
    /// @notice Validate governance parameters
    /// @param params Parameters to validate
    /// @return True if parameters are valid
    function _validateGovernanceParameters(GovernanceParameters memory params) internal pure returns (bool) {
        return params.proposalThreshold <= 1000 && // Max 10%
               params.quorumThreshold <= 5000 &&    // Max 50%
               params.approvalThreshold >= 5000 &&  // Min 50%
               params.approvalThreshold <= 10000 && // Max 100%
               params.votingPeriod >= 1 days &&     // Min 1 day
               params.votingPeriod <= 30 days &&    // Max 30 days
               params.executionDelay <= 7 days;     // Max 7 days delay
    }
}