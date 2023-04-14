// SWC-124 example from https://swcregistry.io/docs/SWC-124#arbitrary-location-write-simplesol
// NOTES:
// in principle the fuzzer "could" generate an exploit for this kind of
// vulnerability.
// BUG: set array.length to UINT256_MAX due to overflow
// 1. TX: `PopBonusCode()`
// EXPLOIT: first overwrite the owner storage variable
// 2. TX: `UpdateBonusCodeAt(N, attacker_address)`
// EXPLOIT: then trigger the selfdestruct
// 3. TX: `Destroy()`
//
// Now the hard part is to compute the `N` here. To overwrite the storage
// address of the owner, we need to compute the offset from the beginning of
// the dynamic array contents to the owner variable.
// The storage slot of the dynamic array is `0`, so the address of the dynamic
// array contents is computed as `keccak256(0)`.
// So we need to provide `-(keccask256(0)) + 1` as `idx` parameter.
// Then the addition will overflow and the storage address will be that of the
// owner.
//
// This seems quite impossible to do this in a general purpose fuzzer. Here are
// some thoughts on how to discover this, nevertheless:
// * Analyze code for static sha3 computations and add them to the dictionary.
// * The fuzzer flips the sign of this value.
// * The fuzzer eventually discovers that it can write to owner
// * The fuzzer chooses a sensible value for owner
//

pragma solidity ^0.4.25;

contract ArbitraryLocationWriteSimple {
    uint256[] private bonusCodes;
    address private owner;

    constructor() public {
        bonusCodes = new uint256[](0);
        owner = msg.sender;
    }

    function() public payable {}

    function PushBonusCode(uint256 c) public {
        bonusCodes.push(c);
    }

    function PopBonusCode() public {
        require(0 <= bonusCodes.length);
        bonusCodes.length--;
    }

    function UpdateBonusCodeAt(uint256 idx, uint256 c) public {
        require(idx < bonusCodes.length);
        bonusCodes[idx] = c;
    }

    function Destroy() public {
        require(msg.sender == owner);
        selfdestruct(msg.sender);
    }
}
