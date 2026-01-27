// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAirdrop {
    error InvalidMerkleProof();
    error InvalidMerkleRoot();
    error SameAsCurrent();
    error AlreadyClaimed();
    error DeadlinePassed();
    error AirdropOngoing();
    error InvalidAddress();
    error InvalidAmount();
    error NotEnoughBalance();

    event AirdropClaim(address indexed claimant, bytes32 indexed merkleRoot, uint256 amount);
    event MerkleRootUpdate(bytes32 previousRoot, bytes32 newRoot);

    function hasClaimed(address user_) external view returns (bool);

    function totalClaimed() external view returns (uint256);

    function deadline() external view returns (uint256);

    function claim(uint256 amount_, bytes32[] calldata merkleProof_) external;

    function updateMerkleRoot(bytes32 merkleRoot_) external;

    function recover(address to_) external;
}
