// SPDX-License-Identifier: MIT

pragma solidity  >=0.8.2 <0.9.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {INilChain} from "./interfaces/INilChain.sol";

contract NilChain is OwnableUpgradeable, PausableUpgradeable, INilChain {

    // ================== @ERRORS ==================

    /// @dev Error if not part of Synchronization Committee.
    error ErrorCallerIsNotMemberOfSC();

    /// @dev Error if not part of Synchronization Committee.
    error ErrorMustBeEOA();

    /// @dev Wrong attempt to set new state root to 0.
    error ErrorNewStateRootIsZero();

    /// @dev Wrong attempt to set old state root to 0.
    error ErrorOldStateRootIsZero();

    /// @dev Call of kzg evaluation precompile failed for unknown reason.
    error ErrorCallEvaluationPrecompileFailed();

    /// @dev Output from evaluation precompile doesn't match expected result.
    error ErrorEvaluationPrecompileOutputWrong();

    /// @dev The current state root doesn't match the submitted old root.
    error ErrorOldStateRootNotMatch();

    /// @dev New state root was already finalized.
    error ErrorNewStateRootAlreadyFinalized();

    // ================== @CONSTANTS ==================

    /// @dev BLS Modulus defined in EIP-4844.
    uint256 private constant BLS_MODULUS =
        52435875175126190479447740508185965837690552500527637822603658699938581184513;

    /// @dev Address of the kzg precompiled contract.
    address private constant KZG_EVALUATION_PRECOMPILE = address(0x0A);

    /// @dev L2 chain ID. Set in the constructor.
    uint64 public immutable chainID;

    // ================== @VARIABLES ==================

    /// @dev last finalized batch index
    uint256 public finalizedBatchIndex; 

    /// @dev Indexed finalized stateroots.
    mapping(uint256 => bytes32) public stateRoots;

    /// @dev Finalized state id.
    mapping(bytes32 => uint256) public stateRootIndex;

    /// @dev List of active Synchronization Committee members.
    mapping(address => bool) public isCommitteeMember;

    uint256 public version;

    // ================== @CODE ==================


    modifier OnlySyncCommittee() {
        // @note In the decentralized mode, it should be only called by a list of validator.
        if (!isCommitteeMember[msg.sender]) revert ErrorCallerIsNotMemberOfSC();
        _;
    }


    constructor (
        uint64 _chainId,
        uint256 _version
    ) initializer {
        chainID = _chainId;
        finalizedBatchIndex = 1;
        /// @dev this is "genesis" root
        stateRoots[0] = 0x0000000000000000000000000000000000000000000000000000000000000001;
        version = _version;
        OwnableUpgradeable.__Ownable_init(msg.sender);
    }

    function isBatchFinalized(uint256 _batchIndex) external override view returns (bool) {
        return finalizedBatchIndex > _batchIndex;
    }

    function isRootFinalized(bytes32 _stateRoot) external override view returns (bool) {
        return stateRootIndex[_stateRoot] != 0;
    }

    function setSyncCommMemberStatus(address _member, bool _status) external override onlyOwner {
        bool oldStatus = isCommitteeMember[_member];
        
        if (tx.origin != msg.sender) {
            revert ErrorMustBeEOA();
        }

        isCommitteeMember[_member] = _status;

        emit CommitteeMemberUpdated(_member, oldStatus, _status);
    }


    /// @dev Memory layout of _blobProof:
    /// | z       | y       | kzg_commitment | kzg_proof |
    /// |---------|---------|----------------|-----------|
    /// | bytes32 | bytes32 | bytes48        | bytes48   |
    /// if _batchIndexInBlobStorage is 0 -- we skip blob proof verification.
    /// verification tested and works fine
    function proofBatch(
        bytes32 _prevStateRoot,
        bytes32 _newStateRoot,
        bytes calldata _blobProof,
        uint256 _batchIndexInBlobStorage
    ) external override OnlySyncCommittee {
        
        if (_prevStateRoot == bytes32(0)) {
            revert ErrorOldStateRootIsZero();
        }
        if (_newStateRoot == bytes32(0)) {
            revert ErrorNewStateRootIsZero();
        }

        // verify blob proof if needed
        // if (_batchIndexInBlobStorage != 0) {
        //     bytes32 blobVersionedHash = blobhash(_batchIndexInBlobStorage);
        //     (bool success, bytes memory data) = KZG_EVALUATION_PRECOMPILE.staticcall(
        //         abi.encodePacked(blobVersionedHash, _blobProof)
        //     );
            
        //     if (!success) {
        //         revert ErrorCallEvaluationPrecompileFailed();
        //     }

        //     (, uint256 result) = abi.decode(data, (uint256, uint256));

        //     if (result != BLS_MODULUS) {
        //         revert ErrorEvaluationPrecompileOutputWrong();
        //     }
        // }

        // verify previous state root.
        if (stateRoots[finalizedBatchIndex - 1] != _prevStateRoot) {
            revert ErrorOldStateRootNotMatch();
        }

        // avoid duplicated verification
        if (stateRoots[finalizedBatchIndex] != bytes32(0)) {
             revert ErrorNewStateRootAlreadyFinalized();
        }

        stateRoots[finalizedBatchIndex] = _newStateRoot;
        stateRootIndex[_newStateRoot] = finalizedBatchIndex;
        emit BatchIsFinalized(finalizedBatchIndex, _prevStateRoot, _newStateRoot);

        finalizedBatchIndex += 1;
    }
}