//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MADAO is AccessControl {
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
        uint256 votesFor;
        uint256 votesAgainst;
        bytes funcSignature;
        string description;
    }

    uint64 private _minimumQuorum = 1000;
    uint24 private _votingPeriodDuration = 3 days; //~6 months max
    address private _voteToken;
    address private _chairperson;
    uint32 private _proposalCounter;
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
        _grantRole(DEFAULT_ADMIN_ROLE, chairperson);

        _voteToken = voteToken;
        _minimumQuorum = minimumQuorum;
        _votingPeriodDuration = debatingPeriodDuration;
    }

    function deposit(uint256 amount) external {
        _deposit[msg.sender] += amount;

        IERC20(_voteToken).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw() external {
        Proposal memory lastVoting = _proposals[_lastVoting[msg.sender]];
        require(
            lastVoting.status != uint8(Status.InProcess),
            "MADAO: tokens are frozen"
        );

        uint amount = _deposit[msg.sender];
        _deposit[msg.sender] = 0;

        IERC20(_voteToken).transfer(msg.sender, amount);
    }

    function addProposal(
        address recipient,
        bytes memory funcSignature,
        string memory description
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(msg.sender == _chairperson, "MADAO: no access");
        Proposal storage p = _proposals[_proposalCounter++];
        p.funcSignature = funcSignature;
        p.description = description;
        p.recipient = recipient;
        p.startDate = uint64(block.timestamp);
    }

    function vote(uint32 proposalId, bool agree) external {
        Proposal storage p = _proposals[proposalId];
        require( //now < finishDate
            block.timestamp < p.startDate + _votingPeriodDuration,
            "MADAO: voting period ended"
        );
        require(!_voted[msg.sender][proposalId], "MADAO: voted already");

        // because of the common voting period for all proposals,
        // it's enough to keep the last voting.
        // all votings before will finish before the last one.
        uint lastVotingId = _lastVoting[msg.sender];
        if (proposalId > lastVotingId)
            _lastVoting[msg.sender] = proposalId;

        if (agree) p.votesFor += _deposit[msg.sender];
        else p.votesAgainst += _deposit[msg.sender];
    }

    function finish(uint256 proposalId) external {
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

    // function delegate(address to, uint256 proposal) external {}
}
