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
    mapping(address => mapping(uint256 => uint256)) private _allowance;

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

    modifier voteGuard(address voter, uint256 pId) {
        require(!_voted[msg.sender][pId], "MADAO: voted already");
        _voted[msg.sender][pId] = true;
        _;
    }

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return _proposals[id];
    }

    function getDeposit() external view returns (uint256) {
        return _deposit[msg.sender];
    }

    function getVoteToken() external view returns (address) {
        return _voteToken;
    }

    function deposit(uint256 amount) external {
        _deposit[msg.sender] += amount;

        IERC20(_voteToken).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw() external {
        uint256 amount = _deposit[msg.sender];
        require(amount > 0, "MADAO: nothing to withdraw");

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

    function vote(uint32 pId, bool agree)
        external
        proposalExists(pId)
        voteGuard(msg.sender, pId)
    {
        uint128 availableAmount = uint128(_checkAmount(msg.sender, pId));

        Proposal storage p = _proposals[pId];
        require( //now < finishDate
            block.timestamp < p.startDate + _votingPeriodDuration,
            "MADAO: voting period ended"
        );

        // because of the common voting period for all proposals,
        // it's enough to keep the last voting.
        // all votings before will finish before the last one.
        uint256 lastVotingId = _lastVoting[msg.sender];
        if (pId > lastVotingId) _lastVoting[msg.sender] = pId; //this is needed for withdraw

        if (agree) p.votesFor += availableAmount;
        else p.votesAgainst += availableAmount;
    }

    function finish(uint256 pId) external proposalExists(pId) {
        Proposal storage p = _proposals[pId];
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

    function delegate(address aDelegate, uint256 pId)
        external
        proposalExists(pId)
        voteGuard(msg.sender, pId)
    {
        require(!_voted[aDelegate][pId], "MADAO: delegate voted already");
        _allowance[aDelegate][pId] += _checkAmount(msg.sender, pId);
    }

    function _checkAmount(address voter, uint256 pId)
        private
        view
        returns (uint256)
    {
        uint256 availableAmount = _deposit[voter] + _allowance[voter][pId];
        require(availableAmount > 0, "MADAO: no deposit");
        return availableAmount;
    }
}
