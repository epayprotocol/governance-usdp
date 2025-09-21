# USDP Governance

- Primary contract file: [USDPGovernance.sol](USDPGovernance.sol)

## Overview
- [contract USDPGovernance()](USDPGovernance.sol:35) implements [interface IUSDPGovernance()](USDPGovernance.sol:8) to provide token-based governance with proposal creation, voting, batched execution with timelocks, emergency controls, parameter management, and delegation/snapshot scaffolding.
- Voting power is derived from USDP ERC20 balances via import at [USDPGovernance.sol](USDPGovernance.sol:4), using [function getVotingPower()](USDPGovernance.sol:580) and [function getVotingPowerAt()](USDPGovernance.sol:588) which reads [IERC20 usdpToken()](USDPGovernance.sol:127) balance at [USDPGovernance.sol](USDPGovernance.sol:590).
- Per-proposal-type governance parameters held in [mapping governanceParams()](USDPGovernance.sol:147) and initialized by [function _initializeGovernanceParameters()](USDPGovernance.sol:933).
- Proposals are executed through [function executeProposal()](USDPGovernance.sol:419) after the per-proposal timelock captured as [uint256 executionTime()](USDPGovernance.sol:77) and enforced at [USDPGovernance.sol](USDPGovernance.sol:426).
- Emergency guardians can take direct actions via [function emergencyAction()](USDPGovernance.sol:488) and veto proposals via [function vetoProposal()](USDPGovernance.sol:504), gated by [modifier onlyEmergencyGuardian()](USDPGovernance.sol:250).
- Core ecosystem references: [IERC20 usdpToken()](USDPGovernance.sol:127), [address treasury()](USDPGovernance.sol:128), [address stabilizer()](USDPGovernance.sol:129), [address oracle()](USDPGovernance.sol:130), [address manager()](USDPGovernance.sol:131).

## Inheritance and dependencies
- Implements [interface IUSDPGovernance()](USDPGovernance.sol:8) which declares:
  - [function createProposal()](USDPGovernance.sol:10)
  - [function vote()](USDPGovernance.sol:18)
  - [function delegate()](USDPGovernance.sol:19)
  - [function executeProposal()](USDPGovernance.sol:20)
  - [function emergencyAction()](USDPGovernance.sol:23)
  - [function updateParameters()](USDPGovernance.sol:24)
  - [function getVotingPower()](USDPGovernance.sol:27)
  - [function getProposalState()](USDPGovernance.sol:28)
  - [function hasVoted()](USDPGovernance.sol:29)
- External dependency import: [USDPGovernance.sol](USDPGovernance.sol:4).

## Storage layout (selected)
- Constants and configuration:
  - [uint256 BASIS_POINTS()](USDPGovernance.sol:40), [uint256 DECIMALS()](USDPGovernance.sol:41)
  - [uint256 PROPOSAL_THRESHOLD()](USDPGovernance.sol:44), [uint256 QUORUM_THRESHOLD()](USDPGovernance.sol:45), [uint256 APPROVAL_THRESHOLD()](USDPGovernance.sol:46), [uint256 SUPERMAJORITY_THRESHOLD()](USDPGovernance.sol:47)
  - [uint256 VOTING_PERIOD()](USDPGovernance.sol:50), [uint256 EMERGENCY_VOTING_PERIOD()](USDPGovernance.sol:51), [uint256 EXECUTION_DELAY()](USDPGovernance.sol:52), [uint256 EMERGENCY_EXECUTION_DELAY()](USDPGovernance.sol:53)
- Proposal type constants: [uint8 PROPOSAL_TYPE_STANDARD()](USDPGovernance.sol:56), [uint8 PROPOSAL_TYPE_EMERGENCY()](USDPGovernance.sol:57), [uint8 PROPOSAL_TYPE_PARAMETER()](USDPGovernance.sol:58), [uint8 PROPOSAL_TYPE_TREASURY()](USDPGovernance.sol:59), [uint8 PROPOSAL_TYPE_CONSTITUTIONAL()](USDPGovernance.sol:60).
- Vote type constants: [uint8 VOTE_AGAINST()](USDPGovernance.sol:63), [uint8 VOTE_FOR()](USDPGovernance.sol:64), [uint8 VOTE_ABSTAIN()](USDPGovernance.sol:65).
- Structs: [struct Proposal()](USDPGovernance.sol:71), [struct VoteData()](USDPGovernance.sol:101), [struct DelegationData()](USDPGovernance.sol:107), [struct GovernanceParameters()](USDPGovernance.sol:113).
- Core references: [IERC20 usdpToken()](USDPGovernance.sol:127), [address treasury()](USDPGovernance.sol:128), [address stabilizer()](USDPGovernance.sol:129), [address oracle()](USDPGovernance.sol:130), [address manager()](USDPGovernance.sol:131).
- Governance state: [uint256 proposalCount()](USDPGovernance.sol:134), [mapping proposals()](USDPGovernance.sol:135), [mapping votes()](USDPGovernance.sol:136), [mapping delegationHistory()](USDPGovernance.sol:137), [mapping currentDelegate()](USDPGovernance.sol:138).
- Access control: [address owner()](USDPGovernance.sol:141), [address pendingOwner()](USDPGovernance.sol:142), [mapping emergencyGuardians()](USDPGovernance.sol:143), [mapping parameterManagers()](USDPGovernance.sol:144).
- Per-type parameters: [mapping governanceParams()](USDPGovernance.sol:147).
- Anti-spam and bonds: [mapping proposalBonds()](USDPGovernance.sol:150), [mapping lastProposalTime()](USDPGovernance.sol:151), [uint256 minimumProposalInterval()](USDPGovernance.sol:152).
- Statistics: [uint256 totalProposalsCreated()](USDPGovernance.sol:155), [uint256 totalProposalsExecuted()](USDPGovernance.sol:156), [uint256 totalVotesCast()](USDPGovernance.sol:157).

## Roles, permissions, and access control
- [modifier onlyOwner()](USDPGovernance.sol:245) gates: [function setEmergencyGuardian()](USDPGovernance.sol:546), [function setParameterManager()](USDPGovernance.sol:554), [function transferOwnership()](USDPGovernance.sol:560), [function setProposalInterval()](USDPGovernance.sol:906), [function updateEcosystemContracts()](USDPGovernance.sol:916), [function updateGovernanceParameters()](USDPGovernance.sol:530), [function createSnapshot()](USDPGovernance.sol:863).
- [modifier onlyEmergencyGuardian()](USDPGovernance.sol:250) gates: [function emergencyAction()](USDPGovernance.sol:488), [function vetoProposal()](USDPGovernance.sol:504), [function emergencyPauseTreasury()](USDPGovernance.sol:712), [function emergencyHaltStabilizer()](USDPGovernance.sol:725), [function emergencyResumeStabilizer()](USDPGovernance.sol:737), [function deployEmergencyFunds()](USDPGovernance.sol:752).
- [modifier onlyParameterManager()](USDPGovernance.sol:255) gates: [function updateParameters()](USDPGovernance.sol:520).
- Governance-only (via proposals) enforced by require(msg.sender == address(this)) at:
  - [function updateTreasuryGovernance()](USDPGovernance.sol:667) — [USDPGovernance.sol](USDPGovernance.sol:668)
  - [function updateStabilizerParameters()](USDPGovernance.sol:680) — [USDPGovernance.sol](USDPGovernance.sol:681)
  - [function updateOracleConfiguration()](USDPGovernance.sol:691) — [USDPGovernance.sol](USDPGovernance.sol:692)
  - [function updateManagerConfiguration()](USDPGovernance.sol:701) — [USDPGovernance.sol](USDPGovernance.sol:702)
  - [function updateTreasuryFees()](USDPGovernance.sol:772) — [USDPGovernance.sol](USDPGovernance.sol:773)
  - [function updateStabilizerThresholds()](USDPGovernance.sol:791) — [USDPGovernance.sol](USDPGovernance.sol:797)
  - [function updateManagerCollateralRatio()](USDPGovernance.sol:815) — [USDPGovernance.sol](USDPGovernance.sol:816)
- [modifier validProposal()](USDPGovernance.sol:260) is applied to: [function vote()](USDPGovernance.sol:379), [function executeProposal()](USDPGovernance.sol:419), [function cancelProposal()](USDPGovernance.sol:882), [function getProposalState()](USDPGovernance.sol:601).

## Events, errors, modifiers
- Events:
  - [event ProposalCreated()](USDPGovernance.sol:163)
  - [event VoteCast()](USDPGovernance.sol:172)
  - [event ProposalExecuted()](USDPGovernance.sol:180)
  - [event ProposalCanceled()](USDPGovernance.sol:185)
  - [event ProposalVetoed()](USDPGovernance.sol:190)
  - [event DelegateChanged()](USDPGovernance.sol:196)
  - [event EmergencyAction()](USDPGovernance.sol:202)
  - [event ParametersUpdated()](USDPGovernance.sol:208)
  - [event GuardianStatusChanged()](USDPGovernance.sol:214)
  - [event OwnershipTransferred()](USDPGovernance.sol:219)
- Errors:
  - [error InsufficientTokens()](USDPGovernance.sol:228), [error ProposalNotActive()](USDPGovernance.sol:229), [error ProposalNotSucceeded()](USDPGovernance.sol:230), [error ProposalAlreadyExecuted()](USDPGovernance.sol:231), [error ProposalStillTimelocked()](USDPGovernance.sol:232), [error InvalidProposalType()](USDPGovernance.sol:233), [error QuorumNotReached()](USDPGovernance.sol:234), [error InsufficientApproval()](USDPGovernance.sol:235), [error ProposalSpamProtection()](USDPGovernance.sol:236), [error UnauthorizedAccess()](USDPGovernance.sol:237), [error InvalidParameters()](USDPGovernance.sol:238), [error EmergencyOnly()](USDPGovernance.sol:240).
- Modifiers: [modifier onlyOwner()](USDPGovernance.sol:245), [modifier onlyEmergencyGuardian()](USDPGovernance.sol:250), [modifier onlyParameterManager()](USDPGovernance.sol:255), [modifier validProposal()](USDPGovernance.sol:260).

## Functions (grouped)
- Initialization and admin:
  - [constructor()](USDPGovernance.sol:269)
  - [function transferOwnership()](USDPGovernance.sol:560), [function acceptOwnership()](USDPGovernance.sol:566)
  - [function setEmergencyGuardian()](USDPGovernance.sol:546), [function setParameterManager()](USDPGovernance.sol:554)
  - [function updateEcosystemContracts()](USDPGovernance.sol:916)
  - [function setProposalInterval()](USDPGovernance.sol:906)
- Proposal lifecycle:
  - [function createProposal()](USDPGovernance.sol:304)
  - [function vote()](USDPGovernance.sol:379)
  - [function executeProposal()](USDPGovernance.sol:419)
  - [function cancelProposal()](USDPGovernance.sol:882)
  - [function vetoProposal()](USDPGovernance.sol:504)
- Voting power, snapshots, delegation:
  - [function getVotingPower()](USDPGovernance.sol:580), [function getVotingPowerAt()](USDPGovernance.sol:588)
  - [function delegate()](USDPGovernance.sol:457), [function delegateWithReason()](USDPGovernance.sol:852)
  - [function getDelegatedPower()](USDPGovernance.sol:833), [function getDelegationHistory()](USDPGovernance.sol:845)
  - [function createSnapshot()](USDPGovernance.sol:863), [function getVotingPowerAtSnapshot()](USDPGovernance.sol:873)
- Parameter management:
  - [function updateParameters()](USDPGovernance.sol:520), [function updateGovernanceParameters()](USDPGovernance.sol:530)
  - [function _validateGovernanceParameters()](USDPGovernance.sol:1005)
- Governance-executed ecosystem updates:
  - [function updateTreasuryGovernance()](USDPGovernance.sol:667)
  - [function updateStabilizerParameters()](USDPGovernance.sol:680)
  - [function updateOracleConfiguration()](USDPGovernance.sol:691)
  - [function updateManagerConfiguration()](USDPGovernance.sol:701)
  - [function updateTreasuryFees()](USDPGovernance.sol:772)
  - [function updateStabilizerThresholds()](USDPGovernance.sol:791)
  - [function updateManagerCollateralRatio()](USDPGovernance.sol:815)
- Emergency controls:
  - [function emergencyAction()](USDPGovernance.sol:488)
  - [function emergencyPauseTreasury()](USDPGovernance.sol:712), [function emergencyHaltStabilizer()](USDPGovernance.sol:725), [function emergencyResumeStabilizer()](USDPGovernance.sol:737), [function deployEmergencyFunds()](USDPGovernance.sol:752)
- Views and getters:
  - [function getProposalState()](USDPGovernance.sol:601), [function hasVoted()](USDPGovernance.sol:623), [function getProposal()](USDPGovernance.sol:630), [function getGovernanceStats()](USDPGovernance.sol:639)

## Governance parameters and lifecycle
- Per-type defaults initialized in [function _initializeGovernanceParameters()](USDPGovernance.sol:933) for: [uint8 PROPOSAL_TYPE_STANDARD()](USDPGovernance.sol:56), [uint8 PROPOSAL_TYPE_EMERGENCY()](USDPGovernance.sol:57), [uint8 PROPOSAL_TYPE_PARAMETER()](USDPGovernance.sol:58), [uint8 PROPOSAL_TYPE_TREASURY()](USDPGovernance.sol:59), [uint8 PROPOSAL_TYPE_CONSTITUTIONAL()](USDPGovernance.sol:60).
- Success criteria enforced by [function _isProposalSuccessful()](USDPGovernance.sol:988): quorum check at [USDPGovernance.sol](USDPGovernance.sol:992) and approval threshold at [USDPGovernance.sol](USDPGovernance.sol:998), using [mapping governanceParams()](USDPGovernance.sol:147) and proposal snapshots.
- Proposal state semantics computed by [function getProposalState()](USDPGovernance.sol:601): vetoed/canceled → 2 [USDPGovernance.sol](USDPGovernance.sol:604)–[USDPGovernance.sol](USDPGovernance.sol:605), executed → 7 [USDPGovernance.sol](USDPGovernance.sol:606), pending → 0 [USDPGovernance.sol](USDPGovernance.sol:608), active → 1 [USDPGovernance.sol](USDPGovernance.sol:609), queued until execution time → 5 [USDPGovernance.sol](USDPGovernance.sol:612), otherwise defeated → 3 [USDPGovernance.sol](USDPGovernance.sol:615).
- Timelock is per-proposal via [uint256 executionTime()](USDPGovernance.sol:77) set at creation and enforced in [function executeProposal()](USDPGovernance.sol:419) at [USDPGovernance.sol](USDPGovernance.sol:426).

## Initialization and deployment notes
- [constructor()](USDPGovernance.sol:269) arguments: _usdpToken, _owner, _treasury, _stabilizer, _oracle, _manager. Preconditions: nonzero checks at [USDPGovernance.sol](USDPGovernance.sol:277)–[USDPGovernance.sol](USDPGovernance.sol:279); state assignments at [USDPGovernance.sol](USDPGovernance.sol:280)–[USDPGovernance.sol](USDPGovernance.sol:285); default parameter initialization via [function _initializeGovernanceParameters()](USDPGovernance.sol:933); emits [event OwnershipTransferred()](USDPGovernance.sol:219) at [USDPGovernance.sol](USDPGovernance.sol:290).

## Security considerations and invariants
- Snapshot and delegation scaffolding:
  - Proposal snapshots recorded in [struct Proposal()](USDPGovernance.sol:71) fields [uint256 snapshotBlock()](USDPGovernance.sol:97) and [uint256 totalSupplySnapshot()](USDPGovernance.sol:99) set at creation [USDPGovernance.sol](USDPGovernance.sol:350)–[USDPGovernance.sol](USDPGovernance.sol:352); votes use snapshot via [function vote()](USDPGovernance.sol:379) calling [function getVotingPowerAt()](USDPGovernance.sol:588) with the snapshot block [USDPGovernance.sol](USDPGovernance.sol:392).
  - Delegated power placeholder: [function getVotingPowerAt()](USDPGovernance.sol:588) sets delegatedPower = 0 at [USDPGovernance.sol](USDPGovernance.sol:593); [function getDelegatedPower()](USDPGovernance.sol:833) returns 0.
  - Snapshot helpers: [function createSnapshot()](USDPGovernance.sol:863) returns block.number; [function getVotingPowerAtSnapshot()](USDPGovernance.sol:873) reads current balance.
- Proposal bonds and anti-spam:
  - Bond deposit on creation at [USDPGovernance.sol](USDPGovernance.sol:355)–[USDPGovernance.sol](USDPGovernance.sol:359) tracked by [mapping proposalBonds()](USDPGovernance.sol:150).
  - Bond refund on successful execution at [USDPGovernance.sol](USDPGovernance.sol:442)–[USDPGovernance.sol](USDPGovernance.sol:446); refund on proposer cancel at [USDPGovernance.sol](USDPGovernance.sol:895)–[USDPGovernance.sol](USDPGovernance.sol:899).
  - Anti-spam interval enforced at [USDPGovernance.sol](USDPGovernance.sol:324)–[USDPGovernance.sol](USDPGovernance.sol:326) using [mapping lastProposalTime()](USDPGovernance.sol:151) and [uint256 minimumProposalInterval()](USDPGovernance.sol:152); configurable via [function setProposalInterval()](USDPGovernance.sol:906).
- Execution and failure handling:
  - Batched execution requires each low-level call to succeed at [USDPGovernance.sol](USDPGovernance.sol:438) in [function executeProposal()](USDPGovernance.sol:419).
  - Execution only after voting ended and timelock elapsed [USDPGovernance.sol](USDPGovernance.sol:425)–[USDPGovernance.sol](USDPGovernance.sol:427).
- Governance-only actions must be invoked through proposals, enforced at the require sites listed in Roles.

## Gas/operational considerations
- [function getGovernanceStats()](USDPGovernance.sol:639) counts active proposals by iterating [USDPGovernance.sol](USDPGovernance.sol:651)–[USDPGovernance.sol](USDPGovernance.sol:659) — O(proposalCount).
- [function executeProposal()](USDPGovernance.sol:419) executes a batch of calls — O(number of calls).
- Counters update on lifecycle: created [USDPGovernance.sol](USDPGovernance.sol:362), executed [USDPGovernance.sol](USDPGovernance.sol:433), vote cast [USDPGovernance.sol](USDPGovernance.sol:412).