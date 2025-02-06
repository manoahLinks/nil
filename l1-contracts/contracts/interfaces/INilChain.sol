// SPDX-License-Identifier: MIT

pragma solidity  >=0.8.2 <0.9.0;

interface INilChain {

    // ================== @EVENTS ==================
    
    /// @dev Notify about changes in the status of Sync Committee member.
    event CommitteeMemberUpdated(address indexed member, bool oldStatus, bool newStatus);

    /// @dev Emitted when old state route replaced with new state root with corresponding batch.
    event BatchIsFinalized(uint256 indexed batchIndex, bytes32 oldStateRoot, bytes32 indexed newStateRoot);

    function isBatchFinalized(uint256 _batchIndex) external view returns (bool);

    function isRootFinalized(bytes32 _stateRoot) external view returns (bool);

    function setSyncCommMemberStatus(address _member, bool _status) external;

    function proofBatch(
        bytes32 _prevStateRoot,
        bytes32 _newStateRoot,
        bytes calldata _blobProof,
        uint256 _batchIndexInBlobStorage
    ) external;
}