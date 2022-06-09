//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MADAO {
    enum Status {
        InProcess,
        Finished,
        Rejected,
        Cancelled
    }

    struct Proposal {
        uint8 status;
        uint64 startDate; //it's ok until (Jul 21 2554)
        address recipient;
        uint128 votesFor;
        uint128 votesAgainst;
        bytes funcSignature;
        string description;
    }

    uint64 private _minimumQuorum;
    uint24 private _votingPeriodDuration; //~6 months max
    address private _voteToken;
    address private _chairperson;
    uint32 private _proposalCounter = 1; //0 is reserved for _lastVoting logic
    mapping(uint256 => Proposal) private _proposals;
    mapping(address => uint256) private _deposit;
    mapping(address => mapping(uint256 => bool)) private _voted;
    mapping(address => uint256) private _lastVoting;

    constructor(
        address chairperson,
        address voteToken,
        uint64 minimumQuorum,
        uint24 debatingPeriodDuration
    ) {
        _chairperson = chairperson;

        _voteToken = voteToken;
        _minimumQuorum = minimumQuorum;
        _votingPeriodDuration = debatingPeriodDuration;
    }

    modifier proposalExists(uint256 pId) {
        require(pId > 0 && pId < _proposalCounter, "MADAO: no such voting");
        _;
    }

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return _proposals[id];
    }

    function getDeposit() external view returns (uint256) {
        return _deposit[msg.sender];
    }

    function deposit(uint256 amount) external {
        _deposit[msg.sender] += amount;

        IERC20(_voteToken).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw() external {
        uint256 amount = _deposit[msg.sender];
        require(
            amount > 0,
            "MADAO: nothing to withdraw"
        );
        
        uint256 lvId = _lastVoting[msg.sender];
        if (lvId > 0) {
            // check if user voted
            require(
                _proposals[lvId].status != uint8(Status.InProcess),
                "MADAO: tokens are frozen"
            );
        }

        _deposit[msg.sender] = 0;

        IERC20(_voteToken).transfer(msg.sender, amount);
    }

    function addProposal(
        address recipient,
        bytes memory funcSignature,
        string memory description
    ) external {
        require(msg.sender == _chairperson, "MADAO: no access");
        Proposal storage p = _proposals[_proposalCounter++];
        p.funcSignature = funcSignature;
        p.description = description;
        p.recipient = recipient;
        p.startDate = uint64(block.timestamp);
    }

    function vote(uint32 proposalId, bool agree)
        external
        proposalExists(proposalId)
    {
        uint128 availableAmount = uint128(_deposit[msg.sender]);
        require(availableAmount > 0, "MADAO: no deposit to vote");

        Proposal storage p = _proposals[proposalId];
        require( //now < finishDate
            block.timestamp < p.startDate + _votingPeriodDuration,
            "MADAO: voting period ended"
        );
        require(!_voted[msg.sender][proposalId], "MADAO: voted already");
        _voted[msg.sender][proposalId] = true;

        // because of the common voting period for all proposals,
        // it's enough to keep the last voting.
        // all votings before will finish before the last one.
        uint256 lastVotingId = _lastVoting[msg.sender];
        if (proposalId > lastVotingId) 
            _lastVoting[msg.sender] = proposalId;//this is needed for withdraw

        if (agree) p.votesFor += availableAmount;
        else p.votesAgainst += availableAmount;
    }

    function finish(uint256 proposalId) external proposalExists(proposalId) {
        Proposal storage p = _proposals[proposalId];
        require( //now > finishDate
            block.timestamp > p.startDate + _votingPeriodDuration,
            "MADAO: voting is in process"
        );
        require(p.status == uint8(Status.InProcess), "MADAO: handled already");
        Status resultStatus;
        if (p.votesFor + p.votesAgainst < _minimumQuorum) {
            resultStatus = Status.Cancelled;
        } else {
            resultStatus = p.votesFor > p.votesAgainst
                ? Status.Finished
                : Status.Rejected;
        }
        p.status = uint8(resultStatus);
        if (resultStatus != Status.Finished) return;

        (bool success, ) = p.recipient.call(p.funcSignature);
        require(success, "MADAO: recipient call error");
    }
}
