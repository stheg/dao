//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MADAO is AccessControl {
    enum Status {
        InProcess,
        Finished,
        Rejected
    }

    struct Proposal {
        uint8 status;
        uint64 startDate; //it's ok until (Jul 21 2554)
        address recipient;
        uint256 votesFor;
        bytes funcSignature;
        string description;
    }

    uint8 private _minimumQuorumPercent;
    uint24 private _votingPeriodDuration; //~6 months max
    address private _voteToken;
    address private _chairperson;
    uint32 private _proposalCounter;
    uint32 private _depositCounter;
    mapping(uint256 => Proposal) private _proposals;
    mapping(uint256 => mapping(address => uint256)) private _spentAmount;
    mapping(address => uint256) private _deposit;

    constructor(
        address chairperson,
        address voteToken,
        uint8 minimumQuorumPercent,
        uint24 debatingPeriodDuration
    ) {
        _chairperson = chairperson;
        _voteToken = voteToken;
        _minimumQuorumPercent = minimumQuorumPercent;
        _votingPeriodDuration = debatingPeriodDuration;
    }

    function deposit(uint256 amount) external {
        _deposit[msg.sender] += amount;
        _depositCounter++;
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

    function vote(uint32 proposalId, uint256 amount) external {
        require(
            _getAvailableAmount(msg.sender, proposalId) >= amount,
            "MADAO: no enough vote tokens"
        );
        Proposal storage p = _proposals[proposalId];
        require(//now < finishDate
            block.timestamp < p.startDate + _votingPeriodDuration,
            "MADAO: voting period ended"
        );
        _deposit[msg.sender] -= amount;
        _spentAmount[_proposalCounter][msg.sender] += amount;
        p.votesFor += amount;
    }

    function finish(uint256 proposalId) external {
        Proposal storage p = _proposals[proposalId];
        require(//now > finishDate
            block.timestamp > p.startDate + _votingPeriodDuration,
            "MADAO: voting is in process"
        );
        require(p.status == 0, "MADAO: handled already");
        uint256 total = IERC20(_voteToken).totalSupply();
        if(p.votesFor * 100 / total < _minimumQuorumPercent) {
            p.status = uint8(Status.Rejected);
            return;
        }
        p.status = uint8(Status.Finished);
        
        (bool success, ) = p.recipient.call(p.funcSignature);
        require(success, "MADAO: external call error");
    }

    function _getAvailableAmount(address voter, uint256 proposalId)
        private
        view
        returns (uint256)
    {
        if (_deposit[voter] <= _spentAmount[proposalId][voter]) 
            return 0;
        return _deposit[voter] - _spentAmount[proposalId][voter];
    }
}
